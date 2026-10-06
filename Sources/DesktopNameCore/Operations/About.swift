import Foundation

/// What `dnm about` prints (FR-030).
public struct AboutInfo: Equatable, Sendable, Encodable {
    public var name: String
    public var version: String
    public var license: String
    public var source: String
    /// Where labeled images and their records are kept, with the home folder shown as `~`.
    public var dataDirectory: String
    public var permissions: [String]
}

public enum About {
    public static let source = "https://github.com/inquinity/desktop-name-manager"

    /// The permissions statement, shared with the app's About window.
    public static let permissions = [
        "Labeling the current Desktop needs no permissions.",
        "Accessibility is used only by --desktop, to press macOS's own \"Move left a space\" and \"Move right a space\" shortcuts, because macOS gives apps no public way to switch Desktops. Nothing else is typed or read.",
        "No network access and no telemetry.",
    ]

    public static func info(dataDirectory: URL, version: String = DesktopNameCoreInfo.displayVersion) -> AboutInfo {
        AboutInfo(name: "Desktop Name Manager (dnm, also installed as desktop-name)", version: version, license: "MIT",
                  source: source, dataDirectory: (dataDirectory.path as NSString).abbreviatingWithTildeInPath,
                  permissions: permissions)
    }
}
