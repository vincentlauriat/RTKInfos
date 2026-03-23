import Foundation
import SQLite

/// Lit la base de données macrtk en read-only.
/// Ouvre une nouvelle connexion à chaque appel pour éviter les locks
/// et garantir la reconnexion si macrtk a recréé le fichier.
final class TrackingRepository {

    private let dbPath: String

    /// Colonnes requises dans la table commands
    private static let requiredColumns = [
        "id", "timestamp", "original_cmd", "rtk_cmd",
        "input_tokens", "output_tokens", "saved_tokens",
        "savings_pct"
    ]

    init(dbPath: String) throws {
        self.dbPath = dbPath
    }

    /// Ouvre une connexion read-only.
    /// Nouvelle connexion à chaque appel = reconnexion automatique si DB recréée.
    private func openConnection() throws -> Connection {
        try Connection(dbPath, readonly: true)
    }

    /// Vérifie que le schéma contient les colonnes attendues.
    func validateSchema() throws -> Bool {
        let db = try openConnection()
        var columns: [String] = []
        let stmt = try db.prepare("PRAGMA table_info(commands)")
        for row in stmt {
            // PRAGMA table_info: col 1 = name
            if let name = row[1] as? String {
                columns.append(name)
            }
        }
        let columnSet = Set(columns)
        return Self.requiredColumns.allSatisfy { columnSet.contains($0) }
    }

    /// Stats agrégées pour aujourd'hui (UTC).
    func todayStats() throws -> DayStats? {
        let db = try openConnection()
        let todayStr = dayString(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowStr = dayString(for: tomorrow)

        let stmt = try db.prepare("""
            SELECT
                COUNT(*) as total_commands,
                COALESCE(SUM(input_tokens), 0) as total_input,
                COALESCE(SUM(output_tokens), 0) as total_output,
                COALESCE(SUM(saved_tokens), 0) as total_saved,
                COALESCE(AVG(savings_pct), 0.0) as avg_savings
            FROM commands
            WHERE timestamp >= ? AND timestamp < ?
        """, todayStr + "T00:00:00Z", tomorrowStr + "T00:00:00Z")

        guard let row = try stmt.failableNext() else { return nil }

        let totalCommands = (row[0] as? Int64) ?? 0
        guard totalCommands > 0 else { return nil }

        return DayStats(
            date: Date(),
            totalCommands: Int(totalCommands),
            inputTokens: Int((row[1] as? Int64) ?? 0),
            outputTokens: Int((row[2] as? Int64) ?? 0),
            savedTokens: Int((row[3] as? Int64) ?? 0),
            savingsPct: (row[4] as? Double) ?? 0.0
        )
    }

    /// Stats par jour pour les 7 derniers jours.
    func weekStats() throws -> [DayStats] {
        let db = try openConnection()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let cutoff = ISO8601DateFormatter().string(from: sevenDaysAgo)

        var results: [DayStats] = []
        let stmt = try db.prepare("""
            SELECT
                date(timestamp) as day,
                COUNT(*) as total_commands,
                COALESCE(SUM(input_tokens), 0),
                COALESCE(SUM(output_tokens), 0),
                COALESCE(SUM(saved_tokens), 0),
                COALESCE(AVG(savings_pct), 0.0)
            FROM commands
            WHERE timestamp >= ?
            GROUP BY day
            ORDER BY day ASC
            LIMIT 7
        """, cutoff)

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")

        for row in stmt {
            guard let dayStr = row[0] as? String,
                  let date = fmt.date(from: dayStr) else { continue }
            results.append(DayStats(
                date: date,
                totalCommands: Int((row[1] as? Int64) ?? 0),
                inputTokens: Int((row[2] as? Int64) ?? 0),
                outputTokens: Int((row[3] as? Int64) ?? 0),
                savedTokens: Int((row[4] as? Int64) ?? 0),
                savingsPct: (row[5] as? Double) ?? 0.0
            ))
        }
        return results
    }

    /// N dernières commandes exécutées.
    func recentCommands(limit: Int = 5) throws -> [CommandRecord] {
        let db = try openConnection()
        var results: [CommandRecord] = []
        let stmt = try db.prepare("""
            SELECT timestamp, original_cmd, rtk_cmd, saved_tokens, savings_pct
            FROM commands
            ORDER BY timestamp DESC
            LIMIT ?
        """, limit)

        let fmt = ISO8601DateFormatter()
        for row in stmt {
            guard let tsStr = row[0] as? String,
                  let date = fmt.date(from: tsStr) else { continue }
            results.append(CommandRecord(
                timestamp: date,
                originalCmd: (row[1] as? String) ?? "",
                rtkCmd: (row[2] as? String) ?? "",
                savedTokens: Int((row[3] as? Int64) ?? 0),
                savingsPct: (row[4] as? Double) ?? 0.0
            ))
        }
        return results
    }

    /// Date du dernier enregistrement (pour détecter inactivité).
    func lastActivityDate() throws -> Date? {
        let db = try openConnection()
        let stmt = try db.prepare("SELECT MAX(timestamp) FROM commands")
        guard let row = try stmt.failableNext(),
              let tsStr = row[0] as? String else { return nil }
        return ISO8601DateFormatter().date(from: tsStr)
    }

    // MARK: - Helpers

    private func dayString(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date)
    }
}
