import Foundation
import CoreServices

/// Watches the rtk data directory for changes to `history.db` and publishes
/// events via an `AsyncStream<Void>`.
///
/// Detection uses two complementary layers:
/// - **FSEvents** (primary): kernel-level file-system notifications with ~500ms latency.
///   Only fires when a path ending in `history.db` is modified.
/// - **Timer** (fallback): periodic polling that fires unconditionally. Ensures the UI
///   stays up to date even on network volumes or when FSEvents is unavailable.
///
/// ## Memory management
/// `FSEventStreamContext` requires a raw C pointer for the `info` field. We use
/// `Unmanaged.passRetained` to transfer ownership into the context, then call
/// `release()` explicitly in `stop()` to balance the retain count:
/// ```
/// startFSEvents()  →  passRetained(self)   // +1
/// stop()           →  fromOpaque(ptr).release()  // -1
/// ```
final class DBWatcher {

    private let directoryPath: String
    private let pollingInterval: TimeInterval
    private var eventStream: FSEventStreamRef?
    private var timer: Timer?
    private var continuation: AsyncStream<Void>.Continuation?
    /// Retained pointer stored so `stop()` can release it to balance `passRetained`.
    private var fsSelfPtr: UnsafeMutableRawPointer?

    /// Async stream of change notifications consumed by `StatsModel`.
    ///
    /// Initialized synchronously in `init()` to eliminate a race condition where
    /// `start()` could be called before the first access to this property.
    private(set) var events: AsyncStream<Void>!

    /// Creates a watcher for the given directory.
    /// - Parameters:
    ///   - directoryPath: Absolute path to the directory containing `history.db`.
    ///   - pollingInterval: Fallback polling interval in seconds (default: 30).
    init(directoryPath: String, pollingInterval: TimeInterval = 30.0) {
        self.directoryPath = directoryPath
        self.pollingInterval = pollingInterval
        var cap: AsyncStream<Void>.Continuation!
        self.events = AsyncStream<Void> { continuation in
            cap = continuation
        }
        self.continuation = cap
    }

    /// Starts both the FSEvents stream and the polling timer.
    func start() {
        startFSEvents()
        startPollingTimer()
    }

    /// Stops all watchers and finishes the `events` stream.
    ///
    /// Releases the retained self-pointer created by `startFSEvents()` to
    /// prevent a memory leak.
    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            if let ptr = fsSelfPtr {
                Unmanaged<DBWatcher>.fromOpaque(ptr).release()
                fsSelfPtr = nil
            }
            FSEventStreamRelease(stream)
            eventStream = nil
        }
        timer?.invalidate()
        timer = nil
        continuation?.finish()
    }

    // MARK: - FSEvents

    private func startFSEvents() {
        let paths = [directoryPath] as CFArray

        // passRetained increments the ref count; balanced by release() in stop()
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        self.fsSelfPtr = selfPtr

        var context = FSEventStreamContext(
            version: 0,
            info: selfPtr,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info,
                  let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String]
            else { return }
            let watcher = Unmanaged<DBWatcher>.fromOpaque(info).takeUnretainedValue()
            // Notify on history.db changes and WAL/shm files (rtk writes to WAL first)
            let relevant = paths.prefix(numEvents).contains {
                $0.hasSuffix("history.db") ||
                $0.hasSuffix("history.db-wal") ||
                $0.hasSuffix("history.db-shm")
            }
            if relevant { watcher.notify() }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            // FSEvents unavailable — polling fallback will cover detection
            Unmanaged<DBWatcher>.fromOpaque(selfPtr).release()
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    // MARK: - Polling fallback

    private func startPollingTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.pollingInterval, repeats: true) { [weak self] _ in
                self?.notify()
            }
        }
    }

    /// Yields a value into the `events` stream, waking any awaiting consumer.
    private func notify() {
        continuation?.yield()
    }
}
