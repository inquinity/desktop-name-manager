import Foundation
import Testing

/// FR-013: `desktop-name` is the same binary under a second name and behaves identically.
@Suite struct AliasTests {
    @Test(.enabled(if: CLI.binary != nil))
    func theAliasBehavesIdentically() throws {
        let binary = try #require(CLI.binary)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("dnm-alias-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let alias = directory.appendingPathComponent("desktop-name")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: binary)

        let store = CLI.scratchStore()
        for arguments in [["--version"], ["displays"], ["list"], ["set", ""], ["set", "x", "--style", "neon"], ["--help"]] {
            let original = try CLI.run(arguments, store: store)
            let aliased = try CLI.run(arguments, executable: alias, store: store)
            #expect(aliased.status == original.status, "\(arguments)")
            #expect(aliased.output == original.output, "\(arguments)")
            #expect(aliased.errors == original.errors, "\(arguments)")
        }
    }
}
