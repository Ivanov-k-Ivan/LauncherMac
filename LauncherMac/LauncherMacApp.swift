import AppKit
import SwiftUI

@main
struct LauncherMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = LauncherController.shared

    var body: some Scene {
        Settings {
            SettingsView(controller: controller)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Show Launcher") {
                    controller.show()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Launcher") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = LauncherController.shared
        controller.setup()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            controller.show()
        }

    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LauncherController.shared.showIfNeeded()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
