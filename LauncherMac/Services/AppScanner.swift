import AppKit

enum AppScanner {
    static var searchRoots: [String] {
        [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
    }

    static func scan() -> [AppInfo] {
        var seen = Set<String>()
        var apps: [AppInfo] = []

        for root in searchRoots {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let path = (root as NSString).appendingPathComponent(entry)
                let url = URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath()
                let key = url.standardizedFileURL.path
                guard seen.insert(key).inserted else { continue }
                guard let values = try? url.resourceValues(forKeys: [.isHiddenKey, .isDirectoryKey]),
                      values.isDirectory == true,
                      values.isHidden != true else { continue }

                let icon = NSWorkspace.shared.icon(forFile: key)
                icon.size = NSSize(width: 256, height: 256)
                let bundle = Bundle(url: url)
                apps.append(AppInfo(
                    url: url,
                    name: displayName(for: url, bundle: bundle),
                    icon: icon,
                    category: AppCategory.from(
                        launchServicesCategory: bundle?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
                    )
                ))
            }
        }

        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func displayName(for url: URL, bundle: Bundle?) -> String {
        if let bundle {
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let name = bundle.object(forInfoDictionaryKey: key) as? String, !name.isEmpty {
                    return name
                }
            }
        }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }
}
