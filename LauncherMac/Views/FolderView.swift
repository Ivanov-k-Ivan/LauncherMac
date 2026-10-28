import AppKit
import SwiftUI

@MainActor
private final class FolderDragState: ObservableObject {
    @Published private(set) var appID: String?
    @Published private(set) var targetID: String?
    @Published private(set) var placeAfter = false
    @Published var location: CGPoint?

    var frames: [String: CGRect] = [:]
    var iconFrames: [String: CGRect] = [:]
    var panelFrame: CGRect = .zero
    var isInGap = false

    func begin(appID: String, location: CGPoint) {
        self.appID = appID
        self.location = location
    }

    func update(location: CGPoint) {
        self.location = location
        guard let appID else { return }

        if let slot = gapSlot(at: location) {
            isInGap = true
            if isNoOp(slot, sourceID: appID) {
                clearTarget()
            } else {
                if targetID != slot.targetID { targetID = slot.targetID }
                if placeAfter != slot.placeAfter { placeAfter = slot.placeAfter }
            }
        } else {
            isInGap = false
            clearTarget()
        }
    }

    func finish(store: LauncherStore, folderID: UUID) {
        guard let appID else { return }

        let gapTarget = targetID
        let gapAfter = placeAfter
        let inGap = isInGap
        let inside = gapTarget != nil || (location.map { panelFrame.contains($0) } ?? false)
        let iconTarget = gapTarget == nil && !inGap ? target(at: location, excluding: appID) : nil
        reset()

        if let gapTarget {
            store.reorderFolderApp(appID, in: folderID, relativeTo: gapTarget, placeAfter: gapAfter)
        } else if inGap {
            return
        } else if inside {
            store.reorderFolderApp(appID, in: folderID, relativeTo: iconTarget?.id, placeAfter: iconTarget?.after ?? false)
        } else {
            store.moveOutOfFolder(appID: appID, folderID: folderID)
        }
    }

    func cancel() {
        reset()
    }

    func insertionPoint() -> CGPoint? {
        guard isInGap,
              let targetID,
              let icon = iconFrames[targetID] ?? frames[targetID] else { return nil }

        let x: CGFloat
        if placeAfter {
            x = icon.maxX + 12
        } else if let leftIcon = leftIcon(before: icon) {
            x = (leftIcon.maxX + icon.minX) / 2
        } else {
            x = icon.minX - 12
        }
        return CGPoint(x: x, y: icon.midY)
    }

    func insertionHeight() -> CGFloat {
        guard let targetID,
              let icon = iconFrames[targetID] ?? frames[targetID] else { return 60 }
        return icon.height + 12
    }

    private func leftIcon(before icon: CGRect) -> CGRect? {
        iconFrames.values
            .filter {
                abs($0.midY - icon.midY) < 1
                    && $0.maxX <= icon.minX
                    && icon.minX - $0.maxX < 200
            }
            .max { $0.maxX < $1.maxX }
    }

    private func clearTarget() {
        if targetID != nil { targetID = nil }
        if placeAfter { placeAfter = false }
    }

    private func reset() {
        appID = nil
        clearTarget()
        isInGap = false
        location = nil
    }

    private func target(at location: CGPoint?, excluding sourceID: String) -> (id: String, after: Bool)? {
        guard let location,
              let (id, frame) = frames.first(where: { $0.value.contains(location) }),
              id != sourceID else { return nil }
        return (id, location.x > frame.midX)
    }

    private func gapSlot(at location: CGPoint) -> FolderDropSlot? {
        let row = frames
            .filter { location.y >= $0.value.minY - 2 && location.y <= $0.value.maxY + 2 }
            .sorted { iconFrame(for: $0.key, fallback: $0.value).midX < iconFrame(for: $1.key, fallback: $1.value).midX }
        guard !row.isEmpty else { return nil }

        let firstIcon = iconFrame(for: row[0].key, fallback: row[0].value)
        if location.x < firstIcon.minX {
            return FolderDropSlot(targetID: row[0].key, placeAfter: false, neighborID: nil)
        }

        let last = row[row.count - 1]
        let lastIcon = iconFrame(for: last.key, fallback: last.value)
        if location.x > lastIcon.maxX {
            return FolderDropSlot(targetID: last.key, placeAfter: true, neighborID: nil)
        }

        for index in 1 ..< row.count {
            let left = row[index - 1]
            let right = row[index]
            let leftIcon = iconFrame(for: left.key, fallback: left.value)
            let rightIcon = iconFrame(for: right.key, fallback: right.value)
            if location.x >= leftIcon.maxX, location.x <= rightIcon.minX {
                return FolderDropSlot(targetID: right.key, placeAfter: false, neighborID: left.key)
            }
        }
        return nil
    }

    private func iconFrame(for id: String, fallback: CGRect) -> CGRect {
        iconFrames[id] ?? fallback
    }

    private func isNoOp(_ slot: FolderDropSlot, sourceID: String) -> Bool {
        slot.targetID == sourceID || slot.neighborID == sourceID
    }
}

private struct FolderDropSlot {
    let targetID: String
    let placeAfter: Bool
    let neighborID: String?
}

private struct FolderPanelFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private struct FolderCellFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct FolderIconFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct FolderView: View {
    let folder: LauncherFolder
    @ObservedObject var store: LauncherStore
    let controller: LauncherController

    @State private var name: String
    @State private var showDeleteConfirmation = false
    @StateObject private var drag = FolderDragState()
    @FocusState private var nameFocused: Bool

    private let spacing: CGFloat = 18
    private let cellWidth: CGFloat = 104
    private let iconSide: CGFloat = 66

    init(folder: LauncherFolder, store: LauncherStore, controller: LauncherController) {
        self.folder = folder
        self.store = store
        self.controller = controller
        _name = State(initialValue: folder.name)
    }

    private var apps: [AppInfo] {
        folder.appIDs.compactMap { store.app(for: $0) }
    }

    var body: some View {
        GeometryReader { geo in
            let maxPanelWidth = min(geo.size.width * 0.8, 780)
            let maxColumns = max(1, Int((maxPanelWidth - 56 + spacing) / (cellWidth + spacing)))
            let columnCount = min(maxColumns, max(2, apps.count))
            let panelWidth = CGFloat(columnCount) * cellWidth + CGFloat(columnCount - 1) * spacing + 56
            let rowCount = max(1, Int(ceil(Double(apps.count) / Double(columnCount))))
            let rowHeight = cellWidth + 6
            let gridHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1)) * spacing
            let scrollHeight = min(gridHeight + 8, 460)

            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)

                VStack(spacing: 14) {
                    TextField("Folder", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .focused($nameFocused)
                        .focusEffectDisabled()
                        .onSubmit {
                            commitName()
                            nameFocused = false
                        }
                        .frame(maxWidth: 260)

                    ScrollView {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.fixed(cellWidth), spacing: spacing),
                                count: columnCount
                            ),
                            alignment: .center,
                            spacing: spacing
                        ) {
                            ForEach(apps) { app in
                                FolderAppCell(
                                    app: app,
                                    store: store,
                                    controller: controller,
                                    iconSide: iconSide,
                                    folderID: folder.id,
                                    drag: drag
                                )
                                .frame(width: cellWidth, height: cellWidth + 6)
                            }
                        }
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: scrollHeight)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(width: panelWidth)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: FolderPanelFrameKey.self,
                            value: geo.frame(in: .global)
                        )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 34, y: 22)
                .overlay(alignment: .topTrailing) {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete Folder")
                    .padding(14)
                }
            }
            .overlay {
                GeometryReader { geo in
                    let origin = geo.frame(in: .global).origin
                    ZStack {
                        if drag.insertionPoint() == nil,
                           let appID = drag.appID,
                           let app = store.app(for: appID),
                           let location = drag.location {
                            Image(nsImage: app.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                                .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                                .opacity(0.92)
                                .position(x: location.x - origin.x, y: location.y - origin.y)
                        }

                        if let point = drag.insertionPoint() {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 4, height: drag.insertionHeight())
                                .shadow(color: Color.accentColor.opacity(0.85), radius: 5)
                                .position(x: point.x - origin.x, y: point.y - origin.y)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(FolderPanelFrameKey.self) { drag.panelFrame = $0 }
        .onPreferenceChange(FolderCellFramesKey.self) { drag.frames = $0 }
        .onPreferenceChange(FolderIconFramesKey.self) { drag.iconFrames = $0 }
        .alert("Delete Folder?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteFolder(id: folder.id)
            }
        } message: {
            Text("The apps in “\(folder.name)” will be moved back to the app grid.")
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                nameFocused = true
            }
        }
        .onDisappear(perform: commitName)
    }

    private func commitName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.renameFolder(id: folder.id, name: trimmed.isEmpty ? "Folder" : trimmed)
    }

    private func close() {
        nameFocused = false
        store.openFolderID = nil
    }
}

private struct FolderAppCell: View {
    let app: AppInfo
    @ObservedObject var store: LauncherStore
    let controller: LauncherController
    let iconSide: CGFloat
    let folderID: UUID
    @ObservedObject var drag: FolderDragState

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSide, height: iconSide)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: FolderIconFramesKey.self,
                            value: [app.id: geo.frame(in: .global)]
                        )
                    }
                )
                .shadow(color: .black.opacity(0.28), radius: 4, y: 2)

            Text(app.name)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(drag.appID == nil && isHovering ? 0.09 : 0))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            controller.launch(app)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { value in
                    if drag.appID == nil {
                        drag.begin(appID: app.id, location: value.location)
                    }
                    guard drag.appID == app.id else { return }
                    drag.update(location: value.location)
                }
                .onEnded { _ in
                    guard drag.appID == app.id else { return }
                    drag.finish(store: store, folderID: folderID)
                }
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: FolderCellFramesKey.self,
                    value: [app.id: geo.frame(in: .global)]
                )
            }
        )
        .contextMenu {
            Button("Open") { controller.launch(app) }
            Button("Remove from Folder") { store.moveOutOfFolder(appID: app.id, folderID: folderID) }
        }
    }
}
