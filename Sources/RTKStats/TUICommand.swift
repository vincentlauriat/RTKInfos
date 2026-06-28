import Foundation
import Darwin
import RTKCore

struct TUICommand {
    let dbPath: String
    let interval: TimeInterval

    func run() async throws {
        let oldTerm = enableRawMode()
        print(ANSI.hideCursor, terminator: "")
        fflush(stdout)

        defer {
            restoreTerminal(oldTerm)
            print(ANSI.showCursor, terminator: "")
            print("")
            fflush(stdout)
        }

        let loader = StatsLoader(dbPath: dbPath)
        var snapshot = (try? loader.load()) ?? .empty
        let state = TUIState()

        Task.detached {
            var byte: UInt8 = 0
            while !(await state.isDone) {
                withUnsafeMutablePointer(to: &byte) { ptr in _ = read(STDIN_FILENO, ptr, 1) }
                switch byte {
                case UInt8(ascii: "q"), UInt8(ascii: "Q"), 3:
                    await state.quit()
                case UInt8(ascii: "t"), UInt8(ascii: "T"):
                    await state.toggleTop()
                case UInt8(ascii: "r"), UInt8(ascii: "R"):
                    await state.requestRefresh()
                default:
                    break
                }
            }
        }

        let dirPath = URL(fileURLWithPath: dbPath).deletingLastPathComponent().path
        let watcher = DBWatcher(directoryPath: dirPath, pollingInterval: interval)
        watcher.start()
        defer { watcher.stop() }

        render(snapshot: snapshot, showTop: await state.showTop)

        for await _ in watcher.events {
            if await state.isDone { break }
            snapshot = (try? loader.load()) ?? snapshot
            render(snapshot: snapshot, showTop: await state.showTop)
        }
    }

    private func render(snapshot: StatsSnapshot, showTop: Bool) {
        print(ANSI.clearScreen, terminator: "")
        print(ANSI.bold("╔══════════════════════════════════════════════╗"))
        print(ANSI.bold("║            RTK Token Savings                 ║"))
        print(ANSI.bold("╚══════════════════════════════════════════════╝"))
        print("")

        if snapshot.isDBMissing {
            print(ANSI.red("  ✗ history.db introuvable"))
        } else if showTop {
            renderTop(snapshot: snapshot)
        } else {
            renderMain(snapshot: snapshot)
        }

        printFooter()
        fflush(stdout)
    }

    private func renderMain(snapshot: StatsSnapshot) {
        if let today = snapshot.todayStats {
            print(ANSI.bold("  AUJOURD'HUI"))
            print("  Commandes     \(ANSI.cyan(String(today.totalCommands).padded(to: 8)))  Tokens sauvés  \(ANSI.green(formatTokens(today.savedTokens)))")
            print("  Taux savings  \(ANSI.green(String(format: "%.1f%%", today.savingsPct)))")
        } else {
            print("  AUJOURD'HUI   aucune commande")
        }
        print("")

        if !snapshot.weekStats.isEmpty {
            print(ANSI.bold("  7 DERNIERS JOURS"))
            let pcts = snapshot.weekStats.map(\.savingsPct)
            print("  \(weekBar(pcts: pcts, plain: false))")
            // Volume-weighted rate, not the mean of per-day percentages.
            let savedSum = snapshot.weekStats.reduce(0) { $0 + $1.savedTokens }
            let inputSum = snapshot.weekStats.reduce(0) { $0 + $1.inputTokens }
            let avg = inputSum > 0 ? 100.0 * Double(savedSum) / Double(inputSum) : 0
            print("  Taux 7j : \(ANSI.green(String(format: "%.1f%%", avg)))")
            print("")
        }

        if !snapshot.recentCommands.isEmpty {
            print(ANSI.bold("  RÉCENTS"))
            let fmt = RelativeDateTimeFormatter()
            fmt.unitsStyle = .short
            for cmd in snapshot.recentCommands.prefix(5) {
                let rel = fmt.localizedString(for: cmd.timestamp, relativeTo: Date())
                let pct = String(format: "%5.1f%%", cmd.savingsPct)
                let name = String(cmd.rtkCmd.prefix(28)).padded(to: 28)
                print("  \(ANSI.dim(rel.padded(to: 8)))  \(name)  \(ANSI.green(pct))")
            }
        }

        if snapshot.isInactive {
            print("")
            print(ANSI.yellow("  ⚠ Aucune activité depuis > 7 jours"))
        }
    }

    private func renderTop(snapshot: StatsSnapshot) {
        print(ANSI.bold("  TOP COMMANDES (par tokens sauvés)"))
        print("")
        for (i, cmd) in snapshot.topCommands.prefix(10).enumerated() {
            let bar = String(repeating: "█", count: max(1, Int(cmd.impactRatio * 20)))
            let name = String(cmd.command.prefix(24)).padded(to: 24)
            print("  \(String(i + 1).padded(to: 2)). \(name)  \(ANSI.green(bar))  \(formatTokens(cmd.totalSaved))")
        }
    }

    private func printFooter() {
        print("")
        print(ANSI.dim("  [q] quitter   [r] refresh   [t] top commandes"))
    }

    private func enableRawMode() -> termios {
        var old = termios()
        tcgetattr(STDIN_FILENO, &old)
        var raw = old
        raw.c_lflag &= ~(tcflag_t(ECHO) | tcflag_t(ICANON))
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: cc_t.self)
            base[Int(VMIN)]  = 1
            base[Int(VTIME)] = 0
        }
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        return old
    }

    private func restoreTerminal(_ term: termios) {
        var t = term
        tcsetattr(STDIN_FILENO, TCSANOW, &t)
    }
}

actor TUIState {
    private(set) var showTop      = false
    private(set) var isDone       = false
    private(set) var needsRefresh = false

    func toggleTop()      { showTop.toggle() }
    func quit()           { isDone = true }
    func requestRefresh() { needsRefresh = true }
    func clearRefresh()   { needsRefresh = false }
}
