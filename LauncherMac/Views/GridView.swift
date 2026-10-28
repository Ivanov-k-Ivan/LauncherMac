import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum GridRow {
    case cells([RootItem])
    case separator
}

struct AppsGrid: View {
    @ObservedObject var store: LauncherStore
    let controller: LauncherController
    let columns: Int
    let rows: Int
    let interactive: Bool
    var fadeEdges = false

    @AppStorage("scrollMode") private var scrollMode = ScrollMode.vertical.rawValue

    private var favoriteItems: [RootItem] {
        store.isSearching ? [] : store.favoriteApps.map { .app($0.id) }
    }

    private var rowsToShow: [GridRow] {
        var result: [GridRow] = []
        if !favoriteItems.isEmpty {
            result += favoriteItems.chunked(into: max(1, columns)).map { .cells($0) }
            result.append(.separator)
        }
        result += store.pageItems.chunked(into: max(1, columns)).map { .cells($0) }
        return result
    }

    var body: some View {
        if scrollMode == ScrollMode.pages.rawValue {
            PagedAppsGrid(
                rows: rowsToShow,
                store: store,
                controller: controller,
                columns: columns,
                rowsPerPage: rows,
                interactive: interactive
            )
        } else {
            VerticalAppsGrid(
                rows: rowsToShow,
                store: store,
                controller: controller,
                columns: columns,
                interactive: interactive,
                fadeEdges: fadeEdges
            )
        }
    }
}

private struct PagedAppsGrid: View {
    let rows: [GridRow]
    @ObservedObject var store: LauncherStore
    let controller: LauncherController
    let columns: Int
    let rowsPerPage: Int
    let interactive: Bool

    private let hSpacing: CGFloat = 16
    private let vSpacing: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let pageCount = max(1, Int(ceil(Double(rows.count) / Double(max(1, rowsPerPage)))))
            let selected = min(max(0, store.currentPage), pageCount - 1)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(0 ..< pageCount, id: \.self) { index in
                        let start = index * rowsPerPage
                        let end = min(start + rowsPerPage, rows.count)
                        let pageRows = start < end ? Array(rows[start ..< end]) : []

                        PagedRowsPage(
                            rows: pageRows,
                            store: store,
                            controller: controller,
                            columns: columns,
                            hSpacing: hSpacing,
                            vSpacing: vSpacing,
                            interactive: interactive
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: pageBinding(selected: selected, pageCount: pageCount))
            .onChange(of: pageCount) { _, newCount in
                store.currentPage = min(store.currentPage, max(0, newCount - 1))
            }
        }
    }

    private func pageBinding(selected: Int, pageCount: Int) -> Binding<Int?> {
        Binding(
            get: {
                Optional(min(max(selected, 0), pageCount - 1))
            },
            set: { newValue in
                guard let newValue else { return }
                store.currentPage = min(max(newValue, 0), pageCount - 1)
            }
        )
    }
}

private struct PagedRowsPage: View {
    let rows: [GridRow]
    @ObservedObject var store: LauncherStore
    let controller: LauncherController
    let columns: Int
    let hSpacing: CGFloat
    let vSpacing: CGFloat
    let interactive: Bool

    private let separatorRowHeight: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let cellWidth = max(1, (geo.size.width - CGFloat(columns - 1) * hSpacing) / CGFloat(columns))
            let hasSeparator = rows.contains { row in
                if case .separator = row { return true }
                return false
            }
            let appRowCount = max(1, rows.reduce(0) { count, row in
                if case .cells = row { return count + 1 }
                return count
            })
            let available = geo.size.height - (hasSeparator ? separatorRowHeight : 0)
                - CGFloat(max(0, rows.count - 1)) * vSpacing
            let cellHeight = max(40, available / CGFloat(appRowCount))
            let iconSide = min(cellWidth * 0.62, cellHeight * 0.68, 132)

            VStack(spacing: vSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    switch row {
                    case .cells(let items):
                        HStack(spacing: hSpacing) {
                            ForEach(0 ..< columns, id: \.self) { index in
                                if index < items.count {
                                    ItemCell(
                                        item: items[index],
                                        store: store,
                                        controller: controller,
                                        iconSide: iconSide,
                                        cellWidth: cellWidth,
                                        interactive: interactive
                                    )
                                    .frame(width: cellWidth, height: cellHeight)
                                } else {
                                    Color.clear
                                        .frame(width: cellWidth, height: cellHeight)
                                }
                            }
                        }

                    case .separator:
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .frame(maxHeight: separatorRowHeight)
                            .padding(.horizontal, 8)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

private struct VerticalAppsGrid: View {
    let rows: [GridRow]
    @ObservedObject var store: LauncherStore
    let controller: LauncherController
    let columns: Int
    let interactive: Bool
    let fadeEdges: Bool

    private let hSpacing: CGFloat = 18
    private let vSpacing: CGFloat = 18
    private let separatorRowHeight: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let cellWidth = max(1, (geo.size.width - CGFloat(columns - 1) * hSpacing) / CGFloat(columns))
            let iconSide = min(cellWidth * 0.77, 108)
            let cellHeight = iconSide + 34
            let contentHeight = CGFloat(rows.count) * cellHeight
                + CGFloat(max(0, rows.count - 1)) * vSpacing
            let extra = max(0, geo.size.height - contentHeight - 16)
            let rowSpacing = vSpacing + min(extra / CGFloat(max(1, rows.count - 1)), 44)

            ScrollView(.vertical) {
                VStack(spacing: rowSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        switch row {
                        case .cells(let items):
                            HStack(spacing: hSpacing) {
                                ForEach(0 ..< columns, id: \.self) { index in
                                    if index < items.count {
                                        ItemCell(
                                            item: items[index],
                                            store: store,
                                            controller: controller,
                                            iconSide: iconSide,
                                            cellWidth: cellWidth,
                                            interactive: interactive
                                        )
                                        .frame(width: cellWidth, height: cellHeight)
                                    } else {
                                        Color.clear
                                            .frame(width: cellWidth, height: cellHeight)
                                    }
                                }
                            }

                        case .separator:
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 1)
                                .padding(.horizontal, 8)
                                .frame(height: separatorRowHeight)
                        }
                    }
                }
                .frame(width: geo.size.width)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .mask {
                if fadeEdges {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 20)
                        Rectangle()
                            .fill(.black)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 34)
                    }
                } else {
                    Rectangle()
                        .fill(.black)
                }
            }
        }
    }
}

private struct ItemCell: View {
    let item: RootItem
    @ObservedObject var store: LauncherStore
    let controller: LauncherController
    let iconSide: CGFloat
    let cellWidth: CGFloat
    let interactive: Bool

    @State private var isHovering = false
    @State private var isTargeted = false

    private var appID: String? {
        if case .app(let id) = item { return id }
        return nil
    }

    private var folder: LauncherFolder? {
        if case .folder(let folder) = item { return folder }
        return nil
    }

    private var title: String {
        if let appID, let app = store.app(for: appID) { return app.name }
        return folder?.name ?? ""
    }

    private var isFavorite: Bool {
        guard let appID else { return false }
        return store.isFavorite(appID)
    }

    var body: some View {
        VStack(spacing: 9) {
            icon
                .frame(width: iconSide, height: iconSide)
                .overlay(alignment: .topTrailing) {
                    if store.isEditingFavorites, appID != nil {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isFavorite ? Color.pink : Color.white.opacity(0.9))
                            .frame(width: 23, height: 23)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                            .offset(x: 5, y: -5)
                    }
                }

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                .frame(width: max(40, cellWidth - 8))
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isHovering || isTargeted ? 0.08 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(isTargeted ? 0.95 : 0), lineWidth: 2)
        )
        .scaleEffect(isTargeted ? 1.04 : 1)
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: isTargeted)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onHover { isHovering = $0 }
        .onTapGesture(perform: activate)
        .modifier(AppDrag(item: item))
        .onDrop(
            of: [.plainText],
            delegate: ItemDropDelegate(
                item: item,
                store: store,
                enabled: interactive,
                cellWidth: cellWidth,
                isTargeted: $isTargeted
            )
        )
        .contextMenu {
            if let appID, let app = store.app(for: appID) {
                Button("Open") { controller.launch(app) }
                Button(isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                    store.toggleFavorite(appID)
                }
            } else if let folder {
                Button("Open Folder") { store.openFolderID = folder.id }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let appID, let app = store.app(for: appID) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
        } else if let folder {
            FolderIconView(folder: folder, store: store)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
        }
    }

    private func activate() {
        switch item {
        case .app(let appID):
            if store.isEditingFavorites {
                store.toggleFavorite(appID)
            } else if let app = store.app(for: appID) {
                controller.launch(app)
            }
        case .folder(let folder):
            guard !store.isEditingFavorites else { return }
            store.openFolderID = folder.id
        }
    }
}

struct FolderIconView: View {
    let folder: LauncherFolder
    @ObservedObject var store: LauncherStore

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inset = side * 0.13
            let spacing = side * 0.035
            let miniSide = (side - inset * 2 - spacing * 2) / 3
            let previews = Array(folder.appIDs.compactMap { store.app(for: $0) }.prefix(9))

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .fill(Color.white.opacity(0.13))

                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(miniSide), spacing: spacing), count: 3),
                    spacing: spacing
                ) {
                    ForEach(previews) { app in
                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: miniSide, height: miniSide)
                    }
                }
                .frame(width: side - inset * 2, height: side - inset * 2)
            }
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
        }
    }
}

private struct AppDrag: ViewModifier {
    let item: RootItem

    @State private var isMoveDrag = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 14) {
                isMoveDrag = true
            } onPressingChanged: { pressing in
                if !pressing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isMoveDrag = false
                    }
                }
            }
            .onDrag {
                let payload: String
                switch item {
                case .app(let appID):
                    payload = isMoveDrag ? DragPayload.movedApp(appID) : DragPayload.app(appID)
                case .folder(let folder):
                    payload = isMoveDrag ? DragPayload.movedFolder(folder.id) : DragPayload.folder(folder.id)
                }
                if isMoveDrag {
                    DispatchQueue.main.async { isMoveDrag = false }
                }
                return NSItemProvider(object: payload as NSString)
            }
    }
}

private struct ItemDropDelegate: DropDelegate {
    let item: RootItem
    let store: LauncherStore
    let enabled: Bool
    let cellWidth: CGFloat
    @Binding var isTargeted: Bool

    func validateDrop(info: DropInfo) -> Bool {
        enabled
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard enabled, let provider = info.itemProviders(for: [.plainText]).first else { return false }

        let placeAfter = info.location.x > cellWidth / 2
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let payload = object as? String else { return }
            DispatchQueue.main.async {
                if let moved = DragPayload.movedItem(from: payload) {
                    store.moveRootItem(moved, relativeTo: item, placeAfter: placeAfter)
                } else if let appID = DragPayload.appID(from: payload) {
                    store.dropApp(appID, onto: item)
                }
            }
        }
        return true
    }
}
