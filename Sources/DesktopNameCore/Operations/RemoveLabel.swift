import Foundation

public enum RemoveLabelOutcome: Equatable, Sendable {
    /// The label was removed and the original wallpaper restored.
    case removed(Label)
    /// The Desktop had no label from this tool; nothing changed.
    case noLabel
}

public struct RemoveLabelResult: Equatable, Sendable {
    public var outcome: RemoveLabelOutcome
    public var displayName: String
}

extension DesktopLabeler {
    /// Restores the Desktop's original image, placement and fill color exactly (FR-008).
    /// The stamp is retired, not deleted, so `undo` can bring it back during the cool-down.
    @discardableResult
    public func removeLabel(on display: Display) throws -> RemoveLabelResult {
        // Nothing stored yet means nothing to remove; do not create the store just to say so.
        guard store.hasManifest else { return RemoveLabelResult(outcome: .noLabel, displayName: display.name) }
        return try store.exclusive { try performRemoveLabel(on: display) }
    }

    private func performRemoveLabel(on display: Display) throws -> RemoveLabelResult {
        try cleanUp()
        let current = try system.currentWallpaper(on: display)
        let manifest = try store.readManifest()

        // Any of our labels showing here counts, whatever its record says (a shared image, see SetLabel).
        guard let stamp = stamp(for: current.url, in: manifest) else {
            return RemoveLabelResult(outcome: .noLabel, displayName: display.name)
        }
        // Fail before changing anything if the original cannot be found.
        let originalURL = try Self.resolve(stamp.original)

        let now = time.now
        let snapshot = try store.transaction { manifest -> Manifest in
            let before = manifest
            // Bookkeeping only: other Desktops may still show this image, so it stays on disk.
            if let index = manifest.stamps.firstIndex(where: { $0.id == stamp.id }), manifest.stamps[index].isActive {
                manifest.stamps[index].state = .retired(at: now, reason: .removed)
            }
            manifest.changes.removeAll { $0.displayUUID == display.uuid }
            manifest.changes.append(ChangeRecord(displayUUID: display.uuid, kind: .remove, at: now,
                                                 produced: .original(stamp.original), before: .stamp(id: stamp.id)))
            return before
        }

        do {
            try apply(originalURL, placement: Self.placement(of: stamp.original), on: display)
        } catch {
            try? store.transaction { $0 = snapshot }
            throw error
        }
        return RemoveLabelResult(outcome: .removed(stamp.label), displayName: display.name)
    }
}
