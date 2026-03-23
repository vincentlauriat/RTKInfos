import SwiftUI
import AppKit

@main
struct RTKMenuBarApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Pas de window principale — menu bar app uniquement
        Settings {
            SettingsView()
                .environment(AppDelegate.shared.model)
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
    private var observerHostingView: NSView?
    private var observerWindow: NSWindow?  // Strong reference — requis pour ARC

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = StatsModel(
            dbPath: UserDefaults.standard.string(forKey: "dbPath") ?? StatsModel.defaultDBPath,
            pollingInterval: UserDefaults.standard.double(forKey: "pollingInterval").nonZeroOr(30)
        )
        model.start()
        setupStatusItem()
        setupPopover()
        setupObserver()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.title = "rtk —"
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

    // MARK: - Observation via NSHostingView fantôme

    private func setupObserver() {
        struct ObserverView: View {
            let model: StatsModel
            let onChange: (StatsSnapshot) -> Void

            var body: some View {
                Color.clear
                    .frame(width: 0, height: 0)
                    .onChange(of: model.snapshot.todaySavingsPct) { _, _ in
                        onChange(model.snapshot)
                    }
            }
        }

        let hostingView = NSHostingView(
            rootView: ObserverView(model: model) { [weak self] _ in
                self?.updateStatusBar()
            }
        )
        hostingView.frame = .zero

        let offscreenWindow = NSWindow(
            contentRect: NSRect(x: -1000, y: -1000, width: 1, height: 1),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        offscreenWindow.contentView = hostingView
        offscreenWindow.orderOut(nil)
        observerHostingView = hostingView
        observerWindow = offscreenWindow  // Retain explicite — ARC ne doit pas libérer
    }

    // MARK: - Mise à jour du label

    func updateStatusBar() {
        guard let button = statusItem?.button else { return }
        let snapshot = model.snapshot

        if let pct = snapshot.todaySavingsPct {
            button.title = "rtk \(Int(pct))%"
            button.contentTintColor = savingsColor(pct)
        } else {
            button.title = "rtk —"
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
