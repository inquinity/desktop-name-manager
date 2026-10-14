import Foundation

/// Tidies the store, only while a command runs. There is no background process.
///
/// Rules (FR-018, FR-026, amended 2026-10-05 and 2026-10-13):
/// - a stamp with a manifest entry is never deleted here, whatever its state: macOS gives new Desktops a copy of
///   the first Desktop's image, so other Desktops may still show it. Only `cleanup` deletes those, when asked;
/// - a file with no manifest entry (written but never applied, for example after a crash) is deleted once it is
///   older than `strayFileAge`, and only if its name matches `<uuid>.dnm.<ext>` exactly;
/// - undo records older than the undo window are dropped;
/// - the manifest, the lock file, subfolders and every other file are never touched;
/// - nothing happens in a folder that has no manifest of ours.
public enum Housekeeping {
    /// How long a change can be undone: long enough to put back a label changed on the wrong display (spec 001 FR-022).
    public static let undoWindow: TimeInterval = 60

    /// How old a file with no manifest entry must be before it is deleted. Generous, because a crash left it, and
    /// independent of the undo window.
    public static let strayFileAge: TimeInterval = 30 * 60

    /// True for names of the form `<uuid>.dnm.<ext>` and nothing else.
    public static func isOurFileName(_ name: String) -> Bool {
        name.wholeMatch(of: /[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.dnm\.[A-Za-z0-9]+/) != nil
    }

    public static func run(store: Store, now: Date) throws {
        guard store.hasManifest else { return }
        let fileManager = FileManager.default
        let undoCutoff = now.addingTimeInterval(-undoWindow)
        let strayCutoff = now.addingTimeInterval(-strayFileAge)

        // Read-only first: when nothing is due, do not take the lock or write anything, so reporting
        // commands work even on a store that cannot be written.
        let current = try store.readManifest()
        let knownNames = Set(current.stamps.map(\.fileName))
        let hasExpiredRecord = current.changes.contains { $0.at < undoCutoff }
        let strayFiles = ((try? fileManager.contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)) ?? []).filter {
            isOurFileName($0.lastPathComponent) && !knownNames.contains($0.lastPathComponent)
        }
        guard hasExpiredRecord || !strayFiles.isEmpty else { return }

        try store.transaction { manifest in
            // Undo records past the undo window can no longer be used (one exactly at its end still can: see UndoLabel).
            manifest.changes.removeAll { $0.at < undoCutoff }

            // Our own files that the manifest does not know, and that are old enough.
            let known = Set(manifest.stamps.map(\.fileName))
            let entries = (try? fileManager.contentsOfDirectory(at: store.directory,
                                                                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey])) ?? []
            for url in entries {
                let name = url.lastPathComponent
                guard isOurFileName(name), !known.contains(name) else { continue }
                let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                guard values?.isRegularFile == true, let modified = values?.contentModificationDate, modified <= strayCutoff else { continue }
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
