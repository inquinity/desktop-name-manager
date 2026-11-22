import DesktopNameCore
import Foundation
import Observation

/// The Settings window's state (spec 014, contracts/app-ui.md §Settings window): the selected pane, and what each
/// pane reads when it is shown.
@MainActor
@Observable
public final class SettingsModel {
    public var pane: SettingsPane = .general {
        didSet { paneShown() }
    }
    public let settings: AppSettings
    public let hotkey: HotkeySetting
    public let cleanUp: CleanUpModel
    public let displays: DisplaysModel
    public private(set) var storage: StorageSummary = .empty
    public private(set) var configuration: ConfigurationSummary?
    public private(set) var labels: [LabelInUse] = []
    /// Whether the app opens at login, read from the system each time General is shown (research R4).
    public private(set) var opensAtLogin = false
    /// One sentence when Open at login could not be changed, or a pane could not be read.
    public private(set) var message: String?
    /// Counts refused "Nothing (hidden)" choices; the picker is rebuilt on each so it shows the kept value.
    public private(set) var menuBarRefusals = 0
    /// Acknowledgements are open in the About pane.
    public var showingAcknowledgements = false

    @ObservationIgnored public let labeler: DesktopLabeler
    @ObservationIgnored private let loginItem: LoginItem
    @ObservationIgnored private let machine: @MainActor () -> Configuration
    @ObservationIgnored public var onMenuBarModeChange: (@MainActor (MenuBarMode) -> Void)?

    public init(settings: AppSettings, labeler: DesktopLabeler, loginItem: LoginItem, hotkey: HotkeySetting,
                machine: @escaping @MainActor () -> Configuration) {
        self.settings = settings
        self.labeler = labeler
        self.loginItem = loginItem
        self.hotkey = hotkey
        self.machine = machine
        cleanUp = CleanUpModel(labeler: labeler)
        displays = DisplaysModel(labeler: labeler)
    }

    /// Shows `pane` and reads what it needs.
    public func show(_ pane: SettingsPane) {
        showingAcknowledgements = false
        if self.pane == pane { paneShown() } else { self.pane = pane }
    }

    /// Reads what the selected pane shows.
    public func paneShown() {
        message = nil
        switch pane {
        case .general:
            opensAtLogin = loginItem.isEnabled
        case .cleanUp:
            cleanUp.refresh(days: settings.cleanUpDays)
            readStorage()
        case .configuration:
            configuration = ConfigurationSummary.read(labeler, configuration: machine())
            readStorage()
        case .displays:
            displays.refresh()
        case .labels:
            do { labels = try LabelInUse.read(labeler) } catch { labels = []; message = MessageWording.sentence(for: error) }
        case .about:
            break
        }
    }

    private func readStorage() {
        do { storage = try StorageSummary.read(labeler, days: settings.cleanUpDays) } catch { message = MessageWording.sentence(for: error) }
    }

    public func setOpensAtLogin(_ on: Bool) {
        do {
            try loginItem.setEnabled(on)
            message = nil
        } catch {
            message = "Open at login could not be changed: \(error.localizedDescription)"
        }
        opensAtLogin = loginItem.isEnabled
    }

    /// FR-014a: the item can be hidden only while the main window's hotkey works; it is then the way to Settings.
    public static let hideNeedsHotkey = "Record a shortcut to open the main window first: with the item hidden, it is the way to Settings."

    public func setMenuBarMode(_ mode: MenuBarMode) {
        if mode == .hidden, !hotkey.opensMainWindow {
            message = Self.hideNeedsHotkey
            menuBarRefusals += 1   // the picker redraws with the kept value even when the sentence is unchanged
            return
        }
        if message == Self.hideNeedsHotkey { message = nil }
        settings.menuBarMode = mode
        onMenuBarModeChange?(mode)
    }

    public func setCleanUpDays(_ days: Int) {
        settings.cleanUpDays = days
        cleanUp.refresh(days: settings.cleanUpDays)
    }

    /// The labels' total, under the Labels pane's list.
    public var labelsTotal: Int64 { labels.reduce(0) { $0 + $1.bytes } }
}
