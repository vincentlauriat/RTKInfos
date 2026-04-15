import XCTest
import SQLite
@testable import RTKMenuBar

@MainActor
final class StatsModelTests: XCTestCase {

    func test_initialState_isEmptySnapshot() {
        let model = StatsModel(dbPath: "/nonexistent/path.db", pollingInterval: 60)
        XCTAssertTrue(model.snapshot.isDBMissing)
        XCTAssertNil(model.snapshot.todayStats)
        XCTAssertTrue(model.snapshot.weekStats.isEmpty)
    }

    func test_refresh_withMissingDB_setsDBMissingTrue() async throws {
        let model = StatsModel(dbPath: "/nonexistent/path.db", pollingInterval: 60)
        await model.refresh()
        XCTAssertTrue(model.snapshot.isDBMissing)
    }

    func test_refresh_withValidDB_setsDBMissingFalse() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rtk_model_\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbPath = tempDir.appendingPathComponent("history.db").path
        createTestDB(at: dbPath)

        let model = StatsModel(dbPath: dbPath, pollingInterval: 60)
        await model.refresh()

        XCTAssertFalse(model.snapshot.isDBMissing)
    }

    // MARK: - Helpers

    private func createTestDB(at path: String) {
        let db = try! Connection(path)
        try! db.execute("""
            CREATE TABLE commands (
                id INTEGER PRIMARY KEY, timestamp TEXT NOT NULL,
                original_cmd TEXT NOT NULL, rtk_cmd TEXT NOT NULL,
                input_tokens INTEGER NOT NULL, output_tokens INTEGER NOT NULL,
                saved_tokens INTEGER NOT NULL, savings_pct REAL NOT NULL,
                exec_time_ms INTEGER DEFAULT 0
            )
        """)
    }
}
