import Foundation
import Testing

/// Spec 006: `dnm alias` through the built binary, with a private store. Only the store changes; the aliases
/// point at the main display, and only read-only commands (`show`, `displays`) use them.
@Suite struct AliasCommandTests {
    func json(_ result: CLI.Result) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any])
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func aliasingTheMainDisplayListsShowsAndRemoves() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }

        let empty = try CLI.run(["alias"], store: store)
        #expect(empty.status == 0 && empty.output.hasPrefix("No aliases."))
        #expect(!FileManager.default.fileExists(atPath: store))   // listing creates nothing

        let set = try CLI.run(["alias", "desk"], store: store)
        #expect(set.status == 0)
        #expect(set.output.hasPrefix("Aliased desk to ") && set.output.contains("(main)."))

        let again = try CLI.run(["alias", "Desk"], store: store)
        #expect(again.status == 0 && again.output.hasPrefix("Aliased Desk to "))

        let list = try CLI.run(["alias"], store: store)
        #expect(list.status == 0 && list.output.hasPrefix("Desk ") && list.output.contains("(main)"))

        let report = try json(try CLI.run(["alias", "--json"], store: store))
        let aliases = try #require(report["aliases"] as? [[String: Any]])
        #expect(aliases.count == 1 && aliases[0]["name"] as? String == "Desk" && aliases[0]["isMain"] as? Bool == true)

        let show = try CLI.run(["show", "--display", "DESK", "--json"], store: store)
        #expect(show.status == 0 && show.errors.isEmpty)

        let displays = try json(try CLI.run(["displays", "--json"], store: store))
        let listed = try #require(displays["displays"] as? [[String: Any]])
        #expect(listed.contains { ($0["aliases"] as? [String]) == ["Desk"] })

        let text = try CLI.run(["displays"], store: store)
        #expect(text.output.contains("aliases: Desk"))

        let check = try CLI.run(["check"], store: store)
        #expect(check.output.contains("Aliases") && check.output.contains("1 alias."))

        let manifest = try String(contentsOfFile: store + "/manifest.json", encoding: .utf8)
        #expect(manifest.contains("\"schemaVersion\" : 2"))

        let removed = try CLI.run(["alias", "--remove", "desk"], store: store)
        #expect(removed.status == 0 && removed.output == "Removed alias Desk.\n")
        #expect(try CLI.run(["alias"], store: store).output.hasPrefix("No aliases."))
    }

    @Test(.enabled(if: CLI.binary != nil), arguments: [
        ["alias", "main"], ["alias", "MAIN"], ["alias", "12"], ["alias", "my desk"], ["alias", "desk$1"],
        ["alias", String(repeating: "x", count: 31)], ["alias", "--remove", "nope"], ["alias", "--remove"],
        ["alias", "--remove", "a", "main"], ["alias", "--json", "desk"], ["alias", "desk", "no-such-display-anywhere"],
    ])
    func invalidInputExitsTwoAndStoresNothing(_ arguments: [String]) throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        let result = try CLI.run(arguments, store: store)
        #expect(result.status == 2, "\(arguments)")
        #expect(result.errors.hasPrefix("dnm: "), "\(arguments)")
        #expect(result.output.isEmpty, "\(arguments)")
        #expect(!FileManager.default.fileExists(atPath: store + "/manifest.json"))
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func anAliasForADisplayThatIsNotConnectedSaysSo() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        try FileManager.default.createDirectory(atPath: store, withIntermediateDirectories: true)
        let record = #"{"schemaVersion": 2, "stamps": [], "changes": [], "aliases": [{"name": "old", "displayUUID": "GONE", "displayName": "Studio Display"}]}"#
        try Data(record.utf8).write(to: URL(fileURLWithPath: store + "/manifest.json"))

        let list = try CLI.run(["alias"], store: store)
        #expect(list.output.contains("old") && list.output.contains("Studio Display") && list.output.contains("(not connected)"))
        let used = try CLI.run(["show", "--display", "old"], store: store)
        #expect(used.status == 2 && used.errors == "dnm: The display aliased as old is not connected.\n")
    }

    @Test(.enabled(if: CLI.binary != nil))
    func theAliasHelpDescribesTheModes() throws {
        let help = try CLI.run(["alias", "--help"])
        #expect(help.status == 0)
        #expect(help.output.contains("--remove") && help.output.contains("--json"))
        #expect(try CLI.run(["show", "--help"]).output.contains("an alias"))
    }
}
