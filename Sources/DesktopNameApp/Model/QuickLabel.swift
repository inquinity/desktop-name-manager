import DesktopNameCore
import Foundation
import Observation

/// The main window's label field (spec 014, data-model.md QuickLabel, FR-013a): label this Desktop in one step.
/// A new label gets the defaults for new labels; a relabel keeps the label's options and changes only the text.
@MainActor
@Observable
public final class QuickLabel {
    public enum State: Equatable, Sendable {
        case ready, invalid, applying, closed
    }

    public let display: Display
    /// The Desktop's label when the main window opened, if it has one.
    public let currentLabel: Label?
    /// What Apply uses besides the text; never shown or changed here.
    public let options: LabelOptions
    public private(set) var text: String
    public private(set) var state: State = .invalid
    /// One sentence under the field, or none: the editor's sentences (FR-008).
    public private(set) var message: String?

    @ObservationIgnored private let applyAction: @MainActor (LabelText, LabelOptions) throws -> Void

    /// `apply` is the same Apply the editor uses (the app passes `LabelingController.apply`), so the result, the undo
    /// record and the errors are the same (FR-007).
    public init(display: Display, currentLabel: Label?, defaults: LabelOptions,
                apply: @escaping @MainActor (LabelText, LabelOptions) throws -> Void) {
        self.display = display
        self.currentLabel = currentLabel
        options = currentLabel.map(LabelOptions.init(keeping:)) ?? defaults
        text = currentLabel?.text.value ?? ""
        applyAction = apply
        validate()
    }

    /// The main window closed: a pending Apply is not made.
    public func close() { state = .closed }

    /// The text as typed or pasted, cleaned as in the editor.
    public func setText(_ raw: String) {
        let cleaned = EditorDraft.cleaned(raw)
        guard cleaned != text, state != .applying, state != .closed else { return }
        text = cleaned
        validate()
    }

    /// Label and Return are on only for valid text that differs from the current label.
    public var canApply: Bool { state == .ready }

    /// Applies once, after the working state is drawn. On success the main window closes; on failure it stays open
    /// with the sentence and the Desktop as it was.
    public func apply() async {
        guard state == .ready, let labelText = try? LabelText(text) else { return }
        state = .applying
        await Working.drawn()
        guard state == .applying else { return }   // the main window closed meanwhile
        do {
            try applyAction(labelText, options)
            state = .closed
        } catch {
            state = .ready
            message = MessageWording.sentence(for: error)
        }
    }

    private func validate() {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            state = .invalid
            message = nil
            return
        }
        do {
            let labelText = try LabelText(text)
            message = nil
            state = labelText == currentLabel?.text ? .invalid : .ready   // unchanged: nothing to apply
        } catch {
            state = .invalid
            message = MessageWording.sentence(for: error)
        }
    }
}

extension LabelOptions {
    /// The options that give `label` again: its chosen values, and Automatic where it was chosen automatically.
    public init(keeping label: Label) {
        self.init(look: label.automatic.contains(.look) ? nil : label.look,
                  textColor: label.automatic.contains(.textColor) ? nil : label.textColor,
                  position: label.position, size: label.size)
    }
}
