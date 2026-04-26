import Foundation

/// Aggregated token savings statistics for a single calendar day.
struct DayStats {
    /// The calendar day these stats represent.
    let date: Date
    /// Total number of commands executed through rtk on this day.
    let totalCommands: Int
    /// Total input tokens sent to Claude (after rtk optimization).
    let inputTokens: Int
    /// Total output tokens received from Claude.
    let outputTokens: Int
    /// Total tokens saved compared to the unoptimized requests.
    let savedTokens: Int
    /// Average savings percentage across all commands (0.0–100.0).
    let savingsPct: Double
}

/// A single command execution record as stored by rtk.
struct CommandRecord {
    /// When the command was executed (UTC).
    let timestamp: Date
    /// The original command before rtk rewriting.
    let originalCmd: String
    /// The optimized command sent to Claude.
    let rtkCmd: String
    /// Tokens saved compared to the original request.
    let savedTokens: Int
    /// Savings as a percentage of the original token count (0.0–100.0).
    let savingsPct: Double
}

/// Aggregated all-time statistics across every recorded command.
struct GlobalStats {
    let totalCommands: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalSavedTokens: Int
    let avgSavingsPct: Double
    let totalExecTimeMs: Int
    let avgExecTimeMs: Int
}

/// A summary of one command pattern, ranked by tokens saved.
struct CommandSummary {
    let command: String
    let count: Int
    let totalSaved: Int
    let avgPct: Double
    let totalTimeMs: Int
    /// Relative impact 0.0–1.0 (proportion of the top command's saved tokens).
    let impactRatio: Double
}

/// An immutable snapshot of all statistics exposed to SwiftUI views.
///
/// `StatsModel` replaces `snapshot` atomically on every refresh, which triggers
/// SwiftUI to re-render only the views that depend on changed fields.
struct StatsSnapshot {
    /// Statistics for today, or `nil` if no commands were run today.
    let todayStats: DayStats?
    /// Per-day statistics for the past 7 days, in chronological order.
    let weekStats: [DayStats]
    /// The most recent commands (up to 50), newest first.
    let recentCommands: [CommandRecord]
    /// All-time aggregated statistics.
    let globalStats: GlobalStats?
    /// Top 10 commands ranked by tokens saved.
    let topCommands: [CommandSummary]
    /// Timestamp of the last recorded command, used to detect inactivity.
    let lastActivityDate: Date?
    /// `true` when `history.db` cannot be found at the configured path.
    let isDBMissing: Bool

    /// `true` when no command has been recorded in the last 7 days.
    var isInactive: Bool {
        guard let last = lastActivityDate else { return false }
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    /// Today's average savings percentage, or `nil` if there is no data for today.
    var todaySavingsPct: Double? {
        todayStats?.savingsPct
    }

    /// The initial state used before the first database read completes.
    static let empty = StatsSnapshot(
        todayStats: nil,
        weekStats: [],
        recentCommands: [],
        globalStats: nil,
        topCommands: [],
        lastActivityDate: nil,
        isDBMissing: true
    )
}
