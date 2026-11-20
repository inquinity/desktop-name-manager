import DesktopNameCore
import Foundation
import Observation

/// What the menu-bar item shows (FR-010).
public enum MenuBarMode: String, CaseIterable, Sendable {
    case iconAndText, icon, hidden
}

/// The app's settings, kept in its own user defaults (spec 014, contracts/app-settings.md, research R9). `dnm` never
/// reads them, and nothing here is written to the label store (FR-018).
///
/// An unknown or invalid value reads as the default and is not rewritten until the person changes that setting.
@MainActor
@Observable
public final class AppSettings {
    enum Key {
        static let menuBarMode = "menuBarMode"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let defaultLook = "defaultLook"
        static let defaultColor = "defaultColor"
        static let defaultPosition = "defaultPosition"
        static let defaultSize = "defaultSize"
        static let cleanUpDays = "cleanUpDays"
        static let welcomeShown = "welcomeShown"
    }

    /// The range of `cleanUpDays`.
    public static let cleanUpDaysRange = 1...3650

    @ObservationIgnored private let defaults: UserDefaults

    public var menuBarMode: MenuBarMode {
        didSet { defaults.set(menuBarMode.rawValue, forKey: Key.menuBarMode) }
    }
    /// The hotkey, or none. Set only after it was registered (FR-015); clearing it removes both keys.
    public var hotkey: Shortcut? {
        didSet {
            if let hotkey {
                defaults.set(Int(hotkey.keyCode), forKey: Key.hotkeyKeyCode)
                defaults.set(Int(hotkey.modifiers), forKey: Key.hotkeyModifiers)
            } else {
                defaults.removeObject(forKey: Key.hotkeyKeyCode)
                defaults.removeObject(forKey: Key.hotkeyModifiers)
            }
        }
    }
    /// The defaults for new labels from the main window and the editor (FR-018). nil is Automatic.
    public var defaultLook: Look? {
        didSet { defaults.set(defaultLook?.rawValue ?? "automatic", forKey: Key.defaultLook) }
    }
    /// nil is Automatic.
    public var defaultColor: TextColor? {
        didSet { defaults.set(Self.spelling(of: defaultColor), forKey: Key.defaultColor) }
    }
    public var defaultPosition: Position {
        didSet { defaults.set(defaultPosition.rawValue, forKey: Key.defaultPosition) }
    }
    public var defaultSize: Size {
        didSet { defaults.set(defaultSize.rawValue, forKey: Key.defaultSize) }
    }
    /// The age Clean Up lists by, 1 to 3650 days. A value out of range is kept in range when set.
    public var cleanUpDays: Int {
        didSet {
            let clamped = min(max(cleanUpDays, Self.cleanUpDaysRange.lowerBound), Self.cleanUpDaysRange.upperBound)
            if clamped != cleanUpDays { cleanUpDays = clamped }   // setting it here does not call didSet again
            defaults.set(clamped, forKey: Key.cleanUpDays)
        }
    }
    /// True once the welcome window was dismissed or closed (FR-017a).
    public var welcomeShown: Bool {
        didSet { defaults.set(welcomeShown, forKey: Key.welcomeShown) }
    }

    /// Reads every setting from `defaults` (the app's own domain in the app; a private suite in tests).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarMode = (defaults.string(forKey: Key.menuBarMode)).flatMap(MenuBarMode.init(rawValue:)) ?? .iconAndText
        hotkey = Self.readHotkey(defaults)
        defaultLook = Self.readLook(defaults.string(forKey: Key.defaultLook))
        defaultColor = Self.readColor(defaults.string(forKey: Key.defaultColor))
        defaultPosition = defaults.string(forKey: Key.defaultPosition).flatMap(Position.init(rawValue:)) ?? .default
        defaultSize = defaults.string(forKey: Key.defaultSize).flatMap(Size.init(rawValue:)) ?? .default
        let days = defaults.object(forKey: Key.cleanUpDays) as? Int
        cleanUpDays = days.flatMap { Self.cleanUpDaysRange.contains($0) ? $0 : nil } ?? DesktopLabeler.defaultCleanupDays
        welcomeShown = defaults.object(forKey: Key.welcomeShown) as? Bool ?? false
    }

    /// The defaults for new labels, as the core takes them.
    public var newLabelOptions: LabelOptions {
        LabelOptions(look: defaultLook, textColor: defaultColor, position: defaultPosition, size: defaultSize)
    }

    // MARK: - Reading

    private static func readHotkey(_ defaults: UserDefaults) -> Shortcut? {
        guard let code = defaults.object(forKey: Key.hotkeyKeyCode) as? Int,
              let modifiers = defaults.object(forKey: Key.hotkeyModifiers) as? Int,
              let keyCode = UInt32(exactly: code), let mask = UInt32(exactly: modifiers) else { return nil }
        let shortcut = Shortcut(keyCode: keyCode, modifiers: mask)
        return shortcut.problem == nil ? shortcut : nil
    }

    private static func readLook(_ value: String?) -> Look? {
        guard let value, value != "automatic" else { return nil }
        return Look(rawValue: value)
    }

    private static func readColor(_ value: String?) -> TextColor? {
        guard let value, value != "automatic" else { return nil }
        return try? LabelOptions.parse(style: nil, color: value, position: nil, size: nil).textColor
    }

    /// The spelling `dnm set --color` takes: `automatic`, `light`, `dark` or `#RRGGBB`.
    static func spelling(of color: TextColor?) -> String {
        switch color {
        case nil: "automatic"
        case .light?: "light"
        case .dark?: "dark"
        case let .custom(red, green, blue)?:
            String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
        }
    }
}
