import Foundation
import Testing

/// contracts/cli.md: one JSON document on standard output and nothing else, diagnostics on standard
/// error, and the scope note always present. Read-only commands against a private store.
@Suite struct JsonContractTests {
    func document(_ result: CLI.Result) throws -> [String: Any] {
        #expect(result.status == 0, "stderr: \(result.errors)")
        let object = try JSONSerialization.jsonObject(with: Data(result.output.utf8))   // the whole stream parses as one document
        return try #require(object as? [String: Any])
    }

    @Test(.enabled(if: CLI.binary != nil))
    func listJSONIsOneDocumentWithTheScopeNote() throws {
        let result = try CLI.run(["list", "--json"])
        let root = try document(result)
        #expect(root["scope"] as? String == "Only labeled and current Desktops are shown.")
        let desktops = try #require(root["desktops"] as? [[String: Any]])
        for desktop in desktops { #expect(Set(desktop.keys) == ["display", "connected", "current", "label", "stampMissing"]) }
        #expect(result.errors.isEmpty)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func listTextEndsWithTheScopeNoteEvenWhenNothingIsOmitted() throws {
        let result = try CLI.run(["list"])
        #expect(result.status == 0)
        #expect(result.output.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("Only labeled and current Desktops are shown."))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func displaysJSONHasNamesAndTheMainFlag() throws {
        let root = try document(try CLI.run(["displays", "--json"]))
        let displays = try #require(root["displays"] as? [[String: Any]])
        for display in displays { #expect(Set(display.keys) == ["name", "isMain"]) }
        if !displays.isEmpty { #expect(displays.contains { $0["isMain"] as? Bool == true }) }
    }

    @Test(.enabled(if: CLI.binary != nil && CLI.connectedDisplayCount() > 0))
    func showJSONOnAnUnlabeledDesktopHasNullLabelAndDate() throws {
        let root = try document(try CLI.run(["show", "--json"]))
        #expect(Set(root.keys) == ["display", "labeled", "label", "createdAt", "originalRecorded", "stampMissing"])
        #expect(root["labeled"] as? Bool == false)
        #expect(root["label"] is NSNull)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func theJSONNeverContainsPathsOrIdentifiers() throws {
        let store = CLI.scratchStore()
        let text = try CLI.run(["list", "--json"], store: store).output + (try CLI.run(["displays", "--json"], store: store).output)
        #expect(!text.contains(store))
        #expect(!text.contains(NSHomeDirectory()))
        #expect(text.range(of: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}", options: .regularExpression) == nil)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func readOnlyCommandsCreateNoStoreFiles() throws {
        let store = CLI.scratchStore()
        _ = try CLI.run(["list"], store: store)
        _ = try CLI.run(["displays"], store: store)
        #expect(!FileManager.default.fileExists(atPath: store))
    }
}
