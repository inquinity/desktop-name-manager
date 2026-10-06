import Foundation

/// A labeled image that `prune` may delete.
public struct PruneCandidate: Equatable, Sendable {
    public var label: String
    public var reason: RetireReason
    public var retiredAt: Date
    public var bytes: Int64
    /// The stamp's file in the store; never printed.
    var fileName: String
}

public struct PruneResult: Equatable, Sendable {
    public var candidates: [PruneCandidate]
    public var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.bytes } }
    /// True when the candidates were deleted, false for a listing only.
    public var deleted: Bool
}

extension DesktopLabeler {
    /// Lists, and with `confirm` deletes, labeled images that are no longer an active label: removed, replaced or
    /// undone through the tool (FR-029). Other Desktops may still show one (macOS copies the first Desktop's image
    /// to new Desktops), so nothing is deleted without confirmation, and an image shown on any display's current
    /// Desktop is never deleted.
    @discardableResult
    public func prune(confirm: Bool) throws -> PruneResult {
        guard store.hasManifest else { return PruneResult(candidates: [], deleted: confirm) }
        return try store.exclusive {
            try cleanUp()
            let candidates = try pruneCandidates(in: try store.readManifest())

            if confirm && !candidates.isEmpty {
                let names = Set(candidates.map(\.fileName))
                try store.transaction { manifest in
                    manifest.stamps.removeAll { names.contains($0.fileName) }
                }
                for name in names { store.removeFile(named: name) }
            }
            return PruneResult(candidates: candidates, deleted: confirm)
        }
    }

    /// The retired images not shown on any display's current Desktop. Reads only.
    func pruneCandidates(in manifest: Manifest) throws -> [PruneCandidate] {
        var showing = Set<String>()
        for display in try system.displays() {
            if let name = try system.currentWallpaper(on: display).url?.lastPathComponent { showing.insert(name) }
        }
        return manifest.stamps.compactMap { stamp in
            guard case .retired(let at, let reason) = stamp.state, !showing.contains(stamp.fileName) else { return nil }
            return PruneCandidate(label: stamp.label.text.value, reason: reason, retiredAt: at, bytes: fileSize(stamp.fileName), fileName: stamp.fileName)
        }.sorted { $0.retiredAt < $1.retiredAt }
    }

    func fileSize(_ fileName: String) -> Int64 {
        Int64((try? store.fileURL(named: fileName).resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
}
