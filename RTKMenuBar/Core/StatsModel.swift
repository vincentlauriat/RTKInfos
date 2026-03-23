import Foundation
import Observation

@Observable
@MainActor
final class StatsModel {

    private(set) var snapshot: StatsSnapshot = .empty

    private let dbPath: String
    private let pollingInterval: TimeInterval
    private var watcher: DBWatcher?
    private var watcherTask: Task<Void, Never>?

    init(dbPath: String, pollingInterval: TimeInterval = 30.0) {
        self.dbPath = dbPath
        self.pollingInterval = pollingInterval
    }

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

    func stop() {
        watcher?.stop()
        watcherTask?.cancel()
    }

    func refresh() async {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            snapshot = StatsSnapshot(
                todayStats: nil,
                weekStats: [],
                recentCommands: [],
                lastActivityDate: nil,
                isDBMissing: true
            )
            return
        }

        do {
            let repo = try TrackingRepository(dbPath: dbPath)

            guard try repo.validateSchema() else {
                // Schéma incompatible — mode dégradé
                snapshot = StatsSnapshot(
                    todayStats: nil,
                    weekStats: [],
                    recentCommands: [],
                    lastActivityDate: nil,
                    isDBMissing: false
                )
                return
            }

            let today = try repo.todayStats()
            let week = try repo.weekStats()
            let recent = try repo.recentCommands(limit: 5)
            let lastActivity = try repo.lastActivityDate()

            snapshot = StatsSnapshot(
                todayStats: today,
                weekStats: week,
                recentCommands: recent,
                lastActivityDate: lastActivity,
                isDBMissing: false
            )
        } catch {
            // Conserver le dernier snapshot valide, juste logger
            print("[RTKMenuBar] Erreur refresh: \(error)")
        }
    }

    // MARK: - DB Path par défaut

    static var defaultDBPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
        // macrtk sur macOS écrit dans ~/Library/Application Support/macrtk/tracking.db
        // mais peut aussi utiliser ~/.local/share/macrtk/tracking.db (Linux compat)
        let candidates = [
            appSupport?.appendingPathComponent("macrtk/tracking.db").path,
            (FileManager.default.homeDirectoryForCurrentUser.path as NSString)
                .appendingPathComponent(".local/share/macrtk/tracking.db")
        ].compactMap { $0 }

        return candidates.first { FileManager.default.fileExists(atPath: $0) }
            ?? candidates.last ?? ""
    }
}
