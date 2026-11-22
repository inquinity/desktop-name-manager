import Foundation

/// Tells the app when the label store changes, whether the app, `dnm` or another copy changed it (spec 014,
/// contracts/core-additions.md §3).
///
/// It watches the store's folder, not the manifest file: the manifest is replaced by a rename, which would end a
/// watch on the file itself. Events are coalesced, and `onChange` is called only when `manifest.json` was replaced or
/// removed, not for stamp images being written. If the folder itself is removed or replaced, the watcher reports the
/// change and watches the new folder once it exists again (checking once a second until then).
@MainActor
public final class StoreWatcher {
    private let directory: URL
    private let manifestURL: URL
    private let onChange: @MainActor () -> Void
    private let delay: TimeInterval
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private var reopen: DispatchWorkItem?
    private var lastSeen: ManifestIdentity?
    private var stopped = false
    /// How long events are gathered before the manifest is checked.
    public static let defaultCoalescingDelay: TimeInterval = 0.1
    static let reopenInterval: TimeInterval = 1

    /// Throws when the store's folder cannot be opened, for example before anything was ever labeled; the caller
    /// creates the watcher again later (the app does when its main window opens).
    public init(store: Store, coalescingDelay: TimeInterval = StoreWatcher.defaultCoalescingDelay,
                onChange: @escaping @MainActor () -> Void) throws {
        directory = store.directory
        manifestURL = store.manifestURL
        delay = coalescingDelay
        self.onChange = onChange
        lastSeen = ManifestIdentity(of: manifestURL)
        guard openSource() else {
            throw DnmError.failure("Cannot watch the stored data: \(String(cString: strerror(errno))).")
        }
    }

    isolated deinit {
        stopEverything()
    }

    /// Ends the watch; no call follows, even one already scheduled.
    public func stop() {
        stopped = true
        stopEverything()
    }

    private func stopEverything() {
        pending?.cancel()
        pending = nil
        reopen?.cancel()
        reopen = nil
        source?.cancel()   // its cancel handler closes the descriptor
        source = nil
    }

    /// Opens the folder and starts the source. False when the folder cannot be opened.
    private func openSource() -> Bool {
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return false }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename],
                                                               queue: .main)
        source.setEventHandler { [weak self, weak source] in
            let folderGone = source.map { !$0.data.isDisjoint(with: [.delete, .rename]) } ?? false
            MainActor.assumeIsolated { self?.handleEvent(folderGone: folderGone) }
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
        return true
    }

    private func handleEvent(folderGone: Bool) {
        guard !stopped else { return }
        if folderGone {
            // The descriptor follows the old folder; watch whatever is at the path now.
            source?.cancel()
            source = nil
            scheduleReopen(after: 0)
        }
        scheduleCheck()
    }

    private func scheduleReopen(after seconds: TimeInterval) {
        reopen?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.stopped, self.source == nil else { return }
                if self.openSource() {
                    self.scheduleCheck()   // the new folder may hold another manifest
                } else {
                    self.scheduleReopen(after: Self.reopenInterval)
                }
            }
        }
        reopen = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func scheduleCheck() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.check() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func check() {
        pending = nil
        guard !stopped else { return }
        let now = ManifestIdentity(of: manifestURL)
        guard now != lastSeen else { return }
        lastSeen = now
        onChange()
    }
}

/// Enough of the manifest file's identity to tell it was replaced: a rename gives a new inode, and a rewrite in place
/// a new modification time or size.
struct ManifestIdentity: Equatable {
    var inode: UInt64
    var modified: Date?
    var size: UInt64

    init?(of url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        modified = attributes[.modificationDate] as? Date
        size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
