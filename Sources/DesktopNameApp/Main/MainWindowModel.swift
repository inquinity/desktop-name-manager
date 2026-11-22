import DesktopNameCore
import Foundation
import Observation

/// The Settings window's panes, in sidebar order (contracts/app-ui.md §Settings window).
public enum SettingsPane: String, CaseIterable, Hashable, Sendable {
    case general, cleanUp, configuration, displays, labels, about

    public var title: String {
        switch self {
        case .general: "General"
        case .cleanUp: "Clean Up"
        case .configuration: "Configuration"
        case .displays: "Displays"
        case .labels: "Labels"
        case .about: "About"
        }
    }

    public var symbol: String {
        switch self {
        case .general: "gearshape"
        case .cleanUp: "trash"
        case .configuration: "info.circle"
        case .displays: "display"
        case .labels: "tag"
        case .about: "questionmark.circle"
        }
    }
}

/// What the main window's items do outside it: the presenter opens the editor in the same panel, the Settings window
/// at a pane, or quits; and closes the panel.
public struct MainWindowActions {
    public var openEditor: @MainActor () -> Void
    public var openSettings: @MainActor (SettingsPane) -> Void
    public var quit: @MainActor () -> Void
    public var close: @MainActor () -> Void

    public init(openEditor: @escaping @MainActor () -> Void, openSettings: @escaping @MainActor (SettingsPane) -> Void,
                quit: @escaping @MainActor () -> Void, close: @escaping @MainActor () -> Void) {
        self.openEditor = openEditor
        self.openSettings = openSettings
        self.quit = quit
        self.close = close
    }
}

/// The main window for one display (spec 014, contracts/app-ui.md §Main window): its label, the quick label field,
/// Remove and Undo, and the counts and sizes, read when it opens.
@MainActor
@Observable
public final class MainWindowModel {
    public let display: Display
    public private(set) var state: MenuBarState
    public private(set) var storage: StorageSummary
    public private(set) var quick: QuickLabel
    /// One sentence after a Remove or Undo failed.
    public private(set) var message: String?
    public private(set) var working = false
    /// True once the main window closed; nothing more is changed from it.
    public private(set) var closed = false

    @ObservationIgnored private let controller: LabelingController
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored public let actions: MainWindowActions

    public init(display: Display, controller: LabelingController, settings: AppSettings, actions: MainWindowActions) {
        self.display = display
        self.controller = controller
        self.settings = settings
        self.actions = actions
        let state = MenuBarState.read(for: display, controller: controller)
        self.state = state
        storage = (try? StorageSummary.read(controller.labeler, days: settings.cleanUpDays)) ?? .empty
        quick = Self.makeQuick(display: display, label: state.currentLabel, controller: controller, settings: settings)
    }

    private static func makeQuick(display: Display, label: Label?, controller: LabelingController,
                                  settings: AppSettings) -> QuickLabel {
        QuickLabel(display: display, currentLabel: label, defaults: settings.newLabelOptions) { text, options in
            try controller.apply(text, options: options, on: display)
        }
    }

    /// The store changed (an app run, `dnm`, or another copy): read the label and Undo again. Reads only. The field is
    /// rebuilt only if the label changed and nothing was typed.
    public func storeChanged() {
        let fresh = MenuBarState.read(for: display, controller: controller)
        let untouched = quick.text == (state.currentLabel?.text.value ?? "")
        state = fresh
        if untouched, fresh.currentLabel != quick.currentLabel, quick.state != .applying, quick.state != .closed {
            quick = Self.makeQuick(display: display, label: fresh.currentLabel, controller: controller, settings: settings)
        }
    }

    /// The main window closed (a click outside, Escape, or another page): a pending change is not made.
    public func close() {
        closed = true
        quick.close()
    }

    public func remove() async {
        await change { try self.controller.remove(on: self.display) }
    }

    public func undo() async {
        await change { try self.controller.undo(on: self.display) }
    }

    private func change(_ body: @MainActor () throws -> Void) async {
        guard !working else { return }
        working = true
        await Working.drawn()
        guard !closed else { working = false; return }   // the main window closed meanwhile
        do {
            try body()
            message = nil
            working = false
            actions.close()
        } catch {
            message = MessageWording.sentence(for: error)
            working = false
            storeChanged()
        }
    }

    /// "4 on 2 displays".
    public var labelsInUseText: String {
        let labels = storage.labelsInUse, displays = storage.displaysWithLabels
        return "\(labels) on \(displays) display\(displays == 1 ? "" : "s")"
    }
}
