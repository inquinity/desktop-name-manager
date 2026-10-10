import Foundation
import Testing

/// Spec 008 through the built binary, with a private store. The error cases stop before anything is changed, and
/// the positive cases use `show`, which only reads; no test here changes a wallpaper.
@Suite struct PositionalDisplayTests {
    func displayNames() throws -> [String] {
        let result = try CLI.run(["displays", "--json"])
        let root = try #require(try JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any])
        return (root["displays"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
    }

    struct Mistake: Sendable, CustomTestStringConvertible {
        let arguments: [String]
        let expected: String
        init(_ arguments: [String], _ expected: String) { self.arguments = arguments; self.expected = expected }
        var testDescription: String { arguments.joined(separator: " ") }
    }

    static let mistakes: [Mistake] = [
        Mistake(["set", "a", "b", "c"], "set takes a label, or a display and a label (got 3 words)"),
        Mistake(["set", "LG", "Ultra", "label"], "Quote anything with spaces"),
        Mistake(["set", "main"], "\"main\" is a display"),
        Mistake(["set", "MAIN"], "dnm set --label MAIN"),
        Mistake(["set", "zz-no-such-display", "Inbox"], "quote the whole label"),
        Mistake(["set", "x", "--label", "y"], "With --label, a plain word is read as the display"),
        Mistake(["set", "a", "b", "--label", "y"], "with --label, set takes at most one display"),
        Mistake(["set", "--label", "a", "--label", "b"], "Give the label once"),
        Mistake(["set", "main", "x", "--display", "main"], "Give the display once"),
        Mistake(["set", "x", "--display", "main", "--display", "main"], "Give the display once"),
        Mistake(["set"], "set needs a label"),
        Mistake(["set", "zz-no-such-display", "Mail", "--color", "bogus"], "Unknown color"),
        Mistake(["set", "", "Mail"], "The display is empty"),
        Mistake(["show", "--display", ""], "The display is empty"),
        Mistake(["show", "main", "main"], "show takes at most one display (got 2 words)"),
        Mistake(["show", "main", "--display", "main"], "Give the display once"),
        Mistake(["show", "--display", "main", "--display", "main"], "Give the display once"),
        Mistake(["remove", "a", "b"], "remove takes at most one display"),
        Mistake(["undo", "a", "b", "c"], "undo takes at most one display (got 3 words)"),
    ]

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0), arguments: PositionalDisplayTests.mistakes)
    func eachMistakeExitsTwoSaysWhatToTypeAndChangesNothing(_ mistake: Mistake) throws {
        let arguments = mistake.arguments, expected = mistake.expected
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        let result = try CLI.run(arguments, store: store)
        #expect(result.status == 2, "\(arguments)")
        #expect(result.output.isEmpty, "\(arguments)")
        #expect(result.errors.hasPrefix("dnm: ") && result.errors.contains(expected), "\(arguments): \(result.errors)")
        #expect(!FileManager.default.fileExists(atPath: store + "/manifest.json"), "\(arguments)")
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func aDisplayWordGivesTheSameAnswerAsTheFlag() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        for name in ["main"] + (try displayNames()) {
            let word = try CLI.run(["show", name, "--json"], store: store)
            let flag = try CLI.run(["show", "--display", name, "--json"], store: store)
            #expect(word.status == 0 && word.output == flag.output && word.errors.isEmpty, "\(name)")
        }
        #expect(try CLI.run(["show", "--json"], store: store).output == (try CLI.run(["show", "main", "--json"], store: store).output))
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func anAliasWorksAsADisplayWord() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        _ = try CLI.run(["alias", "desk"], store: store)
        let word = try CLI.run(["show", "desk", "--json"], store: store)
        let main = try CLI.run(["show", "main", "--json"], store: store)
        #expect(word.status == 0 && word.output == main.output)
        // A lone word that is an alias is refused for `set`, with both forms.
        let refused = try CLI.run(["set", "desk"], store: store)
        #expect(refused.status == 2 && refused.errors.contains("\"desk\" is a display"))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func theHelpShowsTheRealGrammar() throws {
        let set = try CLI.run(["set", "--help"])
        #expect(set.output.contains("dnm set [<display>] <label>") && set.output.contains("dnm set [<display>] --label <text>"))
        for command in ["show", "remove", "undo"] {
            #expect(try CLI.run([command, "--help"]).output.contains("dnm \(command) [<display>]"), "\(command)")
        }
    }
}
