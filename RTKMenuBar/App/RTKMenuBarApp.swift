import SwiftUI
import AppKit

@main
struct RTKMenuBarApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("RTK Token Savings") {
            DashboardView()
                .environment(appDelegate.model)
        }
        .defaultSize(width: 640, height: 560)

        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var model: StatsModel!

    override init() {
        let dbPath = UserDefaults.standard.string(forKey: "dbPath") ?? StatsModel.defaultDBPath
        let polling = UserDefaults.standard.double(forKey: "pollingInterval").nonZeroOr(30)
        model = StatsModel(dbPath: dbPath, pollingInterval: polling)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}

// MARK: - Helpers

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
