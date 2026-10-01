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
