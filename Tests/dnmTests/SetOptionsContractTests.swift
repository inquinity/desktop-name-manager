import Foundation
import Testing

/// contracts/cli.md: option values, validation, and exit codes. Every case here fails during
/// validation, before the tool touches any wallpaper.
@Suite struct SetOptionsContractTests {
    @Test(.enabled(if: CLI.binary != nil), arguments: [
        ["set", ""],
        ["set", "   "],
        ["set", "Mail\nBox"],
        ["set", String(repeating: "a", count: 31)],
        ["set", "x", "--style", "neon"],
        ["set", "x", "--color", "red"],
        ["set", "x", "--color", "#12345"],
        ["set", "x", "--position", "middle"],
        ["set", "x", "--size", "huge"],
        ["set", "x", "--display", "no-such-display-anywhere"],
        ["set", "x", "--display", "1"],
        ["set"],
        ["set", "x", "--bogus"],
        ["frobnicate"],
        ["set", "x", "--desktop", "0"],
        ["set", "x", "--desktop", "two"],
        ["remove", "--desktop", "0"],
        ["undo", "--desktop", "0"],
        ["show", "--desktop", "0"],
        // The display is checked before any switching, so a bad name fails without the permission.
        ["set", "x", "--display", "no-such-display-anywhere", "--desktop", "2"],
    ])
    func invalidInputExitsTwoWithAMessageOnStandardError(_ arguments: [String]) throws {
        let result = try CLI.run(arguments)
        #expect(result.status == 2, "\(arguments): exit \(result.status), stderr: \(result.errors)")
        #expect(result.output.isEmpty)
        #expect(!result.errors.isEmpty)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func theErrorNamesTheAcceptedValues() throws {
        let style = try CLI.run(["set", "x", "--style", "neon"])
        #expect(style.errors.contains("plain, halo, frosted"))
        let position = try CLI.run(["set", "x", "--position", "middle"])
        #expect(position.errors.contains("bottom-left"))
        let color = try CLI.run(["set", "x", "--color", "red"])
        #expect(color.errors.contains("#RRGGBB"))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func helpAndVersionExitZeroOnStandardOutput() throws {
        let help = try CLI.run(["set", "--help"])
        #expect(help.status == 0)
        for option in ["--display", "--style", "--color", "--position", "--size"] { #expect(help.output.contains(option)) }
        let version = try CLI.run(["--version"])
        #expect(version.status == 0)
        #expect(!version.output.isEmpty)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func desktopZeroSaysWhatItTakes() throws {
        let result = try CLI.run(["set", "x", "--desktop", "0"])
        #expect(result.errors.contains("--desktop takes a Desktop number, 1 or more."))
    }

    @Test(.enabled(if: CLI.binary != nil), arguments: ["set", "remove", "undo", "show"])
    func desktopIsOfferedWhereADesktopIsTargeted(_ command: String) throws {
        let help = try CLI.run([command, "--help"])
        #expect(help.output.contains("--desktop <n>"))
        #expect(help.output.contains("Accessibility"))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func setHelpMentionsTheFullScreenEdgeCase() throws {
        #expect(try CLI.run(["set", "--help"]).output.contains("full-screen"))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func aboutStatesThePermissions() throws {
        let about = try CLI.run(["about"])
        #expect(about.status == 0)
        #expect(about.output.contains("Accessibility is used only by --desktop"))
        #expect(about.output.contains("Acknowledgements:"))
        #expect(about.output.contains("swift-argument-parser 1.8.2 - Apache License 2.0 with Runtime Library Exception"))
        #expect(about.output.contains("Full license texts are in Licenses/."))
        // about has no JSON form (maintainer decision 2026-10-07).
        #expect(try CLI.run(["about", "--json"]).status == 2)
    }

    @Test(.enabled(if: CLI.binary != nil))
    func checkReportsAndChangesNothing() throws {
        let store = CLI.scratchStore()
        let check = try CLI.run(["check"], store: store)
        #expect(check.status == 0)
        #expect(check.output.contains("Space shortcuts"))
        let json = try CLI.run(["check", "--json"], store: store)
        let root = try #require(try JSONSerialization.jsonObject(with: Data(json.output.utf8)) as? [String: Any])
        #expect((root["items"] as? [[String: Any]])?.count == 6)
        #expect(!FileManager.default.fileExists(atPath: store))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func rootHelpDocumentsTheExitCodes() throws {
        let help = try CLI.run(["--help"])
        #expect(help.output.contains("Exit codes"))
        #expect(help.output.contains("unsupported wallpaper"))
    }
}

/// A build says which commit it came from, so a tester knows what they are running.
@Suite struct VersionStampTests {
    static func headCommit() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "rev-parse", "--short", "HEAD"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        let commit = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return commit.isEmpty ? nil : commit
    }

    @Test(.enabled(if: CLI.binary != nil))
    func versionIsPlainOrNamesTheCommit() throws {
        let output = try CLI.run(["--version"]).output.trimmingCharacters(in: .whitespacesAndNewlines)
        // "0.1.0 (1)" (release), "0.1.0 (1) <commit>[+]" (any other build), or the unstamped notice.
        #expect(output.range(of: #"^(\d+\.\d+\.\d+ \(\d+\)( [0-9a-f]+\+?)?|unknown version \(built without a build stamp\))$"#,
                             options: .regularExpression) != nil, "got: \(output)")
        // Built through `just`, the stamp names the commit that was checked out when it was built.
        if let range = output.range(of: #"\) [0-9a-f]+"#, options: .regularExpression), let head = Self.headCommit() {
            let stamped = String(output[range].dropFirst(2))
            #expect(head.hasPrefix(stamped) || stamped.hasPrefix(head), "stamped \(stamped), HEAD \(head)")
        }
    }
}
