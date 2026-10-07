import AppKit
import ApplicationServices
import Foundation

/// The machine facts `dnm check` reports, read through public interfaces (FR-031).
public struct Configuration: Equatable, Sendable {
    public var macOSVersion: String
    public var chip: String
    public var displaysHaveSeparateSpaces: Bool
    public var accessibilityGranted: Bool

    public init(macOSVersion: String, chip: String, displaysHaveSeparateSpaces: Bool, accessibilityGranted: Bool) {
        self.macOSVersion = macOSVersion
        self.chip = chip
        self.displaysHaveSeparateSpaces = displaysHaveSeparateSpaces
        self.accessibilityGranted = accessibilityGranted
    }

    /// Reads this Mac's configuration. Never prompts for a permission.
    @MainActor public static func current() -> Configuration {
        // screensHaveSeparateSpaces reports false until the process has an NSApplication (seen on macOS 27).
        _ = NSApplication.shared
        return Configuration(macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString, chip: chipName(),
                      displaysHaveSeparateSpaces: NSScreen.screensHaveSeparateSpaces,
                      accessibilityGranted: AXIsProcessTrusted())
    }

    static func chipName() -> String {
        var size = 0
        if sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 1 {
            var bytes = [CChar](repeating: 0, count: size)
            if sysctlbyname("machdep.cpu.brand_string", &bytes, &size, nil, 0) == 0 {
                return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            }
        }
        #if arch(arm64)
        return "Apple silicon"
        #else
        return "Intel"
        #endif
    }
}

public enum CheckState: String, Equatable, Sendable, Encodable {
    /// Set up as needed.
    case ok
    /// Needs attention for some feature; the item says which and how to fix it.
    case attention
    /// Cannot be read through public interfaces.
    case unknown
    /// For information.
    case info
}

public struct CheckItem: Equatable, Sendable, Encodable {
    public var name: String
    public var state: CheckState
    public var detail: String
    /// How to fix it, when something is missing.
    public var fix: String?

    private enum CodingKeys: String, CodingKey { case name, state, detail, fix }

    /// `fix` is an explicit null when there is nothing to fix, as in the other JSON reports.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(state, forKey: .state)
        try container.encode(detail, forKey: .detail)
        try container.encode(fix, forKey: .fix)
    }
}

public struct CheckReport: Equatable, Sendable, Encodable {
    public var items: [CheckItem]
}

extension DesktopLabeler {
    /// The configuration report (FR-031). Reads only: no cleanup, no lock, no permission prompt.
    public func check(_ configuration: Configuration) -> CheckReport {
        var items = [
            CheckItem(name: "macOS", state: .info, detail: "\(configuration.macOSVersion), \(configuration.chip)"),
            configuration.displaysHaveSeparateSpaces
                ? CheckItem(name: "Separate Spaces", state: .ok, detail: "Displays have separate Spaces.")
                : CheckItem(name: "Separate Spaces", state: .attention, detail: "Displays share one set of Spaces, so labels apply across displays.",
                            fix: "System Settings > Desktop & Dock > Mission Control: turn on \"Displays have separate Spaces\", then log out and in."),
        ]
        items.append(displaysItem())
        items.append(configuration.accessibilityGranted
            ? CheckItem(name: "Accessibility", state: .ok, detail: "Granted to the app running dnm, so --desktop can switch Desktops. \(About.accessibilityScope)")
            : CheckItem(name: "Accessibility", state: .attention, detail: "Not granted to the app running dnm. Only --desktop needs it; labeling the current Desktop works without it. \(About.accessibilityScope)",
                        fix: "\(About.accessibilitySettings): turn on the app you run dnm from (your terminal)."))
        items.append(CheckItem(name: "Space shortcuts", state: .unknown,
                               detail: "macOS offers no public way to read whether \"Move left a space\" and \"Move right a space\" are on. --desktop says so if they are off.",
                               fix: "To look: \(About.shortcutSettings)."))
        items.append(storeItem())
        return CheckReport(items: items)
    }

    private func displaysItem() -> CheckItem {
        do {
            let names = try system.displays().map { $0.isMain ? "\($0.name) (main)" : $0.name }
            return CheckItem(name: "Displays", state: .info, detail: names.joined(separator: ", "))
        } catch {
            return CheckItem(name: "Displays", state: .attention, detail: "Cannot list the displays: \(error.localizedDescription)")
        }
    }

    private func storeItem() -> CheckItem {
        do {
            let manifest = try store.readManifest()
            let active = manifest.stamps.filter(\.isActive).count
            let bytes = manifest.stamps.reduce(Int64(0)) { $0 + fileSize($1.fileName) }
            let freeable = try pruneCandidates(in: manifest).reduce(Int64(0)) { $0 + $1.bytes }
            let size = ByteCountFormatter()
            var detail = "\(active) active label\(active == 1 ? "" : "s"), \(manifest.stamps.count) labeled image\(manifest.stamps.count == 1 ? "" : "s") using \(size.string(fromByteCount: bytes))."
            detail += freeable > 0 ? " `dnm prune` could free \(size.string(fromByteCount: freeable))." : " Nothing to prune."
            return CheckItem(name: "Stored labels", state: .info, detail: detail)
        } catch {
            return CheckItem(name: "Stored labels", state: .attention, detail: error.localizedDescription)
        }
    }
}
