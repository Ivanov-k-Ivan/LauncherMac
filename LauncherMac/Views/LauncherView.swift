import AppKit
import SwiftUI

struct LauncherView: View {
    @ObservedObject var store: LauncherStore
    let controller: LauncherController

    @AppStorage("gridColumns") private var columns = 8
    @AppStorage("gridRows") private var rows = 5
    @AppStorage("presentationMode") private var presentationMode = LauncherController.Presentation.window.rawValue
    @AppStorage("scrollMode") private var scrollMode = ScrollMode.vertical.rawValue

    @FocusState private var searchFocused: Bool
    @Environment(\.openSettings) private var openSettings

    private var isOverlay: Bool {
        presentationMode != LauncherController.Presentation.window.rawValue
    }

    private var gridHorizontalPadding: CGFloat {
        isOverlay ? 80 : 24
    }

    private var panelInset: CGFloat {
        isOverlay ? 14 : 0
    }

    private var panelCornerRadius: CGFloat {
        isOverlay ? 30 : 0
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
        ZStack {
            if isOverlay {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        controller.hide()
                    }
            }

            panel
        }
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            searchFocused = true
        }
        .onChange(of: store.searchText) { _, _ in
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

    @ViewBuilder
    private var panel: some View {
        if #available(macOS 26.0, *) {
            launcherContent
                .padding(panelInset)
                .glassEffect(
                    .regular.tint(Color(red: 0.07, green: 0.09, blue: 0.19).opacity(0.62)),
                    in: RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                )
        } else {
            launcherContent
                .padding(panelInset)
                .background(LauncherBackground())
                .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
        }
    }

    private var launcherContent: some View {
        VStack(spacing: 0) {
            SearchBar(text: $store.searchText, isFocused: $searchFocused, onSubmit: launchFirstItem)
                .frame(maxWidth: 440)
                .padding(.top, isOverlay ? 36 : 22)

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
                .padding(.horizontal, gridHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(isSearching: store.isSearching)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            footer
        }
        .padding(.bottom, 8)
    }

    private var footer: some View {
        ZStack {
            if showsPageDots {
                PageDots(
                    count: pageCount,
                    current: min(max(store.currentPage, 0), pageCount - 1),
                    onSelect: { store.currentPage = $0 }
                )
            }

            HStack(spacing: 4) {
                FooterButton(
                    systemName: store.isEditingFavorites ? "heart.fill" : "heart",
                    color: store.isEditingFavorites ? .pink : .white,
                    isActive: store.isEditingFavorites,
                    help: "Edit Favorites"
                ) {
                    store.isEditingFavorites.toggle()
                }

                FooterButton(
                    systemName: "gearshape.fill",
                    color: .white,
                    isActive: false,
                    help: "Settings",
                    action: showSettings
                )

                Spacer()
            }
            .padding(.horizontal, isOverlay ? 36 : 20)
        }
        .frame(height: 34)
        .padding(.bottom, isOverlay ? 22 : 10)
    }

    private func showSettings() {
        DispatchQueue.main.async {
            NSApp.activate()
            openSettings()
            controller.hide()
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

private struct FooterButton: View {
    let systemName: String
    let color: Color
    let isActive: Bool
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color.opacity(isActive || isHovering ? 0.95 : 0.45))
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(Color.white.opacity(isActive || isHovering ? 0.14 : 0))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

private struct EmptyState: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isSearching ? "magnifyingglass" : "square.grid.3x3")
                .font(.system(size: 34, weight: .light))
            Text(isSearching ? "No apps found" : "No applications")
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.65))
    }
}
