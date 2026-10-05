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
        // "0.1.0" (release), "0.1.0-dev+<commit>[.dirty]" (interim) or "0.1.0-dev+unknown" (unstamped build).
        #expect(output.range(of: #"^\d+\.\d+\.\d+(-dev\+([0-9a-f]+(\.dirty)?|unknown))?$"#, options: .regularExpression) != nil, "got: \(output)")
        // Built through `just`, the stamp names the commit that was checked out when it was built.
        if let range = output.range(of: #"\+[0-9a-f]+"#, options: .regularExpression), let head = Self.headCommit() {
            let stamped = String(output[range].dropFirst())
            #expect(head.hasPrefix(stamped) || stamped.hasPrefix(head), "stamped \(stamped), HEAD \(head)")
        }
    }
}
