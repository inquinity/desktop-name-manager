import Foundation

public struct UndoResult: Equatable, Sendable {
    /// What was undone.
    public var undone: ChangeKind
    /// The label that is showing again, or nil when the original wallpaper is back.
    public var restoredLabel: Label?
    public var displayName: String
    /// How long ago the undone change was made.
    public var minutesAgo: Int
}

extension DesktopLabeler {
    /// Reverses the most recent change made on `display`, if it is within the cool-down and the display's
    /// wallpaper is still the one that change produced (FR-022). One level only.
    @discardableResult
    public func undoLastChange(on display: Display) throws -> UndoResult {
        guard store.hasManifest else {
            throw DnmError.cannotUndo("there is nothing to undo on \(display.name); changes can be undone for \(Int(Cleanup.coolDown / 60)) minutes")
        }
        return try store.exclusive { try performUndo(on: display) }
    }

    private func performUndo(on display: Display) throws -> UndoResult {
        try cleanUp()
        let current = try system.currentWallpaper(on: display)
        let manifest = try store.readManifest()
        let now = time.now

        guard let record = manifest.changes.first(where: { $0.displayUUID == display.uuid }),
              now.timeIntervalSince(record.at) <= Cleanup.coolDown else {
            throw DnmError.cannotUndo("there is nothing to undo on \(display.name); changes can be undone for \(Int(Cleanup.coolDown / 60)) minutes")
        }
        guard produces(record.produced, currentURL: current.url, manifest: manifest) else {
            throw DnmError.cannotUndo("the wallpaper on \(display.name) has changed since that change")
        }

        // Work out what to show again, failing before any change if its file is gone.
        let target: (url: URL, placement: WallpaperPlacement, label: Label?)
        switch record.before {
        case .stamp(let id):
            guard let stamp = manifest.stamps.first(where: { $0.id == id }), store.stampFileExists(named: stamp.fileName) else {
                throw DnmError.cannotUndo("the previous label's image is no longer available")
            }
            target = (store.fileURL(named: stamp.fileName), Self.stampPlacement(fill: stamp.original.fillColor), stamp.label)
        case .original(let original):
            guard let url = try? Self.resolve(original) else {
                throw DnmError.cannotUndo("the original wallpaper image can no longer be found")
            }
            target = (url, Self.placement(of: original), nil)
        }

        let snapshot = try store.transaction { manifest -> Manifest in
            let before = manifest
            if case .stamp(let id) = record.produced, let index = manifest.stamps.firstIndex(where: { $0.id == id }) {
                manifest.stamps[index].state = .retired(at: now, reason: .undone)
            }
            if case .stamp(let id) = record.before, let index = manifest.stamps.firstIndex(where: { $0.id == id }) {
                manifest.stamps[index].state = .active
                manifest.stamps[index].supersededBy = nil
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
        return UndoResult(undone: record.kind, restoredLabel: target.label, displayName: display.name,
                          minutesAgo: Int(now.timeIntervalSince(record.at) / 60))
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
