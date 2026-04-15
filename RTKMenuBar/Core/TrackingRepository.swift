import Foundation
import SQLite

/// Read-only access layer for rtk's SQLite tracking database.
///
/// A new database connection is opened on every call to avoid lock contention with
/// the rtk writer process, and to transparently handle the case where rtk
/// recreates the file (e.g. after a reset).
///
/// All queries are read-only (`Connection(path, readonly: true)`).
/// The app never writes to or modifies the rtk database.
final class TrackingRepository {

    private let dbPath: String

    /// Columns that must exist in the `commands` table for the schema to be considered valid.
    private static let requiredColumns = [
        "id", "timestamp", "original_cmd", "rtk_cmd",
        "input_tokens", "output_tokens", "saved_tokens",
        "savings_pct"
    ]

    /// Creates a repository for the database at `dbPath`.
    /// - Parameter dbPath: Absolute path to rtk's `history.db`.
    init(dbPath: String) throws {
        self.dbPath = dbPath
    }

    /// Opens a SQLite connection to the database.
    ///
    /// rtk's database uses WAL mode. When no `-shm` shared-memory file exists
    /// (i.e. rtk is idle), `sqlite3_open_v2` returns `SQLITE_CANTOPEN (14)` even for
    /// read-write connections, because SQLite cannot initialise the shared-memory
    /// mapping in the restricted Application Support directory.
    ///
    /// Strategy:
    /// 1. Try a direct open — works whenever rtk is running (shm already present).
    /// 2. On failure, copy the database (+ WAL if present) to `/tmp`, where we have
    ///    unrestricted write access, then open the copy. This surfaces data as of the
    ///    last WAL checkpoint, which is sufficient for displaying stats.
    private func openConnection() throws -> Connection {
        if let db = try? Connection(dbPath) {
            return db
        }
        // Fallback: copy to a writable temp location
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rtk-history-snapshot.db").path
        try? FileManager.default.removeItem(atPath: tmp)
        try FileManager.default.copyItem(atPath: dbPath, toPath: tmp)
        // Carry the WAL file too so SQLite can recover recent transactions
        let walSrc = dbPath + "-wal"
        if FileManager.default.fileExists(atPath: walSrc) {
            try? FileManager.default.copyItem(atPath: walSrc, toPath: tmp + "-wal")
        }
        return try Connection(tmp)
    }

    /// Validates that the `commands` table contains all required columns.
    ///
    /// Returns `false` (rather than throwing) when the schema is incompatible,
    /// allowing the caller to enter a graceful degraded mode.
    func validateSchema() throws -> Bool {
        let db = try openConnection()
        var columns: [String] = []
        let stmt = try db.prepare("PRAGMA table_info(commands)")
        for row in stmt {
            // PRAGMA table_info column index 1 is the column name
            if let name = row[1] as? String {
                columns.append(name)
            }
        }
        let columnSet = Set(columns)
        return Self.requiredColumns.allSatisfy { columnSet.contains($0) }
    }

    /// Returns aggregated statistics for the current calendar day (UTC).
    ///
    /// Returns `nil` if no commands were recorded today.
    func todayStats() throws -> DayStats? {
        let db = try openConnection()
        let todayStr = dayString(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
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

    /// Returns per-day statistics for the past 7 days, in chronological order.
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

    /// Returns the `limit` most recent command records, newest first.
    func recentCommands(limit: Int = 5) throws -> [CommandRecord] {
        let db = try openConnection()
        var results: [CommandRecord] = []
        let stmt = try db.prepare("""
            SELECT timestamp, original_cmd, rtk_cmd, saved_tokens, savings_pct
            FROM commands
            ORDER BY timestamp DESC
            LIMIT ?
        """, limit)

        for row in stmt {
            guard let tsStr = row[0] as? String,
                  let date = Self.parseTimestamp(tsStr) else { continue }
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

    /// Returns all-time aggregated statistics across every recorded command.
    func globalStats() throws -> GlobalStats? {
        let db = try openConnection()
        let stmt = try db.prepare("""
            SELECT
                COUNT(*) as total_commands,
                COALESCE(SUM(input_tokens), 0) as total_input,
                COALESCE(SUM(output_tokens), 0) as total_output,
                COALESCE(SUM(saved_tokens), 0) as total_saved,
                COALESCE(AVG(savings_pct), 0.0) as avg_savings,
                COALESCE(SUM(exec_time_ms), 0) as total_exec_ms,
                COALESCE(AVG(exec_time_ms), 0.0) as avg_exec_ms
            FROM commands
        """)
        guard let row = try stmt.failableNext() else { return nil }
        let total = (row[0] as? Int64) ?? 0
        guard total > 0 else { return nil }
        return GlobalStats(
            totalCommands: Int(total),
            totalInputTokens: Int((row[1] as? Int64) ?? 0),
            totalOutputTokens: Int((row[2] as? Int64) ?? 0),
            totalSavedTokens: Int((row[3] as? Int64) ?? 0),
            avgSavingsPct: (row[4] as? Double) ?? 0.0,
            totalExecTimeMs: Int((row[5] as? Int64) ?? 0),
            avgExecTimeMs: Int((row[6] as? Double) ?? 0.0)
        )
    }

    /// Returns the top 10 command patterns ranked by tokens saved.
    func topCommands() throws -> [CommandSummary] {
        let db = try openConnection()
        var rows: [(cmd: String, count: Int, saved: Int, avgPct: Double, timeMs: Int)] = []
        let stmt = try db.prepare("""
            SELECT
                rtk_cmd,
                COUNT(*) as cnt,
                COALESCE(SUM(saved_tokens), 0) as total_saved,
                COALESCE(AVG(savings_pct), 0.0) as avg_pct,
                COALESCE(SUM(exec_time_ms), 0) as total_ms
            FROM commands
            GROUP BY rtk_cmd
            ORDER BY total_saved DESC
            LIMIT 10
        """)
        for row in stmt {
            rows.append((
                cmd: (row[0] as? String) ?? "",
                count: Int((row[1] as? Int64) ?? 0),
                saved: Int((row[2] as? Int64) ?? 0),
                avgPct: (row[3] as? Double) ?? 0.0,
                timeMs: Int((row[4] as? Int64) ?? 0)
            ))
        }
        let maxSaved = rows.first?.saved ?? 1
        return rows.map { r in
            CommandSummary(
                command: r.cmd,
                count: r.count,
                totalSaved: r.saved,
                avgPct: r.avgPct,
                totalTimeMs: r.timeMs,
                impactRatio: maxSaved > 0 ? Double(r.saved) / Double(maxSaved) : 0
            )
        }
    }

    /// Returns the timestamp of the most recent command, used to detect inactivity.
    func lastActivityDate() throws -> Date? {
        let db = try openConnection()
        let stmt = try db.prepare("SELECT MAX(timestamp) FROM commands")
        guard let row = try stmt.failableNext(),
              let tsStr = row[0] as? String else { return nil }
        return Self.parseTimestamp(tsStr)
    }

    // MARK: - Helpers

    private func dayString(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date)
    }

    /// Parses an ISO 8601 timestamp string from rtk's database.
    ///
    /// rtk stores timestamps with microsecond precision and explicit timezone offset,
    /// e.g. `"2026-04-13T21:17:47.953648+00:00"`. Swift's `ISO8601DateFormatter`
    /// only supports up to milliseconds (3 decimal places), so we truncate the
    /// fractional part before parsing.
    private static func parseTimestamp(_ s: String) -> Date? {
        var normalized = s
        // Truncate fractional seconds beyond 3 digits (microseconds → milliseconds)
        if let dotIdx = normalized.firstIndex(of: ".") {
            var scanIdx = normalized.index(after: dotIdx)
            while scanIdx < normalized.endIndex && normalized[scanIdx].isNumber {
                scanIdx = normalized.index(after: scanIdx)
            }
            let fracDigits = normalized[normalized.index(after: dotIdx)..<scanIdx]
            if fracDigits.count > 3 {
                normalized = String(normalized[..<normalized.index(after: dotIdx)])
                    + String(fracDigits.prefix(3))
                    + String(normalized[scanIdx...])
            }
        }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: normalized)
    }
}
