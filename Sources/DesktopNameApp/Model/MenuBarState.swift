import DesktopNameCore
import Foundation

/// What the menu-bar item and the main window show for one display (spec 014, data-model.md MenuBarState, research
/// R5). Read when the main window opens, and the label and undo parts again when the store changes; it is never kept
/// up to date in the background.
public struct MenuBarState: Equatable, Sendable {
    public var activeDisplay: Display?
    /// The label of the Desktop on screen of the active display, if it shows one of this store's stamps.
    public var currentLabel: Label?
    /// What Undo would undo there, if `checkUndo` passes.
    public var undo: LabelingController.UndoOffer?
    /// A sentence when the label could not be read (for example a store newer than the app).
    public var problem: String?

    public var undoAvailable: Bool { undo != nil }

    public init(activeDisplay: Display?, currentLabel: Label?, undo: LabelingController.UndoOffer?, problem: String? = nil) {
        self.activeDisplay = activeDisplay
        self.currentLabel = currentLabel
        self.undo = undo
        self.problem = problem
    }

    /// The status item's text: the app's fixed text in Icon and text mode, else none. Never the label (FR-010).
    public static func itemTitle(for mode: MenuBarMode) -> String? {
        mode == .iconAndText ? AppInfo.menuBarText : nil
    }

    /// The display the main window is about. With separate Spaces, the display whose menu bar was clicked (or the
    /// active display, for the hotkey); without them, one Desktop spans every display and the main display is used, as
    /// `dnm` treats it (spec Edge Cases).
    public static func targetDisplay(chosen: Display?, displays: [Display], separateSpaces: Bool) -> Display? {
        if !separateSpaces { return displays.first(where: \.isMain) ?? chosen }
        if let chosen, displays.contains(where: { $0.uuid == chosen.uuid }) { return chosen }
        return displays.first(where: \.isMain) ?? displays.first
    }

    /// Reads the label and the undo offer for `display`. Reads only: no housekeeping and no lock, so it can run on
    /// every store change without writing anything back.
    @MainActor
    public static func read(for display: Display?, controller: LabelingController) -> MenuBarState {
        guard let display else { return MenuBarState(activeDisplay: nil, currentLabel: nil, undo: nil) }
        do {
            let label = try controller.labeler.currentLabel(on: display)
            return MenuBarState(activeDisplay: display, currentLabel: label, undo: controller.undoOffer(on: display))
        } catch {
            return MenuBarState(activeDisplay: display, currentLabel: nil, undo: nil, problem: MessageWording.sentence(for: error))
        }
    }
}

/// The counts and sizes the main window's storage rows and the Configuration pane show (FR-016b, research R8, R10).
/// Computed when a window opens, not on every change: it reads the stamp files' sizes.
public struct StorageSummary: Equatable, Sendable {
    /// Labels in use: the labeled Desktops `dnm list` reports.
    public var labelsInUse: Int
    /// How many displays those labels are on.
    public var displaysWithLabels: Int
    /// The space every labeled image uses.
    public var spaceUsed: Int64
    /// What Clean Up could free at the age in Settings.
    public var oldImages: Int64

    public init(labelsInUse: Int, displaysWithLabels: Int, spaceUsed: Int64, oldImages: Int64) {
        self.labelsInUse = labelsInUse
        self.displaysWithLabels = displaysWithLabels
        self.spaceUsed = spaceUsed
        self.oldImages = oldImages
    }

    public static let empty = StorageSummary(labelsInUse: 0, displaysWithLabels: 0, spaceUsed: 0, oldImages: 0)

    /// True while what Clean Up could free is at least `dnm`'s nudge threshold, 50 MB (FR-016b). Not throttled: it is
    /// a state, not a reminder.
    public var cleanUpWarning: Bool { oldImages >= DesktopLabeler.nudgeThresholdBytes }

    @MainActor
    public static func read(_ labeler: DesktopLabeler, days: Int) throws -> StorageSummary {
        let labeled = try labeler.listDesktops().entries.filter { $0.label != nil }
        let manifest = try labeler.store.readManifest()
        let space = manifest.stamps.reduce(Int64(0)) { $0 + fileSize(labeler.store, $1.fileName) }
        return StorageSummary(labelsInUse: labeled.count, displaysWithLabels: Set(labeled.map(\.displayName)).count,
                              spaceUsed: space, oldImages: try labeler.cleanupPlan(days: days).totalBytes)
    }

    static func fileSize(_ store: Store, _ name: String) -> Int64 {
        Int64((try? store.fileURL(named: name).resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    /// Sizes as Finder shows them ("63.4 MB").
    public static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
