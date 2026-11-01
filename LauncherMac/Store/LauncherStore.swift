import AppKit
import SwiftUI

@MainActor
final class LauncherStore: ObservableObject {
    @Published private(set) var appsByID: [String: AppInfo] = [:]
    @Published private(set) var items: [RootItem] = []
    @Published var searchText = ""
    @Published var openFolderID: UUID?
    @Published var currentPage = 0
    @Published private(set) var favoriteIDs: [String] = []
    @Published var isEditingFavorites = false
    @Published var selectedCategory: AppCategory?

    private let defaults = UserDefaults.standard
    private let layoutKey = "launcher.layout.v1"
    private let favoritesKey = "launcher.favorites.v1"
    private var lastScan = Date.distantPast

    init() {
        loadFavorites()
        reloadApps()
    }

    // MARK: - Queries

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var pageItems: [RootItem] {
        if isSearching {
            return searchResults.map { .app($0.id) }
        }
        let favoriteSet = Set(favoriteIDs)
        let category = selectedCategory
        return items.compactMap { item in
            switch item {
            case .app(let appID):
                if favoriteSet.contains(appID) { return nil }
                if let category, appsByID[appID]?.category != category { return nil }
                return item
            case .folder(let folder):
                guard let category else { return item }
                let containsCategory = folder.appIDs.contains { appsByID[$0]?.category == category }
                return containsCategory ? item : nil
            }
        }
    }

    var favoriteApps: [AppInfo] {
        favoriteIDs.compactMap { appsByID[$0] }.filter { app in
            selectedCategory == nil || app.category == selectedCategory
        }
    }

    func isFavorite(_ appID: String) -> Bool {
        favoriteIDs.contains(appID)
    }

    func toggleFavorite(_ appID: String) {
        guard appsByID[appID] != nil else { return }
        if let index = favoriteIDs.firstIndex(of: appID) {
            favoriteIDs.remove(at: index)
        } else {
            favoriteIDs.append(appID)
        }
        saveFavorites()
    }

    /// Reorders a favorite app relative to another favorite app.
    func reorderFavorite(_ appID: String, relativeTo targetID: String, placeAfter: Bool) {
        guard appID != targetID,
              let sourceIndex = favoriteIDs.firstIndex(of: appID),
              favoriteIDs.contains(targetID) else { return }

        favoriteIDs.remove(at: sourceIndex)
        guard let targetIndex = favoriteIDs.firstIndex(of: targetID) else { return }

        let insertion = min(max(0, placeAfter ? targetIndex + 1 : targetIndex), favoriteIDs.count)
        favoriteIDs.insert(appID, at: insertion)
        saveFavorites()
    }

    var searchResults: [AppInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return appsByID.values
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func app(for id: String) -> AppInfo? {
        appsByID[id]
    }

    func folder(id: UUID) -> LauncherFolder? {
        for item in items {
            if case .folder(let folder) = item, folder.id == id { return folder }
        }
        return nil
    }

    func resetTransientState() {
        searchText = ""
        openFolderID = nil
        currentPage = 0
        isEditingFavorites = false
        selectedCategory = nil
    }

    // MARK: - Apps

    func reloadApps() {
        let scanned = AppScanner.scan()
        appsByID = Dictionary(scanned.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let validIDs = Set(scanned.map(\.id))
        let prunedFavorites = favoriteIDs.filter { validIDs.contains($0) }
        if prunedFavorites != favoriteIDs {
            favoriteIDs = prunedFavorites
            saveFavorites()
        }

        reconcile(with: scanned)
        lastScan = Date()
    }

    func reloadAppsIfStale() {
        if Date().timeIntervalSince(lastScan) > 120 {
            reloadApps()
        }
    }

    func resetLayout() {
        items = items.sorted { displayName(for: $0).localizedStandardCompare(displayName(for: $1)) == .orderedAscending }
        openFolderID = nil
        currentPage = 0
        save()
    }

    func resetToDefault() {
        defaults.removeObject(forKey: layoutKey)
        favoriteIDs = []
        saveFavorites()
        openFolderID = nil
        currentPage = 0
        let scanned = appsByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        reconcile(with: scanned)
    }

    // MARK: - Layout mutations

    /// Moves a root app or folder next to another root item.
    func moveRootItem(_ moved: MovedItem, relativeTo target: RootItem, placeAfter: Bool) {
        let movedID: String
        switch moved {
        case .app(let appID): movedID = "app:" + appID
        case .folder(let id): movedID = "folder:" + id.uuidString
        }
        guard movedID != target.id,
              items.contains(where: { $0.id == target.id }),
              let sourceIndex = items.firstIndex(where: { $0.id == movedID }) else { return }

        let item = items.remove(at: sourceIndex)
        guard let targetIndex = items.firstIndex(where: { $0.id == target.id }) else {
            items.append(item)
            save()
            return
        }

        let insertion = min(max(0, placeAfter ? targetIndex + 1 : targetIndex), items.count)
        items.insert(item, at: insertion)
        save()
    }

    /// Removes a folder and returns its apps to the main grid in its place.
    func deleteFolder(id: UUID) {
        guard let index = items.firstIndex(where: {
            if case .folder(let folder) = $0 { return folder.id == id }
            return false
        }), case .folder(let folder) = items[index] else { return }

        items.remove(at: index)
        items.insert(contentsOf: folder.appIDs.map { RootItem.app($0) }, at: index)
        if openFolderID == id {
            openFolderID = nil
        }
        save()
    }

    /// Drops an app onto a root item, or onto the empty background when `target` is nil.
    func dropApp(_ appID: String, onto target: RootItem?) {
        guard appsByID[appID] != nil else { return }

        guard let target else {
            if removeFromFolders(appID) {
                items.append(.app(appID))
                save()
            }
            return
        }

        switch target {
        case .app(let targetAppID):
            guard targetAppID != appID else { return }
            removeFromFolders(appID)
            removeRootApp(appID)
            guard let index = items.firstIndex(where: { $0.id == target.id }) else {
                items.append(.folder(LauncherFolder(appIDs: [targetAppID, appID])))
                save()
                return
            }
            items[index] = .folder(LauncherFolder(appIDs: [targetAppID, appID]))

        case .folder(let folder):
            guard !folder.appIDs.contains(appID) else { return }
            removeFromFolders(appID)
            removeRootApp(appID)
            updateFolder(folder.id) { $0.appIDs.append(appID) }
        }

        save()
    }

    /// Moves an app out of a folder and back onto the main grid.
    func moveOutOfFolder(appID: String, folderID: UUID) {
        guard folder(id: folderID)?.appIDs.contains(appID) == true else { return }
        removeFromFolders(appID)
        if !items.contains(where: {
            if case .app(let id) = $0 { return id == appID }
            return false
        }) {
            items.append(.app(appID))
        }
        save()
    }

    /// Reorders an app inside a folder, or appends it when `targetID` is nil.
    func reorderFolderApp(_ appID: String, in folderID: UUID, relativeTo targetID: String?, placeAfter: Bool) {
        guard appID != targetID,
              let folderIndex = items.firstIndex(where: {
                  if case .folder(let folder) = $0 { return folder.id == folderID }
                  return false
              }),
              case .folder(var folder) = items[folderIndex],
              let sourceIndex = folder.appIDs.firstIndex(of: appID) else { return }

        folder.appIDs.remove(at: sourceIndex)

        let insertion: Int
        if let targetID, let targetIndex = folder.appIDs.firstIndex(of: targetID) {
            insertion = min(max(0, placeAfter ? targetIndex + 1 : targetIndex), folder.appIDs.count)
        } else {
            insertion = folder.appIDs.count
        }

        folder.appIDs.insert(appID, at: insertion)
        items[folderIndex] = .folder(folder)
        save()
    }

    func renameFolder(id: UUID, name: String) {
        updateFolder(id) { $0.name = name }
        save()
    }

    // MARK: - Private helpers

    private func displayName(for item: RootItem) -> String {
        switch item {
        case .app(let appID): return appsByID[appID]?.name ?? appID
        case .folder(let folder): return folder.name
        }
    }

    private func removeRootApp(_ appID: String) {
        items.removeAll {
            if case .app(let id) = $0 { return id == appID }
            return false
        }
    }

    @discardableResult
    private func removeFromFolders(_ appID: String) -> Bool {
        guard let index = items.firstIndex(where: { item in
            if case .folder(let folder) = item { return folder.appIDs.contains(appID) }
            return false
        }), case .folder(var folder) = items[index] else { return false }

        folder.appIDs.removeAll { $0 == appID }
        items[index] = .folder(folder)
        collapseIfNeeded(at: index)
        return true
    }

    private func updateFolder(_ id: UUID, _ transform: (inout LauncherFolder) -> Void) {
        guard let index = items.firstIndex(where: {
            if case .folder(let folder) = $0 { return folder.id == id }
            return false
        }), case .folder(var folder) = items[index] else { return }

        transform(&folder)
        items[index] = .folder(folder)
        collapseIfNeeded(at: index)
    }

    private func collapseIfNeeded(at index: Int) {
        guard items.indices.contains(index), case .folder(let folder) = items[index] else { return }
        guard folder.appIDs.count <= 1 else { return }
        if let appID = folder.appIDs.first {
            items[index] = .app(appID)
        } else {
            items.remove(at: index)
        }
    }

    // MARK: - Persistence

    private func loadFavorites() {
        favoriteIDs = defaults.stringArray(forKey: favoritesKey) ?? []
    }

    private func saveFavorites() {
        defaults.set(favoriteIDs, forKey: favoritesKey)
    }

    private func save() {
        if let id = openFolderID, folder(id: id) == nil {
            openFolderID = nil
        }
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: layoutKey)
    }

    private func reconcile(with apps: [AppInfo]) {
        let validIDs = Set(apps.map(\.id))
        var used = Set<String>()
        var result: [RootItem] = []

        if let data = defaults.data(forKey: layoutKey),
           let stored = try? JSONDecoder().decode([RootItem].self, from: data) {
            for item in stored {
                switch item {
                case .app(let id):
                    guard validIDs.contains(id), used.insert(id).inserted else { continue }
                    result.append(.app(id))

                case .folder(var folder):
                    folder.appIDs = folder.appIDs.filter { validIDs.contains($0) && used.insert($0).inserted }
                    if folder.appIDs.isEmpty { continue }
                    if folder.appIDs.count == 1 {
                        result.append(.app(folder.appIDs[0]))
                    } else {
                        result.append(.folder(folder))
                    }
                }
            }
        }

        for app in apps where !used.contains(app.id) {
            result.append(.app(app.id))
        }

        items = result
        save()
    }
}
