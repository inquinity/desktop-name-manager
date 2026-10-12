import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 009 through the built binary, against a private store crafted here. Nothing is shown from it on any display, and
/// no test changes a wallpaper.
@Suite struct CleanupCommandTests {
    struct Crafted {
        var path: String
        var removed: Stamp      // retired 40 days ago
        var unseen: Stamp       // active, last seen 40 days ago
        var recent: Stamp       // active, seen today
        var store: Store { Store(directory: URL(fileURLWithPath: path)) }
        var files: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []).filter { $0.hasSuffix(".dnm.jpg") } }
    }

    static func stamp(_ text: String, state: StampState, lastSeen: Date?, created: Date, bytes: Int, in store: Store) throws -> Stamp {
        let id = UUID()
        let label = Label(text: try LabelText(text), look: .plain, textColor: .light, position: .bottomLeft, size: .medium, automatic: [])
        let stamp = Stamp(id: id, fileName: "\(id.uuidString).dnm.jpg", label: label,
                          original: Original(path: "/tmp/original.png", bookmark: nil, scaling: 3, clipping: true, fillColor: nil),
                          displayUUID: "TEST-DISPLAY", displayName: "Test Display", pixelWidth: 800, pixelHeight: 500,
                          createdAt: created, state: state, reuseKey: nil, lastSeen: lastSeen)
        try store.writeStampFile(Data(), named: stamp.fileName)
        let handle = try FileHandle(forWritingTo: store.fileURL(named: stamp.fileName))
        try handle.truncate(atOffset: UInt64(bytes))
        try handle.close()
        return stamp
    }

    static func craft() throws -> Crafted {
        let path = CLI.scratchStore()
        let store = Store(directory: URL(fileURLWithPath: path))
        let now = Date()
        func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }
        let removed = try stamp("Mail", state: .retired(at: ago(40), reason: .removed), lastSeen: ago(41), created: ago(60), bytes: 3_000_000, in: store)
        let unseen = try stamp("Projects", state: .active, lastSeen: ago(40), created: ago(60), bytes: 2_000_000, in: store)
        let recent = try stamp("Current", state: .active, lastSeen: now, created: ago(60), bytes: 1_000_000, in: store)
        try store.transaction { $0.stamps = [removed, unseen, recent] }
        return Crafted(path: path, removed: removed, unseen: unseen, recent: recent)
    }

    func json(_ result: CLI.Result) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any])
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func withoutATerminalItDescribesAndDeletesNothing() throws {
        let c = try Self.craft(); defer { try? FileManager.default.removeItem(atPath: c.path) }
        let result = try CLI.run(["cleanup"], store: c.path)
        #expect(result.status == 0 && result.errors.isEmpty)
        for needle in ["Old labeled images that no Desktop is known to show (30 days):", "\"Mail\"", "removed 40 days ago", "\"Projects\"",
                       "not seen for 40 days", "2 labeled images, 5 MB in all.", "might still show one of these", "Nothing was deleted: add --yes"] {
            #expect(result.output.contains(needle), "\(needle)")
        }
        #expect(!result.output.contains("\"Current\""), "seen today")
        #expect(c.files.count == 3)
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func yesDeletesTheListedImagesAndTheirRecords() throws {
        let c = try Self.craft(); defer { try? FileManager.default.removeItem(atPath: c.path) }
        let result = try CLI.run(["cleanup", "--yes"], store: c.path)
        #expect(result.status == 0 && result.output.contains("Deleted 2 labeled images, freeing 5 MB."))
        #expect(c.files == [c.recent.fileName])
        #expect(try c.store.readManifest().stamps.map(\.label.text.value) == ["Current"])
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func daysWidensOrNarrowsTheList() throws {
        let c = try Self.craft(); defer { try? FileManager.default.removeItem(atPath: c.path) }
        #expect(try CLI.run(["cleanup", "--days", "90"], store: c.path).output.hasPrefix("Nothing to clean up (no labeled image is older than 90 days)."))
        let everything = try CLI.run(["cleanup", "--days", "0"], store: c.path)
        #expect(everything.output.contains("\"Current\"") && everything.output.contains("3 labeled images"), "every label no Desktop shows")
        #expect(try CLI.run(["cleanup", "--days", "1"], store: c.path).output.contains("Old labeled images that no Desktop is known to show (1 day):"))
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func theJSONDocumentListsCandidatesAndDeletesOnlyWithYes() throws {
        let c = try Self.craft(); defer { try? FileManager.default.removeItem(atPath: c.path) }
        let listing = try json(try CLI.run(["cleanup", "--json"], store: c.path))
        #expect(Set(listing.keys) == ["days", "candidates", "totalBytes", "deleted"])
        #expect(listing["deleted"] as? Bool == false && listing["days"] as? Int == 30 && listing["totalBytes"] as? Int == 5_000_000)
        let entries = try #require(listing["candidates"] as? [[String: Any]])
        #expect(entries.map { $0["why"] as? String } == ["removed", "not seen"] || entries.map { $0["why"] as? String } == ["not seen", "removed"])
        #expect(Set(try #require(entries.first).keys) == ["label", "display", "why", "since", "bytes"])
        #expect(c.files.count == 3)
        let deleted = try json(try CLI.run(["cleanup", "--json", "--yes"], store: c.path))
        #expect(deleted["deleted"] as? Bool == true)
        #expect(c.files.count == 1)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func nothingStoredMeansNothingToCleanUp() throws {
        let store = CLI.scratchStore()
        let result = try CLI.run(["cleanup"], store: store)
        #expect(result.status == 0 && result.output == "Nothing to clean up (no labeled image is older than 30 days).\n")
        #expect(!FileManager.default.fileExists(atPath: store))
    }

    @Test(.enabled(if: CLI.binary != nil), arguments: [["cleanup", "--days", "-1"], ["cleanup", "--days", "soon"], ["cleanup", "--days=-3"], ["cleanup", "extra"]])
    func badInputExitsTwoAndChangesNothing(_ arguments: [String]) throws {
        let store = CLI.scratchStore()
        let result = try CLI.run(arguments, store: store)
        #expect(result.status == 2 && result.output.isEmpty && result.errors.hasPrefix("dnm: "), "\(arguments): \(result.errors)")
        #expect(!FileManager.default.fileExists(atPath: store))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func pruneIsGoneAndSaysWhatReplacedIt() throws {
        for arguments in [["prune"], ["prune", "--yes"], ["prune", "--json"]] {
            let result = try CLI.run(arguments)
            #expect(result.status == 2 && result.output.isEmpty, "\(arguments)")
            #expect(result.errors == "dnm: prune was replaced by cleanup: run dnm cleanup (see dnm cleanup --help).\n", "\(arguments)")
        }
        #expect(!(try CLI.run(["--help"]).output.contains("prune")))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func theHelpDescribesTheCommand() throws {
        let help = try CLI.run(["cleanup", "--help"])
        #expect(help.status == 0)
        // The help wraps its lines, so compare with the whitespace collapsed.
        let text = help.output.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for needle in ["--days <n>", "--yes", "--json", "might still show one of these images", "(default: 30)"] { #expect(text.contains(needle), "\(needle)") }
        #expect(try CLI.run(["--help"]).output.contains("cleanup"))
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func theNudgeNeverAppearsWhenStandardErrorIsNotATerminal() throws {
        let c = try Self.craft(); defer { try? FileManager.default.removeItem(atPath: c.path) }
        // Make the store big enough to be due, then run commands that would nudge on a terminal (the ones that only read).
        let big = try Self.stamp("Huge", state: .active, lastSeen: Date().addingTimeInterval(-90 * 86_400), created: Date().addingTimeInterval(-90 * 86_400), bytes: 80_000_000, in: c.store)
        try c.store.transaction { $0.stamps.append(big) }
        for arguments in [["show", "main"], ["list"], ["check"], ["displays"]] {
            let result = try CLI.run(arguments, store: c.path)
            #expect(!result.errors.contains("could be freed"), "\(arguments)")
        }
        #expect(try c.store.readManifest().maintenance == nil, "nothing was recorded")
    }
}
