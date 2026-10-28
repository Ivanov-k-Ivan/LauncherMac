import AppKit

struct AppInfo: Identifiable, Hashable {
    let url: URL
    let name: String
    let icon: NSImage

    var id: String { url.standardizedFileURL.path }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LauncherFolder: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var appIDs: [String]

    init(id: UUID = UUID(), name: String = "Folder", appIDs: [String] = []) {
        self.id = id
        self.name = name
        self.appIDs = appIDs
    }
}

enum RootItem: Identifiable, Codable, Hashable {
    case app(String)
    case folder(LauncherFolder)

    var id: String {
        switch self {
        case .app(let appID): return "app:" + appID
        case .folder(let folder): return "folder:" + folder.id.uuidString
        }
    }

    var appIDs: [String] {
        switch self {
        case .app(let appID): return [appID]
        case .folder(let folder): return folder.appIDs
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, appID, folder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "folder":
            self = .folder(try container.decode(LauncherFolder.self, forKey: .folder))
        default:
            self = .app(try container.decode(String.self, forKey: .appID))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let appID):
            try container.encode("app", forKey: .type)
            try container.encode(appID, forKey: .appID)
        case .folder(let folder):
            try container.encode("folder", forKey: .type)
            try container.encode(folder, forKey: .folder)
        }
    }
}

enum ScrollMode: String {
    case pages
    case vertical
}

enum DragPayload {
    static let appPrefix = "launcher-app://"
    static let folderPrefix = "launcher-folder://"

    static func app(_ id: String) -> String { appPrefix + id }
    static func folder(_ id: UUID) -> String { folderPrefix + id.uuidString }

    static func appID(from payload: String) -> String? {
        guard payload.hasPrefix(appPrefix) else { return nil }
        return String(payload.dropFirst(appPrefix.count))
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
