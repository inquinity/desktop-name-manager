import Foundation

public struct UndoResult: Equatable, Sendable {
    /// What was undone.
    public var undone: ChangeKind
    /// The label that is showing again, or nil when the original wallpaper is back.
    public var restoredLabel: Label?
    public var displayName: String
}

extension DesktopLabeler {
    /// Reverses the most recent change made on `display`, if it is within the undo window and the display's
    /// wallpaper is still the one that change produced (FR-022). One level only.
    @discardableResult
    public func undoLastChange(on display: Display) throws -> UndoResult {
        guard store.hasManifest else { throw Self.nothingToUndo(on: display) }
        return try store.exclusive { try performUndo(on: display) }
    }

    /// The checks `undoLastChange` makes before it changes anything, read-only and with the same messages, so a command
    /// on several displays can make them for every display first (spec 010 FR-003). With `onScreen: false` only the
    /// record and its window are checked: with `--desktop`, the rest needs Desktop N on screen and is made there, by
    /// `undoLastChange` itself (research R4).
    public func checkUndo(on display: Display, onScreen: Bool) throws {
        guard store.hasManifest else { throw Self.nothingToUndo(on: display) }
        let manifest = try store.readManifest()
        let record = try undoRecord(on: display, in: manifest)
        if onScreen { _ = try undoTarget(of: record, on: display, in: manifest) }
    }

    private func performUndo(on display: Display) throws -> UndoResult {
        try housekeeping()
        let manifest = try store.readManifest()
        let now = time.now
        let record = try undoRecord(on: display, in: manifest)
        let target = try undoTarget(of: record, on: display, in: manifest)

        let shown = try shownFileNames()
        let snapshot = try store.transaction { manifest -> Manifest in
            let before = manifest
            Self.markSeen(shown, at: now, in: &manifest)
            if case .stamp(let id) = record.produced, let index = manifest.stamps.firstIndex(where: { $0.id == id }) {
                // A reused label goes back to how it was: it may still show on another Desktop.
                manifest.stamps[index].state = record.reusedFrom ?? .retired(at: now, reason: .undone)
            }
            if case .stamp(let id) = record.before, let index = manifest.stamps.firstIndex(where: { $0.id == id }) {
                manifest.stamps[index].state = .active
                manifest.stamps[index].supersededBy = nil
                manifest.stamps[index].lastSeen = now   // it is showing again
            }
            manifest.changes.removeAll { $0.displayUUID == display.uuid }   // one level only
            return before
        }

        do {
            try apply(target.url, placement: target.placement, on: display)
        } catch {
            try? store.transaction { $0 = snapshot }
            throw error
        }
        return UndoResult(undone: record.kind, restoredLabel: target.label, displayName: display.name)
    }

    /// The display's change record, if it is within the undo window.
    private func undoRecord(on display: Display, in manifest: Manifest) throws -> ChangeRecord {
        guard let record = manifest.changes.first(where: { $0.displayUUID == display.uuid }),
              time.now.timeIntervalSince(record.at) <= Housekeeping.undoWindow else {
            throw Self.nothingToUndo(on: display)
        }
        return record
    }

    /// What undoing `record` shows again, after checking that the display still shows what the change produced and
    /// that the file to show again exists. Changes nothing.
    private func undoTarget(of record: ChangeRecord, on display: Display,
                            in manifest: Manifest) throws -> (url: URL, placement: WallpaperPlacement, label: Label?) {
        let current = try system.currentWallpaper(on: display)
        guard produces(record.produced, currentURL: current.url, manifest: manifest) else {
            throw DnmError.cannotUndo("the wallpaper on \(display.name) has changed since that change")
        }
        switch record.before {
        case .stamp(let id):
            guard let stamp = manifest.stamps.first(where: { $0.id == id }), store.stampFileExists(named: stamp.fileName) else {
                throw DnmError.cannotUndo("the previous label's image is no longer available")
            }
            return (store.fileURL(named: stamp.fileName), Self.stampPlacement(fill: stamp.original.fillColor), stamp.label)
        case .original(let original):
            guard let url = try? Self.resolve(original) else {
                throw DnmError.cannotUndo("the original wallpaper image can no longer be found")
            }
            return (url, Self.placement(of: original), nil)
        }
    }

    private static func nothingToUndo(on display: Display) -> DnmError {
        .cannotUndo("there is nothing to undo on \(display.name); a change can be undone for \(Int(Housekeeping.undoWindow)) seconds")
    }

    /// True when the display still shows what the change produced.
    private func produces(_ state: StateRef, currentURL: URL?, manifest: Manifest) -> Bool {
        guard let currentURL else { return false }
        switch state {
        case .stamp(let id):
            return stamp(for: currentURL, in: manifest)?.id == id
        case .original(let original):
            let shown = currentURL.resolvingSymlinksInPath().path
            if URL(fileURLWithPath: original.path).resolvingSymlinksInPath().path == shown { return true }
            return (try? Self.resolve(original))?.resolvingSymlinksInPath().path == shown
        }
    }
}
