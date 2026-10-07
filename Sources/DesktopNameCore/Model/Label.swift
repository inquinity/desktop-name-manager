import Foundation

/// How the label is backed so it stays legible.
public enum Look: String, Codable, CaseIterable, Sendable {
    case plain, halo, frosted
}

/// Where the label sits on the screen.
public enum Position: String, Codable, CaseIterable, Sendable {
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottom, top

    public static let `default`: Position = .bottomLeft
}

/// Relative size of the label.
public enum Size: String, Codable, CaseIterable, Sendable {
    case small, medium, large

    public static let `default`: Size = .medium
}

/// Text color: light or dark chosen from the backdrop, or an explicit sRGB color.
public enum TextColor: Codable, Equatable, Sendable {
    case light
    case dark
    case custom(red: Double, green: Double, blue: Double)
}

/// The properties of a label that can be chosen automatically.
public enum LabelOption: String, Codable, CaseIterable, Sendable {
    case look, textColor, position, size
}

/// Characters that must not reach a terminal as they are.
public enum TerminalText {
    /// Control characters (C0, DEL and C1) and the bidirectional formatting characters. Emoji joiners, variation
    /// selectors and tag characters (used in flag emoji) are allowed.
    public static func isUnsafe(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.generalCategory == .control { return true }
        switch scalar.value {
        case 0x061C, 0x200E, 0x200F, 0x202A...0x202E, 0x2066...0x2069: return true
        default: return false
        }
    }

    /// Text from outside (such as a display's name) with unsafe characters replaced by U+FFFD.
    public static func sanitized(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { isUnsafe($0) ? "\u{FFFD}" : $0 }))
    }
}

/// A label's text. One line, 1 to 30 characters after trimming; each emoji counts as one; no line breaks.
public struct LabelText: Codable, Hashable, Sendable {
    public static let maxLength = 30
    public let value: String

    public init(_ raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DnmError.invalidInput("A label needs at least one visible character.")
        }
        guard !trimmed.contains(where: \.isNewline) else {
            throw DnmError.invalidInput("A label must be a single line (no line breaks).")
        }
        // Labels are printed to the terminal: escape sequences could retitle it, write the clipboard or fake
        // output, and direction overrides could make the text read differently from what is stored.
        guard !trimmed.unicodeScalars.contains(where: TerminalText.isUnsafe) else {
            throw DnmError.invalidInput("A label cannot contain control characters (such as escape, tab or text-direction marks).")
        }
        // Character counts extended grapheme clusters, so each emoji counts as one.
        guard trimmed.count <= Self.maxLength else {
            throw DnmError.invalidInput("A label can have at most \(Self.maxLength) characters; this one has \(trimmed.count).")
        }
        value = trimmed
    }

    public init(from decoder: Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// The user's explicit choices; anything left `nil` is automatic or the default.
public struct LabelOptions: Equatable, Sendable {
    public var look: Look?
    public var textColor: TextColor?
    public var position: Position?
    public var size: Size?

    public init(look: Look? = nil, textColor: TextColor? = nil, position: Position? = nil, size: Size? = nil) {
        self.look = look
        self.textColor = textColor
        self.position = position
        self.size = size
    }
}

/// A finished label: the text and the look it was rendered with.
public struct Label: Codable, Equatable, Sendable {
    public var text: LabelText
    public var look: Look
    public var textColor: TextColor
    public var position: Position
    public var size: Size
    /// Which of look, text color, position and size the tool chose rather than the user.
    public var automatic: Set<LabelOption>

    public init(text: LabelText, look: Look, textColor: TextColor, position: Position, size: Size, automatic: Set<LabelOption>) {
        self.text = text
        self.look = look
        self.textColor = textColor
        self.position = position
        self.size = size
        self.automatic = automatic
    }
}
