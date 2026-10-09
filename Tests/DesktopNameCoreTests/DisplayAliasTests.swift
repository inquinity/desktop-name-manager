import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 006: alias names and the manifest's schema versions.
@Suite struct DisplayAliasTests {
    @Test(arguments: ["dp", "DP1", "my-desk", "work_2", "a", String(repeating: "x", count: 30), "1a", "a1"])
    func validNamesAreAccepted(_ name: String) throws {
        #expect(try DisplayAlias.validated(name) == name)
    }

    @Test(arguments: ["main", "MAIN", "Main", "1", "12", "007", "my desk", "desk$1", "a/b", "it's", "\"q\"", "a;b", "né", "", String(repeating: "x", count: 31)])
    func invalidNamesExitTwo(_ name: String) {
        do {
            _ = try DisplayAlias.validated(name)
            Issue.record("expected \(name.debugDescription) to be rejected")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
        } catch { Issue.record("wrong error") }
    }

    @Test func eachRuleHasItsOwnMessage() {
        func failure(_ name: String) -> String {
            do { _ = try DisplayAlias.validated(name) } catch { return (error as? DnmError)?.errorDescription ?? "" }
            return ""
        }
        #expect(failure("main").contains("reserved"))
        #expect(failure("12").contains("only digits"))
        #expect(failure("a b").contains("spaces or special characters"))
        #expect(failure(String(repeating: "x", count: 31)).contains("at most 30"))
    }

    @Test func aVersionOneManifestReadsWithNoAliasesAndIsSavedAsVersionTwo() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = Store(directory: root.appendingPathComponent("store", isDirectory: true))
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 1, "stamps": [], "changes": []}"#.utf8).write(to: store.manifestURL)

        let manifest = try store.readManifest()
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.aliases.isEmpty)

        try store.transaction { $0.aliases.append(DisplayAlias(name: "desk", displayUUID: "U", displayName: "Studio")) }
        let saved = try store.readManifest()
        #expect(saved.schemaVersion == 2)
        #expect(saved.aliases == [DisplayAlias(name: "desk", displayUUID: "U", displayName: "Studio")])
    }

    @Test func aVersionThreeManifestIsRefusedAndLeftAlone() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = Store(directory: root.appendingPathComponent("store", isDirectory: true))
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let original = Data(#"{"schemaVersion": 3, "stamps": [], "changes": [], "aliases": []}"#.utf8)
        try original.write(to: store.manifestURL)
        #expect(throws: DnmError.newerManifest(found: 3, supported: 2)) { try store.readManifest() }
        #expect(try Data(contentsOf: store.manifestURL) == original)
    }

    @Test func aRecordWithoutADisplayNameStillDecodes() throws {
        let json = Data(#"{"schemaVersion": 2, "stamps": [], "changes": [], "aliases": [{"name": "dp", "displayUUID": "U"}]}"#.utf8)
        let manifest = try JSONDecoder().decode(Manifest.self, from: json)
        #expect(manifest.aliases == [DisplayAlias(name: "dp", displayUUID: "U", displayName: nil)])
    }
}
