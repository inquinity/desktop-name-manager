import DesktopNameCore
import Foundation
import Observation

/// The Clean Up pane (spec 014, data-model.md CleanUpModel, FR-016a, research R10): what `dnm cleanup` would delete
/// at the age in Settings, the person's selection, and the confirmation. Deleting goes through `carryOut`, which
/// re-checks each image under the store lock, so one put back on screen meanwhile is kept.
@MainActor
@Observable
public final class CleanUpModel {
    public private(set) var plan = CleanupPlan(days: DesktopLabeler.defaultCleanupDays, candidates: [])
    /// The selected images, by stamp ID; none at first.
    public var selection: Set<UUID> = []
    /// One sentence when the list could not be read or the deletion failed.
    public private(set) var message: String?
    /// What the last deletion removed, for the line after it.
    public private(set) var deleted: CleanupPlan?

    @ObservationIgnored private let labeler: DesktopLabeler

    public init(labeler: DesktopLabeler) {
        self.labeler = labeler
    }

    /// Reads the list again (when the pane opens, and after a deletion).
    public func refresh(days: Int) {
        do {
            plan = try labeler.cleanupPlan(days: days)
            message = nil
        } catch {
            plan = CleanupPlan(days: days, candidates: [])
            message = MessageWording.sentence(for: error)
        }
        selection.formIntersection(plan.candidates.map { $0.stampID })
    }

    public var candidates: [CleanupCandidate] { plan.candidates }
    public var totalBytes: Int64 { plan.totalBytes }
    /// The selected candidates, in the list's order.
    public var selected: [CleanupCandidate] { plan.candidates.filter { selection.contains($0.stampID) } }
    public var selectedBytes: Int64 { selected.reduce(0) { $0 + $1.bytes } }
    /// The line in the bar under the list: the selection's count and size, or the whole list's when nothing is
    /// selected.
    public var summary: String {
        guard !selection.isEmpty else {
            let count = plan.candidates.count
            return "\(count) image\(count == 1 ? "" : "s"), \(StorageSummary.format(totalBytes))"
        }
        return "\(selection.count) selected, \(StorageSummary.format(selectedBytes))"
    }
    /// Delete Selected… is off until something is selected.
    public var canDelete: Bool { !selection.isEmpty }
    /// The header checkbox: all selected.
    public var allSelected: Bool { !plan.candidates.isEmpty && selection.count == plan.candidates.count }

    public func selectAll(_ on: Bool) {
        selection = on ? Set(plan.candidates.map { $0.stampID }) : []
    }

    /// The confirmation's question, naming how many and how much (FR-016a).
    public var confirmation: String {
        let count = selection.count
        return "Delete \(count) old labeled image\(count == 1 ? "" : "s") (\(StorageSummary.format(selectedBytes)))?"
    }

    /// Deletes the selected images after the person confirmed. Only these are deleted, and only if they are still
    /// candidates now.
    public func deleteSelected() {
        guard canDelete else { return }
        let chosen = CleanupPlan(days: plan.days, candidates: selected)
        do {
            deleted = try labeler.carryOut(chosen)
            message = nil
        } catch {
            message = MessageWording.sentence(for: error)
        }
        selection = []
        refresh(days: plan.days ?? DesktopLabeler.defaultCleanupDays)
    }
}

extension CleanupReason {
    /// The reason as the list shows it.
    public var phrase: String {
        switch self {
        case .replaced: "Replaced"
        case .removed: "Removed"
        case .undone: "Undone"
        case .notSeen: "Not seen"
        case .notOnAnyDesktop: "Not on any Desktop"
        }
    }
}
