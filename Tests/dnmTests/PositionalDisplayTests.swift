import Foundation
import Testing

/// Specs 008 and 010 through the built binary, with a private store. The error cases stop before anything is changed, and
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
        Mistake(["set"], "set needs a label"),
        Mistake(["set", "zz-no-such-display", "Mail", "--color", "bogus"], "Unknown color"),
        Mistake(["set", "", "Mail"], "The display is empty"),
        Mistake(["show", "--display", ""], "The display is empty"),
        Mistake(["show", "main", "main"], "show takes at most one display (got 2 words)"),
        Mistake(["remove", "main", "zz-no-such-display"], "No display matches \"zz-no-such-display\""),
        Mistake(["undo", "main", "main", "zz-no-such-display"], "No display matches \"zz-no-such-display\""),
        Mistake(["set", "main", "x", "--display", "zz-no-such-display"], "No display matches \"zz-no-such-display\""),
        Mistake(["set", "main", String(repeating: "x", count: 31), "--display", "main"], "30"),
        Mistake(["remove", "main", "--display", ""], "The display is empty"),
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
        #expect(try CLI.run(["show", "--help"]).output.contains("dnm show [<display>] [options]"))
        for command in ["remove", "undo"] {
            let help = try CLI.run([command, "--help"]).output
            let flowed = help.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            #expect(flowed.contains("dnm \(command) [<display> ...] [options]") && flowed.contains("dnm \(command) main DP"), "\(command)")
        }
        let flowed = set.output.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(flowed.contains("dnm set main \"Mail\" --display DP"))
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func theSameDisplayNamedTwiceIsAcceptedAndMeansOneDisplay() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        let plain = try CLI.run(["show", "main", "--json"], store: store)
        for arguments in [["show", "main", "--display", "main", "--json"], ["show", "--display", "main", "--display", "main", "--json"],
                          ["show", "--display", "MAIN", "--display", "main", "--json"]] {
            let result = try CLI.run(arguments, store: store)
            #expect(result.status == 0 && result.output == plain.output && result.errors.isEmpty, "\(arguments)")
        }
    }

    /// `show` stays one display (spec 010 FR-002); `set`, `remove` and `undo` with a typo among several displays change
    /// nothing (SC-002, SC-003).
    @Test(.enabled(if: CLI.connectedDisplayCount() > 1))
    func showRefusesTwoDisplaysAndATypoAmongSeveralChangesNothing() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        let other = try #require(try displayNames().first { name in
            (try? CLI.run(["show", "main", "--json"]).output.contains("\"name\" : \"\(name)\"")) == false
        })
        for arguments in [["show", "main", "--display", other], ["show", "--display", "main", "--display", other]] {
            let result = try CLI.run(arguments, store: store)
            #expect(result.status == 2 && result.output.isEmpty, "\(arguments)")
            #expect(result.errors == "dnm: Multiple displays for a single command are not currently supported.\n", "\(arguments): \(result.errors)")
        }
        for arguments in [["set", "main", "x", "--display", other, "--display", "zz-no-such-display"],
                          ["remove", "main", other, "zz-no-such-display"], ["undo", other, "main", "zz-no-such-display"],
                          ["set", "main", String(repeating: "y", count: 31), "--display", other]] {
            let result = try CLI.run(arguments, store: store)
            #expect(result.status == 2 && result.output.isEmpty, "\(arguments): \(result.errors)")
            #expect(!FileManager.default.fileExists(atPath: store + "/manifest.json"), "\(arguments)")
        }
        // Nothing to undo on either display: exit 1, nothing changed, nothing stored.
        let undo = try CLI.run(["undo", "main", other], store: store)
        #expect(undo.status == 1 && undo.output.isEmpty && undo.errors.contains("Cannot undo: there is nothing to undo on"))
        #expect(!FileManager.default.fileExists(atPath: store + "/manifest.json"))
    }
}
