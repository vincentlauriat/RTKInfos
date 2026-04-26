import ArgumentParser
import RTKCore

@main
struct RTKStatsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "rtk-stats",
        abstract: "Affiche les statistiques de token savings RTK",
        version: "1.0.0"
    )

    @Flag(name: .long, help: "Mode TUI interactif")
    var tui = false

    @Flag(name: .long, help: "Sortie en tableau aligné")
    var table = false

    @Flag(name: .long, help: "Sortie sans couleurs ANSI (pour scripts)")
    var plain = false

    @Option(name: .long, help: "Chemin vers history.db")
    var db: String?

    @Option(name: .long, help: "Intervalle de refresh en secondes (mode TUI, défaut: 5)")
    var interval: Double = 5.0

    mutating func run() async throws {
        let dbPath = db ?? resolveDefaultDBPath()

        if tui {
            try await TUICommand(dbPath: dbPath, interval: interval).run()
        } else {
            let loader = StatsLoader(dbPath: dbPath)
            let snapshot = try loader.load()
            SummaryCommand(snapshot: snapshot, table: table, plain: plain).render()
        }
    }
}
