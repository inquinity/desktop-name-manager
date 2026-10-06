import Foundation

/// Deletes stamps nobody needs, only while a command runs. There is no background process.
///
/// Rules (FR-018, FR-026):
/// - an active stamp is never deleted;
/// - a stamp retired less than the cool-down ago is kept, so a removed or replaced label can be recovered;
/// - a file with no manifest entry is deleted only if it is older than the cool-down and its name
///   matches `<uuid>.dnm.<ext>` exactly;
/// - the manifest, the lock file, subfolders and every other file are never touched;
/// - nothing happens in a folder that has no manifest of ours.
public enum Cleanup {
    /// Fixed 30 minutes.
    public static let coolDown: TimeInterval = 30 * 60

    /// True for names of the form `<uuid>.dnm.<ext>` and nothing else.
    public static func isOurFileName(_ name: String) -> Bool {
        name.wholeMatch(of: /[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.dnm\.[A-Za-z0-9]+/) != nil
    }

    public static func run(store: Store, now: Date) throws {
        guard store.hasManifest else { return }
        let fileManager = FileManager.default
        let cutoff = now.addingTimeInterval(-coolDown)

        // Read-only first: when nothing is due, do not take the lock or write anything, so reporting
        // commands work even on a store that cannot be written.
        let current = try store.readManifest()
        let knownNames = Set(current.stamps.map(\.fileName))
        // Retired and old enough. (T082 replaces this rule: applied stamps are kept until `prune`.)
        func deletable(_ stamp: Stamp) -> Bool {
            guard case .retired(let at, _) = stamp.state, at <= cutoff else { return false }
            return true
        }
        let hasExpiredStamp = current.stamps.contains(where: deletable)
        let hasExpiredRecord = current.changes.contains { $0.at <= cutoff }
        let strayFiles = ((try? fileManager.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)) ?? []).filter {
            isOurFileName($0.lastPathComponent) && !knownNames.contains($0.lastPathComponent)
        }
        guard hasExpiredStamp || hasExpiredRecord || !strayFiles.isEmpty else { return }

        try store.transaction { manifest in
            // Retired stamps past the cool-down: delete the file and the entry.
            manifest.stamps.removeAll { stamp in
                guard deletable(stamp) else { return false }
                store.removeFile(named: stamp.fileName)
                return true
            }
            // Undo records past the cool-down can no longer be used.
            manifest.changes.removeAll { $0.at <= cutoff }

            // Our own files that the manifest does not know, and that are old enough.
            let known = Set(manifest.stamps.map(\.fileName))
            let entries = (try? fileManager.contentsOfDirectory(at: store.directory,
                                                                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey])) ?? []
            for url in entries {
                let name = url.lastPathComponent
                guard isOurFileName(name), !known.contains(name) else { continue }
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                guard values?.isRegularFile == true, let modified = values?.contentModificationDate, modified <= cutoff else { continue }
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
