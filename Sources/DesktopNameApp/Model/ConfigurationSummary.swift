import DesktopNameCore
import Foundation

/// What the Configuration and About panes show, from the same sources as `dnm check` and `dnm about` (spec 014, FR-019,
/// research R8), so the values they share never disagree. Only what the app can read: no Accessibility row and no
/// Space-shortcut row.
public struct ConfigurationSummary: Equatable, Sendable {
    /// "macOS 26.1 (Build …), Apple M4": the detail of `dnm check`'s macOS line.
    public var macOS: String
    public var separateSpaces: Bool
    public var displayCount: Int
    /// The data folder, shortened with `~`, as `dnm about` prints it.
    public var dataFolder: String
    /// The data folder itself, for Show in Finder.
    public var dataFolderURL: URL

    public init(macOS: String, separateSpaces: Bool, displayCount: Int, dataFolder: String, dataFolderURL: URL) {
        self.macOS = macOS
        self.separateSpaces = separateSpaces
        self.displayCount = displayCount
        self.dataFolder = dataFolder
        self.dataFolderURL = dataFolderURL
    }

    /// Reads it through `check` and `About.info`, with `configuration` the machine facts (`Configuration.current()`
    /// in the app).
    @MainActor
    public static func read(_ labeler: DesktopLabeler, configuration: Configuration) -> ConfigurationSummary {
        let report = labeler.check(configuration)
        let macOS = report.items.first { $0.name == "macOS" }?.detail ?? configuration.macOSVersion
        let separate = report.items.first { $0.name == "Separate Spaces" }.map { $0.state == .ok } ?? configuration.displaysHaveSeparateSpaces
        let displays = (try? labeler.system.displays().count) ?? 0
        let about = About.info(dataDirectory: labeler.store.directory)
        return ConfigurationSummary(macOS: macOS, separateSpaces: separate, displayCount: displays,
                                    dataFolder: about.dataDirectory, dataFolderURL: labeler.store.directory)
    }
}

/// Open at login (spec 014, FR-016, research R4). The app's implementation uses `SMAppService.mainApp`; tests use a
/// fake. Its status is read each time Settings shows it, so a login item turned off in System Settings shows as off.
@MainActor
public protocol LoginItem: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}
