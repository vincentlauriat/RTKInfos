import XCTest
import SQLite
@testable import RTKMenuBar

final class TrackingRepositoryTests: XCTestCase {

    var tempDB: URL!

    override func setUp() {
        super.setUp()
        tempDB = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_tracking_\(UUID()).db")
        createTestDB(at: tempDB)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDB)
        super.tearDown()
    }

    func createTestDB(at url: URL) {
        let db = try! Connection(url.path)
        try! db.execute("""
            CREATE TABLE commands (
                id INTEGER PRIMARY KEY,
                timestamp TEXT NOT NULL,
                original_cmd TEXT NOT NULL,
                rtk_cmd TEXT NOT NULL,
                input_tokens INTEGER NOT NULL,
                output_tokens INTEGER NOT NULL,
                saved_tokens INTEGER NOT NULL,
                savings_pct REAL NOT NULL,
                exec_time_ms INTEGER DEFAULT 0
            )
        """)
    }

    func insertCommand(db: Connection, timestamp: String, savedTokens: Int, savingsPct: Double) throws {
        try db.run(
            "INSERT INTO commands (timestamp, original_cmd, rtk_cmd, input_tokens, output_tokens, saved_tokens, savings_pct) VALUES (?, 'git log', 'rtk git log', 1000, ?, ?, ?)",
            timestamp, 1000 - savedTokens, savedTokens, savingsPct
        )
    }

    func test_schemaValidation_returnsTrue_forValidSchema() throws {
        let repo = try TrackingRepository(dbPath: tempDB.path)
        XCTAssertTrue(try repo.validateSchema())
    }

    func test_todayStats_returnsNil_whenNoCommandsToday() throws {
        let repo = try TrackingRepository(dbPath: tempDB.path)
        let stats = try repo.todayStats()
        XCTAssertNil(stats)
    }

    func test_todayStats_returnsAggregatedStats() throws {
        let db = try Connection(tempDB.path)
        let today = ISO8601DateFormatter().string(from: Date())
        try insertCommand(db: db, timestamp: today, savedTokens: 800, savingsPct: 80.0)
        try insertCommand(db: db, timestamp: today, savedTokens: 700, savingsPct: 70.0)

        let repo = try TrackingRepository(dbPath: tempDB.path)
        let stats = try repo.todayStats()
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.totalCommands, 2)
        XCTAssertEqual(stats?.savedTokens, 1500)
        XCTAssertEqual(stats?.savingsPct ?? 0.0, 75.0, accuracy: 0.1)
    }

    func test_weekStats_returns7DaysOrLess() throws {
        let repo = try TrackingRepository(dbPath: tempDB.path)
        let stats = try repo.weekStats()
        XCTAssertLessThanOrEqual(stats.count, 7)
    }

    func test_recentCommands_respectsLimit() throws {
        let db = try Connection(tempDB.path)
        let today = ISO8601DateFormatter().string(from: Date())
        for _ in 0..<10 {
            try insertCommand(db: db, timestamp: today, savedTokens: 500, savingsPct: 50.0)
        }
        let repo = try TrackingRepository(dbPath: tempDB.path)
        let cmds = try repo.recentCommands(limit: 5)
        XCTAssertEqual(cmds.count, 5)
    }
}
