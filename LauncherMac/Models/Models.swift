import AppKit

struct AppInfo: Identifiable, Hashable {
    let url: URL
    let name: String
    let icon: NSImage
    let category: AppCategory?

    var id: String { url.standardizedFileURL.path }

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum AppCategory: String, CaseIterable, Identifiable, Hashable {
    case developerTools
    case utilities
    case productivityFinance
    case creativity
    case social
    case entertainment
    case informationReading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .developerTools: return "Developer Tools"
        case .utilities: return "Utilities"
        case .productivityFinance: return "Productivity & Finance"
        case .creativity: return "Creativity"
        case .social: return "Social"
        case .entertainment: return "Entertainment"
        case .informationReading: return "Information & Reading"
        }
    }

    static func from(launchServicesCategory raw: String?) -> AppCategory? {
        guard let raw else { return nil }
        switch raw {
        case "public.app-category.developer-tools":
            return .developerTools
        case "public.app-category.utilities":
            return .utilities
        case "public.app-category.productivity", "public.app-category.finance",
             "public.app-category.business":
            return .productivityFinance
        case "public.app-category.graphics-design", "public.app-category.graphics-and-design",
             "public.app-category.photography", "public.app-category.video",
             "public.app-category.music":
            return .creativity
        case "public.app-category.social-networking":
            return .social
        case "public.app-category.entertainment", "public.app-category.games":
            return .entertainment
        case "public.app-category.reference", "public.app-category.news",
             "public.app-category.education", "public.app-category.books",
             "public.app-category.travel":
            return .informationReading
        default:
            if raw.hasSuffix("-games") { return .entertainment }
            return nil
        }
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

enum MovedItem: Hashable {
    case app(String)
    case folder(UUID)
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
