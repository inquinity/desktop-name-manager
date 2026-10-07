import Foundation

/// An open-source component compiled into the binary (constitution 2.1.0). `scripts/make-acknowledgements.sh`
/// checks that this list names each binary component of `Acknowledgements.md` at the version that ships.
public struct Acknowledgement: Equatable, Sendable {
    public var name: String
    public var version: String
    public var license: String
    /// The license, pinned to the version that ships.
    public var url: String
}

/// What `dnm about` prints (FR-030).
public struct AboutInfo: Equatable, Sendable {
    public var name: String
    public var version: String
    public var license: String
    public var source: String
    /// Where labeled images and their records are kept, with the home folder shown as `~`.
    public var dataDirectory: String
    public var permissions: [String]
    public var acknowledgements: [Acknowledgement]
}

public enum About {
    public static let source = "https://github.com/inquinity/desktop-name-manager"

    /// The components compiled into `dnm`, in the order of `Acknowledgements.md`.
    public static let acknowledgements = [
        Acknowledgement(name: "swift-argument-parser", version: "1.8.2",
                        license: "Apache License 2.0 with Runtime Library Exception",
                        url: "https://github.com/apple/swift-argument-parser/blob/1.8.2/LICENSE.txt"),
    ]

    /// What the Accessibility permission covers for a command-line tool (security plan S1).
    public static let accessibilityScope = "macOS grants it to the whole app you run dnm from (your terminal), so every program run in that app can then send keystrokes and clicks too; turn it off when you no longer need --desktop."

    /// Where the Accessibility permission is granted; macOS 27 renamed the panel.
    /// Where the "Move left/right a space" shortcuts are turned on. They are only in the Keyboard pane.
    public static let shortcutSettings = "System Settings > Keyboard (near the bottom of the sidebar) > Keyboard Shortcuts… > Mission Control, then expand the Mission Control group and turn on \"Move left a space\" and \"Move right a space\". Desktop & Dock > Shortcuts… does not list them"

    public static let accessibilitySettings = "System Settings > Privacy & Security > Accessibility (macOS 26) or Device Control and Data Access (macOS 27)"

    /// The permissions statement, shared with the app's About window.
    public static let permissions = [
        "Labeling the current Desktop needs no permissions.",
        "Accessibility is used only by --desktop, to press macOS's own \"Move left a space\" and \"Move right a space\" shortcuts, because macOS gives apps no public way to switch Desktops. Nothing else is typed or read. " + accessibilityScope,
        "No network access and no telemetry.",
    ]

    public static func info(dataDirectory: URL, version: String = DesktopNameCoreInfo.displayVersion) -> AboutInfo {
        AboutInfo(name: "Desktop Name Manager (dnm, also installed as desktop-name)", version: version, license: "MIT",
                  source: source, dataDirectory: (dataDirectory.path as NSString).abbreviatingWithTildeInPath,
                  permissions: permissions, acknowledgements: acknowledgements)
    }
}
