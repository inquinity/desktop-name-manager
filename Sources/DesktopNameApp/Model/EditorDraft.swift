import CoreGraphics
import DesktopNameCore
import Foundation
import Observation

/// What the editor does when the person applies or removes (spec 014): one core call each. The app passes its
/// `LabelingController`; the prototype passes calls on a fake wallpaper system and a temporary store.
public struct EditorActions {
    public var apply: @MainActor (LabelText, LabelOptions) throws -> Void
    public var remove: @MainActor () throws -> Void

    public init(apply: @escaping @MainActor (LabelText, LabelOptions) throws -> Void,
                remove: @escaping @MainActor () throws -> Void) {
        self.apply = apply
        self.remove = remove
    }
}

/// The editor's state while it is open for one Desktop (spec 014, data-model.md EditorDraft). Dropped on Cancel or
/// close; nothing here is stored.
@MainActor
@Observable
public final class EditorDraft {
    public enum State: Equatable, Sendable {
        case loading, ready, invalid, applying, removing, unsupported, closed
    }

    /// The four style choices, each shown as a small render over this Desktop's wallpaper.
    public enum StyleChoice: Hashable, CaseIterable, Sendable {
        case automatic, plain, halo, frosted

        public var look: Look? {
            switch self {
            case .automatic: nil
            case .plain: .plain
            case .halo: .halo
            case .frosted: .frosted
            }
        }

        public init(_ look: Look?) {
            switch look {
            case nil: self = .automatic
            case .plain?: self = .plain
            case .halo?: self = .halo
            case .frosted?: self = .frosted
            }
        }
    }

    public let display: Display
    /// The Desktop's label when the editor opened, if it has one: Remove Label is offered only then.
    public let currentLabel: Label?
    public private(set) var text: String
    public private(set) var style: StyleChoice
    /// nil is Automatic.
    public private(set) var color: TextColor?
    public private(set) var position: Position
    public private(set) var size: Size
    public private(set) var state: State = .loading
    /// One sentence under the field, or none (FR-008, FR-009).
    public private(set) var message: String?
    /// The latest preview, or the bare wallpaper while the text is empty.
    public private(set) var preview: CGImage?
    public private(set) var chips: [StyleChoice: CGImage] = [:]
    /// What Automatic picks for this spot, as the latest render chose it.
    public private(set) var automaticLook: Look?
    /// How long the latest preview took to render (prototype spike S2).
    public private(set) var lastRenderSeconds: Double?

    @ObservationIgnored private let actions: EditorActions
    @ObservationIgnored private var source: PreviewSource?
    @ObservationIgnored private var chipSource: PreviewSource?
    @ObservationIgnored private var generation = 0
    /// True while a preview is being rendered (tests wait on it).
    public private(set) var isRendering = false
    @ObservationIgnored public let previewWidth: Int
    @ObservationIgnored public let chipWidth: Int

    /// Options start from the Desktop's label when it has one, else from `defaults` (the defaults for new labels).
    public init(display: Display, currentLabel: Label?, defaults: LabelOptions, actions: EditorActions,
                previewWidth: Int = 800, chipWidth: Int = 240) {
        self.display = display
        self.currentLabel = currentLabel
        self.actions = actions
        self.previewWidth = previewWidth
        self.chipWidth = chipWidth
        if let label = currentLabel {
            text = label.text.value
            style = label.automatic.contains(.look) ? .automatic : StyleChoice(label.look)
            color = label.automatic.contains(.textColor) ? nil : label.textColor
            position = label.position
            size = label.size
        } else {
            text = ""
            style = StyleChoice(defaults.look)
            color = defaults.textColor
            position = defaults.position ?? .default
            size = defaults.size ?? .default
        }
    }

    // MARK: - Opening

    /// Loads the Desktop's picture once (the image `setLabel` would stamp). A wallpaper the app will not label leaves
    /// the editor in `unsupported`, with its sentence and no Apply.
    public func load(_ makeSource: () throws -> PreviewSource) {
        do {
            let source = try makeSource()
            self.source = source
            chipSource = source.scaled(toWidth: chipWidth)
            preview = source.image
            state = .ready
            validate()
            scheduleRender()
        } catch {
            state = .unsupported
            message = MessageWording.sentence(for: error)
        }
    }

    // MARK: - Editing

    /// The text as typed or pasted. Line breaks and control characters are left out (prototype review round 3), so
    /// they never need a message.
    public func setText(_ raw: String) {
        let cleaned = Self.cleaned(raw)
        guard cleaned != text else { return }
        text = cleaned
        validate()
        scheduleRender()
    }

    public func setStyle(_ choice: StyleChoice) { style = choice; scheduleRender() }
    public func setColor(_ value: TextColor?) { color = value; scheduleRender() }
    public func setPosition(_ value: Position) { position = value; scheduleRender() }
    public func setSize(_ value: Size) { size = value; scheduleRender() }

    /// The options as the core takes them.
    public var options: LabelOptions {
        LabelOptions(look: style.look, textColor: color, position: position, size: size)
    }

    public var canApply: Bool { state == .ready }
    public var canRemove: Bool { currentLabel != nil && (state == .ready || state == .invalid || state == .unsupported) }

    /// Line breaks and the characters `LabelText` refuses (control and text-direction characters) are dropped.
    static func cleaned(_ raw: String) -> String {
        let kept = raw.unicodeScalars.filter { scalar in
            !TerminalText.isUnsafe(scalar) && !Character(scalar).isNewline
        }
        return String(String.UnicodeScalarView(kept))
    }

    private func validate() {
        guard state == .ready || state == .invalid else { return }
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            state = .invalid
            message = nil   // an empty field turns Apply off without a word
            return
        }
        do {
            _ = try LabelText(text)
            state = .ready
            message = nil
        } catch {
            state = .invalid
            message = MessageWording.sentence(for: error)
        }
    }

    // MARK: - Applying

    /// Applies once; a second press while applying does nothing. On failure the editor stays open with the sentence,
    /// and the Desktop is as it was.
    public func apply() {
        guard state == .ready, let labelText = try? LabelText(text) else { return }
        state = .applying
        do {
            try actions.apply(labelText, options)
            state = .closed
        } catch {
            state = .ready
            message = MessageWording.sentence(for: error)
        }
    }

    public func remove() {
        guard canRemove else { return }
        let before = state
        state = .removing
        do {
            try actions.remove()
            state = .closed
        } catch {
            state = before
            message = MessageWording.sentence(for: error)
        }
    }

    public func cancel() { state = .closed }

    // MARK: - Preview

    /// Renders off the main thread. Changes while a render runs are coalesced: when it finishes, only the newest
    /// request is rendered.
    private func scheduleRender() {
        generation += 1
        guard source != nil, !isRendering else { return }
        startRender()
    }

    private func startRender() {
        guard let source, let chipSource else { return }
        let wanted = generation
        let labelText = try? LabelText(text)
        let options = self.options
        let previewWidth = self.previewWidth, chipWidth = self.chipWidth
        isRendering = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.render(text: labelText, options: options, source: source, chipSource: chipSource,
                            previewWidth: previewWidth, chipWidth: chipWidth)
            }.value
            self.finish(result, generation: wanted)
        }
    }

    private func finish(_ result: RenderResult, generation rendered: Int) {
        isRendering = false
        guard state != .closed else { return }   // the editor closed meanwhile: nothing to show
        if rendered == generation {
            preview = result.preview
            chips = result.chips
            automaticLook = result.automaticLook
            lastRenderSeconds = result.seconds
        } else {
            startRender()   // something changed meanwhile: render the newest request
        }
    }

    struct RenderResult: @unchecked Sendable {
        var preview: CGImage?
        var chips: [StyleChoice: CGImage]
        var automaticLook: Look?
        var seconds: Double
    }

    nonisolated static func render(text: LabelText?, options: LabelOptions, source: PreviewSource, chipSource: PreviewSource,
                                   previewWidth: Int, chipWidth: Int) -> RenderResult {
        let started = Date()
        guard let text else {
            return RenderResult(preview: source.image, chips: [:], automaticLook: nil, seconds: Date().timeIntervalSince(started))
        }
        let main = try? LabelPreview.render(PreviewRequest(text: text, options: options, maxPixelWidth: previewWidth), source: source)
        let seconds = Date().timeIntervalSince(started)
        var chips: [StyleChoice: CGImage] = [:]
        var automaticLook: Look?
        for choice in StyleChoice.allCases {
            var chipOptions = options
            chipOptions.look = choice.look
            if let chip = try? LabelPreview.render(PreviewRequest(text: text, options: chipOptions, maxPixelWidth: chipWidth),
                                                   source: chipSource) {
                chips[choice] = chip.image
                if choice == .automatic { automaticLook = chip.label.look }
            }
        }
        return RenderResult(preview: main?.image ?? source.image, chips: chips, automaticLook: automaticLook, seconds: seconds)
    }
}
