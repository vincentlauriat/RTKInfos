import Foundation

/// Stats agrégées pour une journée
struct DayStats {
    let date: Date
    let totalCommands: Int
    let inputTokens: Int
    let outputTokens: Int
    let savedTokens: Int
    let savingsPct: Double  // 0.0 – 100.0
}

/// Enregistrement d'une commande individuelle
struct CommandRecord {
    let timestamp: Date
    let originalCmd: String
    let rtkCmd: String
    let savedTokens: Int
    let savingsPct: Double
}

/// Snapshot complet des stats exposé aux vues
struct StatsSnapshot {
    let todayStats: DayStats?
    let weekStats: [DayStats]       // 7 derniers jours, ordre chronologique
    let recentCommands: [CommandRecord]  // 5 dernières commandes
    let lastActivityDate: Date?
    let isDBMissing: Bool

    var isInactive: Bool {
        guard let last = lastActivityDate else { return false }
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    var todaySavingsPct: Double? {
        todayStats?.savingsPct
    }

    static let empty = StatsSnapshot(
        todayStats: nil,
        weekStats: [],
        recentCommands: [],
        lastActivityDate: nil,
        isDBMissing: true
    )
}
