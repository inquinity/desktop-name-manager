import DesktopNameCore
import Foundation

/// Apply, Remove and Undo for the app (spec 014, research R7): each is one call to the same `DesktopLabeler`
/// operation `dnm` makes, on the main actor (the real wallpaper system and the store's per-thread lock need it). The
/// store is read as it is when the button is pressed, and its lock is held only for that call, never while a window is
/// open.
@MainActor
public final class LabelingController {
    /// What Undo would undo on a display: the main window's "Undo <Label|Remove> on <display>".
    public struct UndoOffer: Equatable, Sendable {
        public var removes: Bool
        public var displayName: String

        public var title: String { "Undo \(removes ? "Remove" : "Label") on \(displayName)" }
    }

    public let labeler: DesktopLabeler

    public init(labeler: DesktopLabeler) {
        self.labeler = labeler
    }

    /// Labels the Desktop on screen of `display`, exactly as `dnm set` with the same text and options (FR-007).
    @discardableResult
    public func apply(_ text: LabelText, options: LabelOptions, on display: Display) throws -> SetLabelResult {
        try labeler.setLabel(text, options: options, on: display)
    }

    /// Removes the label of the Desktop on screen of `display`, as `dnm remove`.
    @discardableResult
    public func remove(on display: Display) throws -> RemoveLabelResult {
        try labeler.removeLabel(on: display)
    }

    /// Undoes the last change on `display`, as `dnm undo`; a change `dnm` made is undone the same way.
    @discardableResult
    public func undo(on display: Display) throws -> UndoResult {
        try labeler.undoLastChange(on: display)
    }

    /// The Undo the main window offers for `display`, or nil when `checkUndo` refuses (nothing within 60 seconds, or
    /// the wallpaper changed since). Reads only.
    public func undoOffer(on display: Display) -> UndoOffer? {
        guard (try? labeler.checkUndo(on: display, onScreen: true)) != nil,
              let record = try? labeler.store.readManifest().changes.first(where: { $0.displayUUID == display.uuid })
        else { return nil }
        return UndoOffer(removes: record.kind == .remove, displayName: display.name)
    }
}

/// The working state is shown before a change starts (research R7): the model enters it, then waits about one frame so
/// it is drawn, then makes the call.
enum Working {
    static func drawn() async {
        try? await Task.sleep(for: .milliseconds(16))
    }
}
