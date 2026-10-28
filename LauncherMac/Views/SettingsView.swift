import SwiftUI

struct SettingsView: View {
    let controller: LauncherController

    @AppStorage("gridColumns") private var columns = 7
    @AppStorage("gridRows") private var rows = 4
    @AppStorage("presentationMode") private var presentationMode = LauncherController.Presentation.window.rawValue
    @AppStorage("globalHotKeyEnabled") private var hotKeyEnabled = true
    @AppStorage("scrollMode") private var scrollMode = ScrollMode.vertical.rawValue

    var body: some View {
        Form {
            Section("Grid") {
                Stepper("Columns: \(columns)", value: $columns, in: 4 ... 12)
                Stepper("Rows: \(rows)", value: $rows, in: 3 ... 8)
                Text("\(columns) × \(rows) — \(columns * rows) apps per page")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Scrolling") {
                Picker("Layout", selection: $scrollMode) {
                    Text("Horizontal Pages").tag(ScrollMode.pages.rawValue)
                    Text("Vertical").tag(ScrollMode.vertical.rawValue)
                }
                .pickerStyle(.segmented)

                Text(scrollMode == ScrollMode.vertical.rawValue
                     ? "Apps scroll vertically in one continuous grid."
                     : "Apps are split into pages you can swipe between.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Presentation") {
                Picker("Mode", selection: $presentationMode) {
                    Text("Full Screen").tag(LauncherController.Presentation.overlay.rawValue)
                    Text("Window").tag(LauncherController.Presentation.window.rawValue)
                }
                .pickerStyle(.segmented)
            }

            Section("Shortcut") {
                Toggle("Global shortcut (⌥Space)", isOn: $hotKeyEnabled)
            }

            Section {
                Button("Refresh Apps") {
                    controller.store.reloadApps()
                }
                Button("Reset Layout") {
                    controller.store.resetLayout()
                    controller.resetWindowSize()
                }
            }

            Section {
                Button {
                    columns = 7
                    rows = 4
                    scrollMode = ScrollMode.vertical.rawValue
                    presentationMode = LauncherController.Presentation.window.rawValue
                    controller.store.resetToDefault()
                    DispatchQueue.main.async {
                        controller.resetWindowSize()
                    }
                } label: {
                    Text("Reset to Default")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onChange(of: presentationMode) { _, _ in
            controller.presentationChanged()
        }
        .onChange(of: hotKeyEnabled) { _, _ in
            controller.refreshHotKey()
        }
    }
}
