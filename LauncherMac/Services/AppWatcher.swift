import CoreServices
import Foundation

final class AppWatcher {
    private var stream: FSEventStreamRef?
    private var onChange: (() -> Void)?
    private var pendingReload: DispatchWorkItem?

    private let queue = DispatchQueue(label: "LauncherMac.AppWatcher")
    private static let roots = AppScanner.searchRoots

    func start(onChange: @escaping () -> Void) {
        stop()

        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
            guard let info else { return }
            let watcher = Unmanaged<AppWatcher>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            let flags = UnsafeBufferPointer(start: eventFlags, count: count)
            watcher.handle(paths: paths, flags: Array(flags))
        }

        let createFlags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagIgnoreSelf
        )

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            Self.roots as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            createFlags
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        pendingReload?.cancel()
        pendingReload = nil

        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func handle(paths: [String], flags: [FSEventStreamEventFlags]) {
        let relevant = paths.contains { path in
            Self.affectsApps(path)
        }

        guard relevant else { return }

        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let onChange = self.onChange else { return }
            DispatchQueue.main.async {
                onChange()
            }
        }
        pendingReload = work
        queue.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    /// True when a path is an app bundle (or lives inside one) under one of the scanned roots.
    private static func affectsApps(_ path: String) -> Bool {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path

        for root in roots {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            guard normalized.hasPrefix(prefix) else { continue }

            let relative = normalized.dropFirst(prefix.count)
            guard let first = relative.split(separator: "/", maxSplits: 1).first else {
                return true
            }
            if first.hasSuffix(".app") {
                return true
            }
        }

        return false
    }
}
