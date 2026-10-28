import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class LauncherController: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = LauncherController()

    let store = LauncherStore()

    enum Presentation: String {
        case overlay
        case window
    }

    private var window: NSWindow?
    private var keyMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var hotKey: HotKey?
    private var hidSystemUI = false

    private override init() {
        super.init()
    }

    var presentation: Presentation {
        Presentation(rawValue: UserDefaults.standard.string(forKey: "presentationMode") ?? "") ?? .window
    }

    private var hotKeyEnabled: Bool {
        UserDefaults.standard.object(forKey: "globalHotKeyEnabled") as? Bool ?? true
    }

    // MARK: - Lifecycle

    func setup() {
        refreshHotKey()
    }

    func refreshHotKey() {
        hotKey?.unregister()
        hotKey = nil

        guard hotKeyEnabled else { return }

        let hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) { [weak self] in
            Task { @MainActor in
                self?.toggle()
            }
        }
        if hotKey.register() {
            self.hotKey = hotKey
        }
    }

    // MARK: - Show / hide

    func toggle() {
        if let window, window.isVisible {
            hide()
        } else {
            show()
        }
    }

    func showIfNeeded() {
        if let window, window.isVisible {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        show()
    }

    func show() {
        teardownWindow()
        store.resetTransientState()
        store.reloadAppsIfStale()

        let newWindow = makeWindow()
        newWindow.delegate = self
        window = newWindow

        NSApp.activate()

        if presentation == .overlay {
            if let screen = screenUnderMouse() {
                newWindow.setFrame(screen.frame, display: true)
            }
            NSApp.presentationOptions = [.hideDock, .hideMenuBar]
            hidSystemUI = true
        }

        newWindow.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        teardownWindow()
        store.resetTransientState()
    }

    func closeFolder() {
        store.openFolderID = nil
    }

    func presentationChanged() {
        guard window?.isVisible == true else { return }
        show()
    }

    func launch(_ app: AppInfo) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration) { _, error in
            if let error {
                NSLog("Launcher: failed to open %@ — %@", app.name, error.localizedDescription)
            }
        }
        hide()
    }

    // MARK: - Window plumbing

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingView(rootView: LauncherView(store: store, controller: self))

        switch presentation {
        case .overlay:
            let screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens[0]
            let window = LauncherPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .darkAqua)
            window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.acceptsMouseMovedEvents = true
            window.contentView = hosting
            window.setFrame(screen.frame, display: true)
            return window

        case .window:
            let window = LauncherPanel(
                contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.appearance = NSAppearance(named: .darkAqua)
            window.title = "Launcher"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 760, height: 520)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            window.acceptsMouseMovedEvents = true
            window.contentView = hosting
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.setFrameAutosaveName("LauncherWindow")
            if !window.setFrameUsingName("LauncherWindow") {
                window.center()
            }
            return window
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, window.isVisible else { return }
            if NSApp.isActive, let keyWindow = NSApp.keyWindow, keyWindow !== window {
                return
            }
            self.hide()
        }
    }

    private func teardownWindow() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if hidSystemUI {
            NSApp.presentationOptions = []
            hidSystemUI = false
        }
        window?.orderOut(nil)
        window?.close()
        window = nil
    }

    private func screenUnderMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) } ?? NSScreen.main
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            DispatchQueue.main.async {
                self?.handleEscape()
            }
            return nil
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let running = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  running.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            DispatchQueue.main.async {
                guard let self, self.presentation == .overlay else { return }
                self.hide()
            }
        }
    }

    private func handleEscape() {
        if store.isEditingFavorites {
            store.isEditingFavorites = false
            return
        }
        if store.openFolderID != nil {
            store.openFolderID = nil
        } else {
            hide()
        }
    }
}

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
