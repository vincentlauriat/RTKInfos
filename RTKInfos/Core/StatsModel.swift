import Foundation
import Combine

/// The central `ObservableObject` source of truth for all UI state.
///
/// `StatsModel` owns a `DBWatcher` that emits events whenever `history.db` changes.
/// Each event triggers `refresh()`, which reads the database and atomically replaces
/// `snapshot`. SwiftUI views that depend on `snapshot` re-render automatically.
///
/// All methods and properties are confined to `@MainActor` to guarantee thread-safe
/// mutation of `snapshot` without explicit locking.
@MainActor
final class StatsModel: ObservableObject {

    /// The current UI state. Replaced atomically on every successful refresh.
    @Published private(set) var snapshot: StatsSnapshot = .empty

    private let dbPath: String
    private var pollingInterval: TimeInterval
    private var watcher: DBWatcher?
    private var watcherTask: Task<Void, Never>?

    /// Creates a model configured to read from `dbPath` and poll every `pollingInterval` seconds.
    /// - Parameters:
    ///   - dbPath: Absolute path to rtk's `history.db`.
    ///   - pollingInterval: Fallback polling interval in seconds (default: 30).
    init(dbPath: String, pollingInterval: TimeInterval = 30.0) {
        self.dbPath = dbPath
        self.pollingInterval = pollingInterval
    }

    /// Starts the `DBWatcher` and triggers an initial database read.
    ///
    /// Safe to call only once. Subsequent calls would create a second watcher
    /// and double the refresh rate.
    func start() {
        let dirPath = URL(fileURLWithPath: dbPath).deletingLastPathComponent().path
        watcher = DBWatcher(directoryPath: dirPath, pollingInterval: pollingInterval)

        watcherTask = Task { [weak self] in
            guard let self, let watcher = self.watcher else { return }
            watcher.start()
            for await _ in watcher.events {
                await self.refresh()
            }
        }

        Task { await refresh() }
    }

    /// Stops the watcher and cancels the event-consuming task.
    func stop() {
        watcher?.stop()
        watcherTask?.cancel()
        watcher = nil
        watcherTask = nil
    }

    /// Restarts the watcher with a new polling interval, taking effect immediately.
    func restartWatcher(pollingInterval newInterval: TimeInterval) {
        stop()
        pollingInterval = newInterval
        start()
    }

    /// Reads the database and updates `snapshot`.
    ///
    /// - If the database file is missing, sets `isDBMissing = true`.
    /// - If the schema is incompatible, enters degraded mode (stats cleared, no error thrown).
    /// - On any other error, preserves the previous snapshot and logs the error.
    func refresh() async {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            snapshot = StatsSnapshot(
                todayStats: nil,
                weekStats: [],
                recentCommands: [],
                globalStats: nil,
                topCommands: [],
                lastActivityDate: nil,
                isDBMissing: true
            )
            return
        }

        do {
            let repo = try TrackingRepository(dbPath: dbPath)

            guard try repo.validateSchema() else {
                // Incompatible schema — degraded mode, no crash
                snapshot = StatsSnapshot(
                    todayStats: nil,
                    weekStats: [],
                    recentCommands: [],
                    globalStats: nil,
                    topCommands: [],
                    lastActivityDate: nil,
                    isDBMissing: false
                )
                return
            }

            let today = try repo.todayStats()
            let week = try repo.weekStats()
            let recent = try repo.recentCommands(limit: 50)
            let global = try repo.globalStats()
            let top = try repo.topCommands()
            let lastActivity = try repo.lastActivityDate()

            snapshot = StatsSnapshot(
                todayStats: today,
                weekStats: week,
                recentCommands: recent,
                globalStats: global,
                topCommands: top,
                lastActivityDate: lastActivity,
                isDBMissing: false
            )
        } catch {
            print("[RTKInfos] Refresh error: \(error)")
        }
    }

    // MARK: - Default DB path

    /// Resolves the default path to rtk's `history.db`.
    ///
    /// Checks two locations in priority order:
    /// 1. `~/Library/Application Support/rtk/history.db` (macOS standard)
    /// 2. `~/.local/share/rtk/history.db` (Linux-compatible fallback)
    ///
    /// Returns the first path that exists on disk, falling back to the last candidate
    /// so that `SettingsView` has a reasonable placeholder to display.
    static var defaultDBPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
        let candidates = [
            appSupport?.appendingPathComponent("rtk/history.db").path,
            (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
                .appendingPathComponent(".local/share/rtk/history.db")
        ].compactMap { $0 }

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? candidates.last ?? ""
    }
}
