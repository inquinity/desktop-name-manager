import Foundation

/// A short name for a display, bound to the display's identity (spec 006).
public struct DisplayAlias: Codable, Equatable, Sendable {
    public static let maxLength = 30

    /// The name as last typed. Unique case-insensitively.
    public var name: String
    /// The display's UUID. Shown only when no name was recorded.
    public var displayUUID: String
    /// The display's name when the alias was set, for showing the alias while the display is not connected.
    public var displayName: String?

    public init(name: String, displayUUID: String, displayName: String?) {
        self.name = name
        self.displayUUID = displayUUID
        self.displayName = displayName
    }

    /// Checks an alias name against the rules in contracts/cli.md and returns it unchanged.
    public static func validated(_ name: String) throws -> String {
        if name.lowercased() == "main" {
            throw DnmError.invalidInput("main is reserved and cannot be used as an alias.")
        }
        if !name.isEmpty, name.allSatisfy(\.isASCIIDigit) {
            throw DnmError.invalidInput("An alias cannot be only digits, because --display does not accept numbers.")
        }
        guard name.allSatisfy({ $0.isASCIIDigit || $0.isASCIILetter || $0 == "-" || $0 == "_" }) else {
            throw DnmError.invalidInput("Alias names cannot contain spaces or special characters. Use letters, numbers, hyphens, or underscores.")
        }
        guard !name.isEmpty else { throw DnmError.invalidInput("An alias name cannot be empty.") }
        guard name.count <= maxLength else { throw DnmError.invalidInput("Alias names can be at most \(maxLength) characters.") }
        return name
    }

    func matches(_ other: String) -> Bool { name.lowercased() == other.lowercased() }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
    var isASCIILetter: Bool { ("a"..."z").contains(self) || ("A"..."Z").contains(self) }
}
