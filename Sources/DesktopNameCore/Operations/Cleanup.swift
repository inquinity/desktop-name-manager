import Foundation

/// Why a labeled image is a candidate for `dnm cleanup`.
public enum CleanupReason: String, Codable, Sendable {
    /// The label was removed, replaced or undone through `dnm`, long enough ago.
    case removed, replaced, undone
    /// The label is still active, but no Desktop has been seen showing it for long enough (for example the Desktop
    /// was deleted, which `dnm` is never told).
    case notSeen = "not seen"
}

/// A labeled image that `dnm cleanup` may delete (spec 009).
public struct CleanupCandidate: Equatable, Sendable {
    public var label: String
    public var displayName: String
    public var reason: CleanupReason
    /// When it was retired, or when it was last seen.
    public var since: Date
    public var bytes: Int64
    /// The stamp and its file in the store; never printed.
    var stampID: UUID
    var fileName: String
}

/// What `cleanup` would delete, as shown to the person before they agree.
public struct CleanupPlan: Equatable, Sendable {
    public var days: Int
    public var candidates: [CleanupCandidate]
    public var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.bytes } }
}

/// A reminder that old labeled images have piled up (spec 009).
public struct CleanupNudge: Equatable, Sendable {
    public var bytes: Int64
    public var labels: Int
}

extension DesktopLabeler {
    public static let defaultCleanupDays = 30
    /// The nudge appears when `cleanup` could free at least this much (decimal MB, as sizes are shown).
    public static let nudgeThresholdBytes: Int64 = 50_000_000
    /// A nudge is not repeated within this long, unless the amount has doubled.
    public static let nudgeInterval: TimeInterval = 7 * 86_400

    /// What `cleanup` would delete now: images that no display's current Desktop shows, that no undo needs, and that
    /// were retired, or last seen, at least `days` days ago. Reads only (apart from housekeeping).
    public func cleanupPlan(days: Int) throws -> CleanupPlan {
        guard store.hasManifest else { return CleanupPlan(days: days, candidates: []) }
        try housekeeping()
        let manifest = try store.readManifest()
        return CleanupPlan(days: days, candidates: cleanupCandidates(in: manifest, days: days, now: time.now, shown: try shownFileNames()))
    }

    /// Deletes the images and records of `plan` that are still candidates now (something may have changed since the
    /// person was shown the plan), as one locked change; returns what was deleted. Never deletes anything the plan did
    /// not list.
    @discardableResult
    public func carryOut(_ plan: CleanupPlan) throws -> CleanupPlan {
        guard store.hasManifest, !plan.candidates.isEmpty else { return CleanupPlan(days: plan.days, candidates: []) }
        return try store.exclusive {
            try housekeeping()
            let now = time.now
            let shown = try shownFileNames()
            let planned = Set(plan.candidates.map(\.stampID))
            let candidates = cleanupCandidates(in: try store.readManifest(), days: plan.days, now: now, shown: shown)
                .filter { planned.contains($0.stampID) }
            let ids = Set(candidates.map(\.stampID))
            try store.transaction { manifest in
                manifest.stamps.removeAll { ids.contains($0.id) }
                Self.markSeen(shown, at: now, in: &manifest)
                manifest.maintenance = nil
            }
            for name in Set(candidates.map(\.fileName)) { store.removeFile(named: name) }
            return CleanupPlan(days: plan.days, candidates: candidates)
        }
    }

    /// The reminder, if one is due: at least the threshold could be freed (at the default days), and it was not shown
    /// within the interval unless the amount has doubled since. Records that it was shown. Deletes nothing.
    public func nudgeIfDue() throws -> CleanupNudge? {
        guard store.hasManifest else { return nil }
        let now = time.now
        let manifest = try store.readManifest()
        let candidates = cleanupCandidates(in: manifest, days: Self.defaultCleanupDays, now: now, shown: try shownFileNames())
        let bytes = candidates.reduce(Int64(0)) { $0 + $1.bytes }
        guard bytes >= Self.nudgeThresholdBytes else { return nil }
        if let last = manifest.maintenance, let at = last.nudgedAt, let lastBytes = last.nudgedBytes,
           now.timeIntervalSince(at) < Self.nudgeInterval, bytes < 2 * lastBytes {
            return nil
        }
        try store.transaction { $0.maintenance = Maintenance(nudgedAt: now, nudgedBytes: bytes) }
        return CleanupNudge(bytes: bytes, labels: candidates.count)
    }

    /// What `cleanup` could free at the default days, for `dnm check`.
    func reclaimableBytes(in manifest: Manifest) throws -> Int64 {
        cleanupCandidates(in: manifest, days: Self.defaultCleanupDays, now: time.now, shown: try shownFileNames()).reduce(0) { $0 + $1.bytes }
    }

    /// The selection rule (spec 009 data model §4), shared by `cleanup`, the nudge and `check`.
    func cleanupCandidates(in manifest: Manifest, days: Int, now: Date, shown: Set<String>) -> [CleanupCandidate] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        // Undo needs both images a change names, but only inside the undo window; read-only commands (`check`, the nudge)
        // do not run housekeeping, so an expired record can still be in the manifest and must not count.
        var needed = Set<UUID>()
        for record in manifest.changes where now.timeIntervalSince(record.at) <= Housekeeping.coolDown {
            for state in [record.produced, record.before] { if case .stamp(let id) = state { needed.insert(id) } }
        }
        return manifest.stamps.compactMap { stamp -> CleanupCandidate? in
            guard !shown.contains(stamp.fileName), !needed.contains(stamp.id) else { return nil }
            let reason: CleanupReason
            let since: Date
            switch stamp.state {
            case .retired(let at, let why):
                guard at <= cutoff else { return nil }
                reason = switch why { case .removed: .removed; case .replaced: .replaced; case .undone: .undone }
                since = at
            case .active:
                let seen = stamp.lastSeen ?? stamp.createdAt
                guard seen <= cutoff else { return nil }
                reason = .notSeen
                since = seen
            }
            return CleanupCandidate(label: stamp.label.text.value, displayName: stamp.displayName.isEmpty ? "Unknown display" : stamp.displayName,
                                    reason: reason, since: since, bytes: fileSize(stamp.fileName), stampID: stamp.id, fileName: stamp.fileName)
        }.sorted { $0.since < $1.since }
    }

    func fileSize(_ fileName: String) -> Int64 {
        Int64((try? store.fileURL(named: fileName).resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
}
