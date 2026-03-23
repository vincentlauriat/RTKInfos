import Foundation
import CoreServices

/// Surveille le répertoire macrtk via FSEvents + Timer de polling fallback.
/// Publie un événement `AsyncStream<Void>` à chaque modification de tracking.db détectée.
///
/// Gestion mémoire FSEventStreamContext :
/// On utilise `passRetained` pour transférer la propriété à FSEventStreamContext.info,
/// et on appelle `release()` explicitement dans `stop()` pour équilibrer le retain.
final class DBWatcher {

    private let directoryPath: String
    private let pollingInterval: TimeInterval
    private var eventStream: FSEventStreamRef?
    private var timer: Timer?
    private var continuation: AsyncStream<Void>.Continuation?

    /// Stream d'événements à consommer par StatsModel.
    lazy var events: AsyncStream<Void> = {
        AsyncStream { [weak self] continuation in
            self?.continuation = continuation
        }
    }()

    init(directoryPath: String, pollingInterval: TimeInterval = 30.0) {
        self.directoryPath = directoryPath
        self.pollingInterval = pollingInterval
    }

    func start() {
        startFSEvents()
        startPollingTimer()
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            // Libère le retain créé par passRetained dans startFSEvents()
            Unmanaged.passUnretained(self).release()
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

        // passRetained : incrémente le refcount, équilibré par release() dans stop()
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

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
            // Filtrer : ne notifier que si tracking.db est concerné
            let relevant = paths.prefix(numEvents).contains { $0.hasSuffix("tracking.db") }
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
            // FSEvents indisponible — le polling fallback prend le relais
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

    private func notify() {
        continuation?.yield()
    }
}
