import SwiftUI
import AppKit
import Sparkle

/// The SwiftUI entry point for RTKInfos.
///
/// Uses `@NSApplicationDelegateAdaptor` to bridge to `AppDelegate`, which initializes
/// `StatsModel` before any view renders, preventing nil environment object crashes.
@main
struct RTKInfosApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.model)
        }
    }
}

// MARK: - AppDelegate

/// Application delegate responsible for the app lifecycle and `StatsModel` initialization.
///
/// `StatsModel` is created in `init()` (before `applicationDidFinishLaunching`) to guarantee
/// the model exists when SwiftUI renders the first frame. Configuration is read from
/// `UserDefaults` so that user preferences (DB path, polling interval) survive relaunches.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// The central data model injected into the SwiftUI environment.
    private(set) var model: StatsModel!

    /// Menu bar status item.
    private var statusItem: NSStatusItem?

    private var mainWindow: NSWindow?

    /// Sparkle in-app updater. `startingUpdater: true` begins background checks immediately.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    override init() {
        RTKFonts.registerIfNeeded()
        let savedPath = UserDefaults.standard.string(forKey: "dbPath")
        let dbPath: String
        if let saved = savedPath, FileManager.default.fileExists(atPath: saved) {
            dbPath = saved
        } else {
            dbPath = StatsModel.defaultDBPath
            if savedPath != nil {
                UserDefaults.standard.removeObject(forKey: "dbPath")
            }
        }
        let polling = UserDefaults.standard.double(forKey: "pollingInterval").nonZeroOr(30)
        model = StatsModel(dbPath: dbPath, pollingInterval: polling)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnly")
        applyActivationPolicy(menuBarOnly: menuBarOnly)
        setupMainWindow()
        setupStatusItem()
        addCheckForUpdatesMenuItem()
        model.start()
    }

    func applyActivationPolicy(menuBarOnly: Bool) {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
    }

    private func setupMainWindow() {
        let content = DashboardView().environmentObject(model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1060, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "RTK Token Savings"
        window.contentView = NSHostingView(rootView: content)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        mainWindow = window
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "RTK")
        button.image?.isTemplate = true
        button.action = #selector(statusItemClicked)
        button.target = self
        button.toolTip = "RTK Token Savings"
    }

    /// Inserts "Check for Updates…" into the app menu (after "About RTKInfos").
    private func addCheckForUpdatesMenuItem() {
        guard let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu else { return }
        let item = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        item.target = self
        appMenu.insertItem(.separator(), at: 1)
        appMenu.insertItem(item, at: 2)
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func statusItemClicked() {
        guard let window = mainWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow?.makeKeyAndOrderFront(nil) }
        return true
    }
}

// MARK: - Helpers

private extension Double {
    /// Returns `self` if non-zero, otherwise returns `fallback`.
    /// Used to guard against a zero `pollingInterval` stored in `UserDefaults`.
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
