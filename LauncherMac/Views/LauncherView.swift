import AppKit
import SwiftUI

struct LauncherView: View {
    @ObservedObject var store: LauncherStore
    let controller: LauncherController

    @AppStorage("gridColumns") private var columns = 7
    @AppStorage("gridRows") private var rows = 4
    @AppStorage("presentationMode") private var presentationMode = LauncherController.Presentation.window.rawValue
    @AppStorage("scrollMode") private var scrollMode = ScrollMode.vertical.rawValue

    @FocusState private var searchFocused: Bool
    @Environment(\.openSettings) private var openSettings

    private var isOverlay: Bool {
        presentationMode != LauncherController.Presentation.window.rawValue
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
    }

    private var hasContent: Bool {
        if store.isSearching { return !store.pageItems.isEmpty }
        return !store.pageItems.isEmpty || !store.favoriteApps.isEmpty
    }

    private var pageCount: Int {
        let favoriteRows: Int
        if store.isSearching || store.favoriteApps.isEmpty {
            favoriteRows = 0
        } else {
            favoriteRows = Int(ceil(Double(store.favoriteApps.count) / Double(max(1, columns)))) + 1
        }
        let itemRows = Int(ceil(Double(store.pageItems.count) / Double(max(1, columns))))
        let totalRows = favoriteRows + itemRows
        return max(1, Int(ceil(Double(totalRows) / Double(max(1, rows)))))
    }

    private var showsPageDots: Bool {
        !store.isSearching
            && scrollMode == ScrollMode.pages.rawValue
            && pageCount > 1
    }

    var body: some View {
        Group {
            if isOverlay {
                launchpad
            } else {
                spotlightWindow
            }
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            searchFocused = true
        }
        .onChange(of: store.searchText) { _, _ in
            store.currentPage = 0
        }
        .onChange(of: store.selectedCategory) { _, _ in
            store.currentPage = 0
        }
        .onChange(of: store.openFolderID) { _, newValue in
            searchFocused = (newValue == nil)
        }
        .onChange(of: columns) { _, _ in store.currentPage = 0 }
        .onChange(of: rows) { _, _ in store.currentPage = 0 }
        .onChange(of: scrollMode) { _, _ in store.currentPage = 0 }
        .onChange(of: store.favoriteIDs) { _, _ in store.currentPage = 0 }
        .overlay {
            if let folderID = store.openFolderID, let folder = store.folder(id: folderID) {
                FolderView(folder: folder, store: store, controller: controller)
                    .id(folder.id)
            }
        }
    }

    // MARK: - Windowed presentation (Spotlight-style)

    @ViewBuilder
    private var spotlightWindow: some View {
        launcherContent
            .background(LauncherBackground(shape: panelShape))
            .overlay {
                panelShape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }
            .contentShape(panelShape)
            .onTapGesture {}
    }

    private var launcherContent: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 22)

            if store.isEditingFavorites {
                FavoritesHint {
                    store.isEditingFavorites = false
                }
                .padding(.top, 12)
            }

            if !store.isSearching {
                CategoryChips(categories: AppCategory.allCases, selection: $store.selectedCategory)
                    .padding(.top, 20)
            }

            if hasContent {
                AppsGrid(
                    store: store,
                    controller: controller,
                    columns: columns,
                    rows: rows,
                    interactive: !store.isSearching,
                    fadeEdges: true,
                    trailingSpacer: scrollMode == ScrollMode.vertical.rawValue
                )
                .padding(.top, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(isSearching: store.isSearching, category: store.selectedCategory)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showsPageDots {
                PageDots(
                    count: pageCount,
                    current: min(max(store.currentPage, 0), pageCount - 1),
                    onSelect: { store.currentPage = $0 }
                )
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, showsPageDots ? 8 : 16)
    }

    // MARK: - Full-screen presentation (Launchpad-style)

    private var launchpad: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    CapsuleSearchBar(text: $store.searchText, isFocused: $searchFocused, onSubmit: launchFirstItem)
                        .frame(maxWidth: 440)

                    HStack(spacing: 14) {
                        Spacer()
                        if showsPageDots {
                            PageDots(
                                count: pageCount,
                                current: min(max(store.currentPage, 0), pageCount - 1),
                                onSelect: { store.currentPage = $0 }
                            )
                        }
                        menuButton
                    }
                }
                .frame(height: 38)
                .padding(.top, 36)
                .padding(.horizontal, 36)

                if store.isEditingFavorites {
                    FavoritesHint {
                        store.isEditingFavorites = false
                    }
                    .padding(.top, 12)
                }

                if hasContent {
                    AppsGrid(
                        store: store,
                        controller: controller,
                        columns: columns,
                        rows: rows,
                        interactive: !store.isSearching
                    )
                    .padding(.top, 14)
                    .padding(.horizontal, 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyState(isSearching: store.isSearching, category: nil)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            SearchBar(text: $store.searchText, isFocused: $searchFocused, onSubmit: launchFirstItem)

            menuButton
        }
    }

    private var menuButton: some View {
        Menu {
            Button(store.isEditingFavorites ? "Done Editing Favorites" : "Edit Favorites") {
                store.isEditingFavorites.toggle()
            }
            Divider()
            Button("Refresh Apps") { store.reloadApps() }
            Button("Reset Layout") {
                store.resetLayout()
                controller.resetWindowSize()
            }
            Divider()
            Button("Settings…") { showSettings() }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.09)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
    }

    private func showSettings() {
        DispatchQueue.main.async {
            NSApp.activate()
            openSettings()
            controller.raiseSettingsWindow()
        }
    }

    private func launchFirstItem() {
        if store.isSearching {
            if let app = store.searchResults.first {
                controller.launch(app)
            } else {
                NSSound.beep()
            }
            return
        }

        if let app = store.favoriteApps.first {
            controller.launch(app)
            return
        }

        for item in store.pageItems {
            if let appID = item.appIDs.first, let app = store.app(for: appID) {
                controller.launch(app)
                return
            }
        }

        NSSound.beep()
    }
}

private struct FavoritesHint: View {
    let done: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink)
            Text("Tap apps to add or remove from Favorites")
            Button(action: done) {
                Text("Done")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.12)))
        .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.12)))
    }
}


private struct EmptyState: View {
    let isSearching: Bool
    let category: AppCategory?

    private var title: String {
        if isSearching { return "No apps found" }
        if let category { return "No apps in \(category.title)" }
        return "No applications"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isSearching ? "magnifyingglass" : "square.grid.3x3")
                .font(.system(size: 34, weight: .light))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.65))
    }
}
