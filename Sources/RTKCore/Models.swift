import Foundation

public struct DayStats {
    public let date: Date
    public let totalCommands: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let savedTokens: Int
    public let savingsPct: Double

    public init(date: Date, totalCommands: Int, inputTokens: Int, outputTokens: Int, savedTokens: Int, savingsPct: Double) {
        self.date = date; self.totalCommands = totalCommands; self.inputTokens = inputTokens
        self.outputTokens = outputTokens; self.savedTokens = savedTokens; self.savingsPct = savingsPct
    }
}

public struct CommandRecord {
    public let timestamp: Date
    public let originalCmd: String
    public let rtkCmd: String
    public let savedTokens: Int
    public let savingsPct: Double

    public init(timestamp: Date, originalCmd: String, rtkCmd: String, savedTokens: Int, savingsPct: Double) {
        self.timestamp = timestamp; self.originalCmd = originalCmd; self.rtkCmd = rtkCmd
        self.savedTokens = savedTokens; self.savingsPct = savingsPct
    }
}

public struct GlobalStats {
    public let totalCommands: Int
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalSavedTokens: Int
    public let avgSavingsPct: Double
    public let totalExecTimeMs: Int
    public let avgExecTimeMs: Int

    public init(totalCommands: Int, totalInputTokens: Int, totalOutputTokens: Int, totalSavedTokens: Int, avgSavingsPct: Double, totalExecTimeMs: Int, avgExecTimeMs: Int) {
        self.totalCommands = totalCommands; self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens; self.totalSavedTokens = totalSavedTokens
        self.avgSavingsPct = avgSavingsPct; self.totalExecTimeMs = totalExecTimeMs; self.avgExecTimeMs = avgExecTimeMs
    }
}

public struct CommandSummary {
    public let command: String
    public let count: Int
    public let totalSaved: Int
    public let avgPct: Double
    public let totalTimeMs: Int
    public let impactRatio: Double

    public init(command: String, count: Int, totalSaved: Int, avgPct: Double, totalTimeMs: Int, impactRatio: Double) {
        self.command = command; self.count = count; self.totalSaved = totalSaved
        self.avgPct = avgPct; self.totalTimeMs = totalTimeMs; self.impactRatio = impactRatio
    }
}

public struct StatsSnapshot {
    public let todayStats: DayStats?
    public let weekStats: [DayStats]
    public let recentCommands: [CommandRecord]
    public let globalStats: GlobalStats?
    public let topCommands: [CommandSummary]
    public let lastActivityDate: Date?
    public let isDBMissing: Bool

    public var isInactive: Bool {
        guard let last = lastActivityDate else { return false }
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    public var todaySavingsPct: Double? { todayStats?.savingsPct }

    public static let empty = StatsSnapshot(
        todayStats: nil, weekStats: [], recentCommands: [],
        globalStats: nil, topCommands: [], lastActivityDate: nil,
        isDBMissing: true
    )

    public init(todayStats: DayStats?, weekStats: [DayStats], recentCommands: [CommandRecord], globalStats: GlobalStats?, topCommands: [CommandSummary], lastActivityDate: Date?, isDBMissing: Bool) {
        self.todayStats = todayStats; self.weekStats = weekStats; self.recentCommands = recentCommands
        self.globalStats = globalStats; self.topCommands = topCommands
        self.lastActivityDate = lastActivityDate; self.isDBMissing = isDBMissing
    }
}
