import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FolderView: View {
    let folder: LauncherFolder
    @ObservedObject var store: LauncherStore
    let controller: LauncherController

    @State private var name: String
    @State private var isTargeted = false
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
                    .onDrop(of: [.plainText], isTargeted: $isTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadObject(ofClass: NSString.self) { object, _ in
                            guard let payload = object as? String,
                                  let appID = DragPayload.appID(from: payload) else { return }
                            DispatchQueue.main.async {
                                store.moveOutOfFolder(appID: appID, folderID: folder.id)
                            }
                        }
                        return true
                    }

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
                                    folderID: folder.id
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
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(isTargeted ? 0.55 : 0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.45), radius: 34, y: 22)
            }
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

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSide, height: iconSide)
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
                .fill(Color.white.opacity(isHovering ? 0.09 : 0))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture {
            controller.launch(app)
        }
        .onDrag {
            NSItemProvider(object: DragPayload.app(app.id) as NSString)
        }
        .contextMenu {
            Button("Open") { controller.launch(app) }
            Button("Remove from Folder") { store.moveOutOfFolder(appID: app.id, folderID: folderID) }
        }
    }
}
