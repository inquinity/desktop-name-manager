import Foundation

/// The hotkey: one key with modifiers (spec 014, FR-014, research R3). The key code is the virtual key code and the
/// modifiers are the Carbon mask `RegisterEventHotKey` takes, as stored in the settings (contracts/app-settings.md).
public struct Shortcut: Equatable, Hashable, Sendable {
    /// Carbon modifier bits (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`), spelled out so this library needs no
    /// Carbon import.
    public enum Modifier {
        public static let command: UInt32 = 1 << 8
        public static let shift: UInt32 = 1 << 9
        public static let option: UInt32 = 1 << 11
        public static let control: UInt32 = 1 << 12
        static let all = command | shift | option | control
    }

    /// Virtual key codes with no printable character, named as the menus show them.
    static let namedKeys: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]
    /// The letters, digits and punctuation of the US layout, by virtual key code. The display string uses them so it
    /// does not depend on the current keyboard layout's API.
    static let characters: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M",
        45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`",
    ]
    /// Keys refused on their own, whatever the modifiers: Escape, Return, Tab and Space (data-model.md AppSettings).
    static let refusedKeys: Set<UInt32> = [53, 36, 48, 49]

    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers & Modifier.all
    }

    /// Why this shortcut cannot be used, or nil. It needs at least two of ⌃⌥⌘, or ⌘ with ⇧; Escape, Return, Tab and
    /// Space are refused.
    public var problem: String? {
        if Self.refusedKeys.contains(keyCode) { return "Escape, Return, Tab and Space cannot be used. Choose another key." }
        let held = [Modifier.control, Modifier.option, Modifier.command].filter { modifiers & $0 != 0 }.count
        let commandShift = modifiers & Modifier.command != 0 && modifiers & Modifier.shift != 0
        guard held >= 2 || commandShift else { return "Use at least two of ⌃ ⌥ ⌘, or ⌘ with ⇧." }
        return nil
    }

    /// As the menus show it, for example "⌃⌥⌘L".
    public var displayString: String {
        var text = ""
        if modifiers & Modifier.control != 0 { text += "⌃" }
        if modifiers & Modifier.option != 0 { text += "⌥" }
        if modifiers & Modifier.shift != 0 { text += "⇧" }
        if modifiers & Modifier.command != 0 { text += "⌘" }
        return text + (Self.characters[keyCode] ?? Self.namedKeys[keyCode] ?? "Key \(keyCode)")
    }
}
