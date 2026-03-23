import SwiftUI
import AppKit

@main
struct RTKMenuBarApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Pas de window principale — menu bar app uniquement
        // SettingsView n'utilise que @AppStorage, le model n'est pas nécessaire ici
        Settings {
            SettingsView()
        }
    }
}

// MARK: - AppDelegate

/// Stratégie d'observation @Observable depuis AppKit :
/// NSHostingView invisible dans une fenêtre hors-écran. Cette vue observe StatsModel
/// nativement et appelle updateStatusBar() via callback à chaque changement.
/// La fenêtre doit être retenue (observerWindow) sinon ARC la libère.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    static var shared: AppDelegate!

    private(set) var model: StatsModel!

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    override init() {
        // model doit être initialisé ici car SwiftUI évalue Settings{}.body avant applicationDidFinishLaunching
        let dbPath = UserDefaults.standard.string(forKey: "dbPath") ?? StatsModel.defaultDBPath
        let polling = UserDefaults.standard.double(forKey: "pollingInterval").nonZeroOr(30)
        model = StatsModel(dbPath: dbPath, pollingInterval: polling)
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Status item en premier, AVANT le changement de policy
        setupStatusItem()
        setupPopover()
        // Policy .regular = icône Dock visible
        NSApp.setActivationPolicy(.regular)
        model.start()
        observeModel()
    }

    // Clic sur l'icône Dock → ouvre les Préférences
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        return true
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        // Effacer l'état de visibilité persisté (peut rester à false d'une session précédente)
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Visible RTKMenuBarStatusItem")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.autosaveName = "RTKMenuBarStatusItem"
        statusItem?.isVisible = true
        guard let button = statusItem?.button else { return }
        let img = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "RTK")
        img?.isTemplate = true
        button.image = img
        button.imagePosition = .imageLeft
        button.title = " rtk —"
        button.action = #selector(togglePopover)
        button.target = self
        updateStatusBar()
    }


    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environment(model)
        )
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Observation via withObservationTracking (API canonique @Observable)

    private func observeModel() {
        withObservationTracking {
            // Accéder aux propriétés observées pour enregistrer les dépendances
            _ = model.snapshot.todaySavingsPct
            _ = model.snapshot.isDBMissing
        } onChange: { [weak self] in
            // onChange s'exécute hors MainActor — reprogrammer sur MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusBar()
                // Re-enregistrer pour le prochain changement (observation continue)
                self.observeModel()
            }
        }
    }

    // MARK: - Mise à jour du label

    func updateStatusBar() {
        guard let button = statusItem?.button else { return }
        let snapshot = model.snapshot

        if let pct = snapshot.todaySavingsPct {
            button.title = " rtk \(Int(pct))%"
            button.contentTintColor = savingsColor(pct)
        } else {
            button.title = " rtk —"
            button.contentTintColor = .secondaryLabelColor
        }
    }

    private func savingsColor(_ pct: Double) -> NSColor {
        switch pct {
        case 70...: return .systemGreen
        case 40..<70: return .systemOrange
        default: return .systemRed
        }
    }
}

// MARK: - Helpers

private extension Double {
    func nonZeroOr(_ fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}

extension StatsSnapshot: Equatable {
    static func == (lhs: StatsSnapshot, rhs: StatsSnapshot) -> Bool {
        lhs.todaySavingsPct == rhs.todaySavingsPct &&
        lhs.isDBMissing == rhs.isDBMissing
    }
}
