import Foundation

/// Reads the words and flags of a command line into a display and, for `set`, a label (spec 008). The commands do no
/// matching or counting of their own: they pass what the parser gave them and use what comes back. The display is
/// resolved here, once, by `DisplayResolver`, so there is no second lookup and no second warning.
public enum DisplayArguments {
    public struct Target: Equatable, Sendable {
        public var display: Display
        /// The override warning for standard error, if an alias of the same name was overridden.
        public var notice: String?
    }

    public struct SetRequest: Equatable, Sendable {
        public var target: Target
        public var label: String
    }

    /// `remove`, `undo` and `show`: at most one display, as a word or with `--display`.
    public static func target(command: String, words: [String], displayFlags: [String],
                              in displays: [Display], aliases: [DisplayAlias]) throws -> Target {
        guard displayFlags.count <= 1 else { throw displayGivenTwice }
        switch words.count {
        case 0:
            return try resolve(displayFlags.first, in: displays, aliases: aliases)
        case 1:
            guard displayFlags.isEmpty else { throw displayGivenTwice }
            return try resolve(words[0], in: displays, aliases: aliases)
        default:
            throw DnmError.invalidInput("\(command) takes at most one display (got \(words.count) words). Quote a name with spaces, or use an alias.")
        }
    }

    /// `set [<display>] <label>` and `set [<display>] --label <text>`; the reading is the table in
    /// `specs/008-positional-display/contracts/cli.md`.
    public static func setRequest(words: [String], displayFlags: [String], labelFlags: [String],
                                  in displays: [Display], aliases: [DisplayAlias]) throws -> SetRequest {
        guard displayFlags.count <= 1 else { throw displayGivenTwice }
        guard labelFlags.count <= 1 else { throw DnmError.invalidInput("Give the label once, as a word or with --label (not both, and not --label twice).") }

        if let label = labelFlags.first {
            switch words.count {
            case 0:
                return SetRequest(target: try resolve(displayFlags.first, in: displays, aliases: aliases), label: label)
            case 1:
                guard displayFlags.isEmpty else { throw displayGivenTwice }
                let target = try resolve(words[0], in: displays, aliases: aliases,
                                         hint: "With --label, a plain word is read as the display; to give the label, use --label alone or a display and a label.")
                return SetRequest(target: target, label: label)
            default:
                throw DnmError.invalidInput("with --label, set takes at most one display (got \(words.count) words). Quote a name with spaces, or use an alias.")
            }
        }

        switch words.count {
        case 0:
            throw DnmError.invalidInput("set needs a label: dnm set [<display>] <label>.")
        case 1:
            let word = words[0]
            if displayFlags.isEmpty, DisplayResolver.isReference(word, in: displays, aliases: aliases) {
                let quoted = ShellQuoting.quote(word)
                // A word that starts with a dash is read as an option, so it is written with `=`.
                let dashed = word.hasPrefix("-")
                let labelThis = dashed ? "dnm set --display=\(quoted) \"<label>\"" : "dnm set \(quoted) \"<label>\""
                let useAsLabel = dashed ? "dnm set --label=\(quoted)" : "dnm set --label \(quoted)"
                throw DnmError.invalidInput("\"\(word)\" is a display. To label it: \(labelThis). To use \"\(word)\" as the label of the main display: \(useAsLabel).")
            }
            return SetRequest(target: try resolve(displayFlags.first, in: displays, aliases: aliases), label: word)
        case 2:
            guard displayFlags.isEmpty else { throw displayGivenTwice }
            let both = ShellQuoting.quote("\(words[0]) \(words[1])")
            let target = try resolve(words[0], in: displays, aliases: aliases,
                                     hint: "To label the main display with several words, quote the whole label: dnm set \(both).")
            return SetRequest(target: target, label: words[1])
        default:
            throw DnmError.invalidInput("set takes a label, or a display and a label (got \(words.count) words). Quote anything with spaces; an alias avoids quoting a display name: dnm alias lg \"LG Ultra\".")
        }
    }

    private static var displayGivenTwice: DnmError {
        .invalidInput("Give the display once, as a word or with --display (not both, and not --display twice).")
    }

    /// Resolves through `DisplayResolver`. A hint is added to its message only when the word is no display at all: an
    /// alias of a display that is away, say, is a display, and the hint would suggest a wrong command. A display
    /// that is given but empty is an error, not the main display (a script's empty variable must not pick one).
    private static func resolve(_ value: String?, in displays: [Display], aliases: [DisplayAlias], hint: String? = nil) throws -> Target {
        if let value, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DnmError.invalidInput("The display is empty: name a display, or leave it out for the main display.")
        }
        do {
            let resolution = try DisplayResolver.resolution(value, in: displays, aliases: aliases)
            return Target(display: resolution.display, notice: resolution.notice)
        } catch DnmError.invalidInput(let message) where hint != nil && !(value.map { DisplayResolver.isReference($0, in: displays, aliases: aliases) } ?? false) {
            throw DnmError.invalidInput("\(message) \(hint ?? "")")
        }
    }
}
