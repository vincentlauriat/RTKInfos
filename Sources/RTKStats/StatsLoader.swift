import Foundation
import RTKCore

struct StatsLoader {
    let dbPath: String

    func load() throws -> StatsSnapshot {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return .empty
        }
        let repo = try TrackingRepository(dbPath: dbPath)
        guard try repo.validateSchema() else {
            return StatsSnapshot(
                todayStats: nil, weekStats: [], recentCommands: [],
                globalStats: nil, topCommands: [], lastActivityDate: nil,
                isDBMissing: false
            )
        }
        return StatsSnapshot(
            todayStats:       try repo.todayStats(),
            weekStats:        try repo.weekStats(),
            recentCommands:   try repo.recentCommands(limit: 5),
            globalStats:      try repo.globalStats(),
            topCommands:      try repo.topCommands(),
            lastActivityDate: try repo.lastActivityDate(),
            isDBMissing:      false
        )
    }
}

func resolveDefaultDBPath() -> String {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = [
        appSupport?.appendingPathComponent("rtk/history.db").path,
        "\(home)/.local/share/rtk/history.db"
    ].compactMap { $0 }
    return candidates.first { FileManager.default.fileExists(atPath: $0) }
        ?? candidates.last ?? ""
}
