import XCTest
@testable import RTKMenuBar

final class DBWatcherTests: XCTestCase {

    func test_watcher_emitsEvent_whenFileModified() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rtk_test_\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbFile = tempDir.appendingPathComponent("history.db")

        let watcher = DBWatcher(directoryPath: tempDir.path, pollingInterval: 1.0)
        var eventReceived = false
        let expectation = expectation(description: "FSEvent or poll received")

        Task {
            for await _ in watcher.events {
                if !eventReceived {
                    eventReceived = true
                    expectation.fulfill()
                }
                break
            }
        }

        watcher.start()
        defer { watcher.stop() }

        // Créer le fichier pour déclencher FSEvent ou attendre le poll
        try Data().write(to: dbFile)

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(eventReceived)
    }

    func test_watcher_emitsOnPollingFallback() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("rtk_poll_\(UUID())")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Polling très rapide pour le test
        let watcher = DBWatcher(directoryPath: tempDir.path, pollingInterval: 0.3)
        let expectation = expectation(description: "Poll event received")

        Task {
            for await _ in watcher.events {
                expectation.fulfill()
                break
            }
        }

        watcher.start()
        defer { watcher.stop() }

        await fulfillment(of: [expectation], timeout: 3.0)
    }

    func test_watcher_stop_doesNotCrash() {
        let watcher = DBWatcher(directoryPath: "/tmp", pollingInterval: 30.0)
        watcher.start()
        watcher.stop()  // Ne doit pas crasher
    }
}
