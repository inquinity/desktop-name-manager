import Foundation

/// Reads the words and flags of a command line into the displays and, for `set`, a label (specs 008 and 010). The
/// commands do no matching or counting of their own: they pass what the parser gave them and use what comes back. Each
/// display is resolved here, once, by `DisplayResolver`, so there is no second lookup and no second warning.
public enum DisplayArguments {
    /// One display, for `show`.
    public struct Target: Equatable, Sendable {
        public var display: Display
        /// The override warning for standard error, if an alias of the same name was overridden.
        public var notice: String?
    }

    /// The displays a command acts on, in order (spec 010 contract §2): the display words, in order, then each
    /// `--display` value, in order; a display named more than once, by any name, appears once, at its first place.
    public struct Targets: Equatable, Sendable {
        public var displays: [Display]
        /// For each display, the word that named it first (`main` when none was named), for the commands a message
        /// suggests: it resolved once, so it resolves again, even where two displays share a name.
        public var references: [String]
        /// The override warnings for standard error, each once, joined.
        public var notice: String?
    }

    public struct SetRequest: Equatable, Sendable {
        public var targets: Targets
        public var label: String
    }

    /// `show`: at most one display, as a word or with `--display`. Two different displays are refused.
    public static func target(command: String, words: [String], displayFlags: [String],
                              in displays: [Display], aliases: [DisplayAlias]) throws -> Target {
        guard words.count <= 1 else {
            throw DnmError.invalidInput("\(command) takes at most one display (got \(words.count) words). Quote a name with spaces, or use an alias.")
        }
        let targets = try resolve(words: words, flags: displayFlags, in: displays, aliases: aliases)
        guard targets.displays.count == 1 else {
            throw DnmError.invalidInput("Multiple displays for a single command are not currently supported.")
        }
        return Target(display: targets.displays[0], notice: targets.notice)
    }

    /// `remove` and `undo`: any number of display words and `--display` values (spec 010).
    public static func targets(words: [String], displayFlags: [String],
                               in displays: [Display], aliases: [DisplayAlias]) throws -> Targets {
        try resolve(words: words, flags: displayFlags, in: displays, aliases: aliases)
    }

    /// `set [<display>] <label>` and `set [<display>] --label <text>`; the reading is the table in
    /// `specs/008-positional-display/contracts/cli.md`.
    public static func setRequest(words: [String], displayFlags: [String], labelFlags: [String],
                                  in displays: [Display], aliases: [DisplayAlias]) throws -> SetRequest {
        guard labelFlags.count <= 1 else { throw DnmError.invalidInput("Give the label once, as a word or with --label (not both, and not --label twice).") }

        if let label = labelFlags.first {
            switch words.count {
            case 0:
                return SetRequest(targets: try resolve(words: [], flags: displayFlags, in: displays, aliases: aliases), label: label)
            case 1:
                let targets = try resolve(words: words, flags: displayFlags, in: displays, aliases: aliases,
                                          hint: "With --label, a plain word is read as the display; to give the label, use --label alone or a display and a label.")
                return SetRequest(targets: targets, label: label)
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
            return SetRequest(targets: try resolve(words: [], flags: displayFlags, in: displays, aliases: aliases), label: word)
        case 2:
            let both = ShellQuoting.quote("\(words[0]) \(words[1])")
            let targets = try resolve(words: [words[0]], flags: displayFlags, in: displays, aliases: aliases,
                                      hint: "To label the main display with several words, quote the whole label: dnm set \(both).")
            return SetRequest(targets: targets, label: words[1])
        default:
            throw DnmError.invalidInput("set takes a label, or a display and a label (got \(words.count) words). Quote anything with spaces; an alias avoids quoting a display name: dnm alias lg \"LG Ultra\".")
        }
    }

    /// The displays a person named, as words and with `--display` (any number of times), resolved through
    /// `DisplayResolver`, every one before anything changes. Naming the same display twice is one display, at its first
    /// place (a command typed and then added to should not have to be edited). The hint, when given, belongs to the
    /// words only.
    private static func resolve(words: [String], flags: [String], in displays: [Display], aliases: [DisplayAlias],
                                hint: String? = nil) throws -> Targets {
        let values = words.map { (value: $0, hint: hint) } + flags.map { (value: $0, hint: String?.none) }
        guard !values.isEmpty else {
            let main = try resolveOne(nil, in: displays, aliases: aliases)
            return Targets(displays: [main.display], references: ["main"], notice: main.notice)
        }
        var result = Targets(displays: [], references: [], notice: nil)
        var notices: [String] = []
        for (value, hint) in values {
            let target = try resolveOne(value, in: displays, aliases: aliases, hint: hint)
            if let notice = target.notice, !notices.contains(notice) { notices.append(notice) }
            guard !result.displays.contains(where: { $0.uuid == target.display.uuid }) else { continue }
            result.displays.append(target.display)
            result.references.append(value)
        }
        result.notice = notices.isEmpty ? nil : notices.joined(separator: " ")
        return result
    }

    /// Resolves one value through `DisplayResolver`. A hint is added to its message only when the word is no display at
    /// all: an alias of a display that is away, say, is a display, and the hint would suggest a wrong command. A display
    /// that is given but empty is an error, not the main display (a script's empty variable must not pick one).
    private static func resolveOne(_ value: String?, in displays: [Display], aliases: [DisplayAlias], hint: String? = nil) throws -> Target {
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
