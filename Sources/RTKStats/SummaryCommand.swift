import Foundation
import RTKCore

struct SummaryCommand {
    let snapshot: StatsSnapshot
    let table: Bool
    let plain: Bool

    func render() {
        table ? renderTable() : renderText()
    }

    private func renderText() {
        let p = Painter(plain: plain)
        print(p.bold("RTK Token Savings"))
        print("")

        if snapshot.isDBMissing {
            print(p.red("  ✗ history.db introuvable. Vérifiez que rtk est installé."))
            return
        }

        if let today = snapshot.todayStats {
            print(p.bold("  Aujourd'hui"))
            print("  Commandes     : \(p.cyan(String(today.totalCommands)))")
            print("  Tokens sauvés : \(p.green(formatTokens(today.savedTokens)))  (\(p.green(String(format: "%.1f%%", today.savingsPct))))")
        } else {
            print("  Aujourd'hui   : aucune commande enregistrée")
        }

        if !snapshot.weekStats.isEmpty {
            print("")
            print(p.bold("  7 derniers jours"))
            let pcts = snapshot.weekStats.map(\.savingsPct)
            print("  \(weekBar(pcts: pcts, plain: plain))")
            // Volume-weighted rate, not the mean of per-day percentages
            // (a 3-command day must not weigh as much as a 5000-command day).
            let savedSum = snapshot.weekStats.reduce(0) { $0 + $1.savedTokens }
            let inputSum = snapshot.weekStats.reduce(0) { $0 + $1.inputTokens }
            let avg = inputSum > 0 ? 100.0 * Double(savedSum) / Double(inputSum) : 0
            print("  Taux 7j       : \(p.green(String(format: "%.1f%%", avg)))")
        }

        if let global = snapshot.globalStats {
            print("")
            print(p.bold("  Total"))
            print("  Commandes     : \(p.cyan(String(global.totalCommands)))")
            print("  Tokens sauvés : \(p.green(formatTokens(global.totalSavedTokens)))")
            print("  Taux global   : \(p.green(String(format: "%.1f%%", global.avgSavingsPct)))")
        }

        if snapshot.isInactive {
            print("")
            print(p.yellow("  ⚠ Aucune activité depuis plus de 7 jours"))
        }
    }

    private func renderTable() {
        let p = Painter(plain: plain)
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEE dd/MM"
        dateFmt.locale = Locale(identifier: "fr_FR")

        let header = "Date".padded(to: 12) + "  " + "Cmds".padded(to: 6) + "  "
                   + "Sauvés".padded(to: 10) + "  " + "Moy%"
        print(p.bold(header))
        print(p.dim(String(repeating: "─", count: 42)))

        for day in snapshot.weekStats {
            let row = dateFmt.string(from: day.date).padded(to: 12) + "  "
                    + String(day.totalCommands).padded(to: 6) + "  "
                    + formatTokens(day.savedTokens).padded(to: 10) + "  "
                    + String(format: "%.1f%%", day.savingsPct)
            print(row)
        }

        if snapshot.weekStats.isEmpty {
            print("  (aucune donnée)")
        }
    }
}
