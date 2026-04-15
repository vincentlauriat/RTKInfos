import SwiftUI
import AppKit

/// The SwiftUI entry point for RTKMenuBar.
///
/// Uses `@NSApplicationDelegateAdaptor` to bridge to `AppDelegate`, which initializes
/// `StatsModel` before any view renders, preventing nil environment object crashes.
@main
struct RTKMenuBarApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("RTK Token Savings") {
            DashboardView()
                .environmentObject(appDelegate.model)
        }
        .defaultSize(width: 1060, height: 560)

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

    /// Menu bar status item (toujours présent, quel que soit le mode).
    private var statusItem: NSStatusItem?

    override init() {
        // Use saved path only if the file actually exists; fall back to auto-detection otherwise.
        let savedPath = UserDefaults.standard.string(forKey: "dbPath")
        let dbPath: String
        if let saved = savedPath, FileManager.default.fileExists(atPath: saved) {
            dbPath = saved
        } else {
            dbPath = StatsModel.defaultDBPath
            // Clear the stale preference so Settings shows the correct path
            if savedPath != nil {
                UserDefaults.standard.removeObject(forKey: "dbPath")
            }
        }
        let polling = UserDefaults.standard.double(forKey: "pollingInterval").nonZeroOr(30)
        model = StatsModel(dbPath: dbPath, pollingInterval: polling)
        super.init()
    }

    /// Sets the activation policy and starts the model's watcher.
    ///
    /// - `.regular` (défaut) : icône Dock + barre de menu.
    /// - `.accessory`        : barre de menu seulement, pas d'icône Dock.
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnly")
        applyActivationPolicy(menuBarOnly: menuBarOnly)
        setupStatusItem()
        model.start()
    }

    /// Applique la politique d'activation selon le mode choisi.
    func applyActivationPolicy(menuBarOnly: Bool) {
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
    }

    /// Crée l'item ⚡ dans la barre de menu système.
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "RTK")
        button.image?.isTemplate = true  // s'adapte au mode clair/sombre
        button.action = #selector(statusItemClicked)
        button.target = self
        button.toolTip = "RTK Token Savings"
    }

    /// Ouvre (ou ramène au premier plan) la fenêtre principale au clic sur l'item.
    @objc private func statusItemClicked() {
        guard let window = NSApp.windows.first(where: { $0.title == "RTK Token Savings" }) else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Returns `false` so the app keeps running when all windows are closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Re-opens the main window when the user clicks the Dock icon with no visible windows.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
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
