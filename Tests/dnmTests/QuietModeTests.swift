import ArgumentParser
import Foundation
import Testing
@testable import dnm

/// Spec 011: quiet mode (`-q`, `--quiet`, `DNM_QUIET=1`) holds back warnings and notes and nothing else.
@Suite struct QuietModeTests {
    // MARK: - Parsing (FR-001)

    func parsedQuiet(_ arguments: [String]) throws -> Bool {
        let command = try Dnm.parseAsRoot(arguments)
        return try #require(command as? HasGlobalOptions, "\(type(of: command)) has no global options").global.quiet
    }

    @Test(arguments: [["-q", "set", "x"], ["set", "-q", "x"], ["set", "x", "-q"], ["-q", "set", "-q", "x"],
                      ["--quiet", "show"], ["show", "--quiet"], ["-q", "list", "--json"], ["-q"]])
    func quietIsReadBeforeOrAfterTheCommandName(_ arguments: [String]) throws {
        #expect(try parsedQuiet(arguments), "\(arguments)")
    }

    @Test(arguments: [["set", "x"], ["show"], ["list"], []])
    func withoutTheFlagQuietIsOff(_ arguments: [String]) throws {
        #expect(try !parsedQuiet(arguments), "\(arguments)")
    }

    /// Every command accepts it, so it can be set once for everything.
    @Test(arguments: [["set", "x"], ["remove"], ["undo"], ["show"], ["list"], ["displays"], ["alias"], ["cleanup"],
                      ["about"], ["check"]])
    func everyCommandAcceptsIt(_ arguments: [String]) throws {
        #expect(try parsedQuiet(arguments + ["-q"]), "\(arguments)")
        #expect(try parsedQuiet(["-q"] + arguments), "\(arguments)")
    }

    /// `prune` only says what replaced it: it takes every word after it, `-q` included, and `dnm -q prune` is read by
    /// `dnm` itself, so both still reach its message (checked through the binary in `errorsAreUnchanged`).
    @Test func pruneTakesItWithoutAnOptionGroup() throws {
        #expect(try Dnm.parseAsRoot(["prune", "-q"]) is PruneCommand)
        #expect(try Dnm.parseAsRoot(["-q", "prune"]) is PruneCommand)
    }

    /// A label that is literally `-q` stays a label when it is written as one.
    @Test func aLabelSpelledLikeTheFlagStaysALabel() throws {
        let afterDashes = try #require(try Dnm.parseAsRoot(["set", "--", "-q"]) as? SetCommand)
        #expect(afterDashes.first == "-q" && !afterDashes.global.quiet)
        let named = try #require(try Dnm.parseAsRoot(["set", "--label=-q"]) as? SetCommand)
        #expect(named.labelFlag == ["-q"] && !named.global.quiet)
    }

    // MARK: - The environment (FR-002)

    @Test(arguments: [
        (nil, false, false), ("", false, false), ("0", false, false), ("true", false, false), ("yes", false, false),
        (" 1", false, false), ("1", false, true),
        (nil, true, true), ("0", true, true), ("1", true, true),
    ] as [(String?, Bool, Bool)])
    func onlyExactlyOneTurnsItOn(value: String?, flag: Bool, expected: Bool) {
        let environment = value.map { ["DNM_QUIET": $0] } ?? [:]
        #expect(GlobalOptions.quiet(flag: flag, environment: environment) == expected, "DNM_QUIET=\(value ?? "unset"), flag \(flag)")
    }

    // MARK: - The gate (FR-003, FR-004)

    @Test(arguments: [Output.Kind.warning, .note])
    func warningsAndNotesAreHeldBackOnlyWhenQuiet(kind: Output.Kind) {
        #expect(Output.shouldPrint(kind, quiet: false))
        #expect(!Output.shouldPrint(kind, quiet: true))
    }

    /// Every warning and note goes through the gate: none is written as an error, which quiet mode never holds back,
    /// and nothing but `Output` writes to standard error at all. (A line scan: a call split across lines, or a prefix
    /// built elsewhere, would still need review; the second check keeps any such writer inside `Output.swift`.)
    @Test func noWarningOrNoteIsWrittenAsAnError() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/dnm").standardizedFileURL
        let files = try #require(FileManager.default.enumerator(atPath: sources.path)).compactMap { $0 as? String }
            .filter { $0.hasSuffix(".swift") }
        #expect(files.count >= 10)
        for file in files {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n") where line.contains("Output.err(") {
                #expect(!line.contains("warning:") && !line.contains("note:"), "\(file): \(line)")
            }
            if file != "Output.swift" {
                for writer in ["FileHandle.standardError", "fileDescriptor: 2", "write(STDERR_FILENO", "write(2,", "fputs(", "stderr"] {
                    #expect(!text.contains(writer), "\(file) writes to standard error without Output (\(writer))")
                }
            }
        }
    }

    // MARK: - Through the binary

    /// The main display's name, read at run time (never written into the repository).
    static let mainDisplayName: String? = {
        guard CLI.binary != nil, let result = try? CLI.run(["displays", "--json"]), result.status == 0,
              let root = try? JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any],
              let displays = root["displays"] as? [[String: Any]] else { return nil }
        return displays.first { $0["isMain"] as? Bool == true }?["name"] as? String
    }()

    /// A scratch store holding an alias named like the connected main display, bound to a made-up display. `dnm alias`
    /// refuses that name while the display is connected, but loading does not re-check it: this is how an alias ends up
    /// overridden when a display with its name is connected later.
    static func storeWithOverriddenAlias(_ name: String) throws -> String {
        let store = CLI.scratchStore()
        try FileManager.default.createDirectory(atPath: store, withIntermediateDirectories: true)
        let alias: [String: Any] = ["name": name, "displayUUID": "ELSEWHERE", "displayName": "Elsewhere"]
        let manifest: [String: Any] = ["schemaVersion": 3, "stamps": [], "changes": [], "aliases": [alias]]
        try JSONSerialization.data(withJSONObject: manifest).write(to: URL(fileURLWithPath: store).appendingPathComponent("manifest.json"))
        return store
    }

    /// SC-001, User Story 1: the override warning without quiet mode, nothing on standard error with it, and the
    /// same standard output and exit status either way.
    @Test(.enabled(if: mainDisplayName != nil))
    func quietModeHidesTheOverrideWarningAndNothingElse() throws {
        let name = try #require(Self.mainDisplayName)
        let store = try Self.storeWithOverriddenAlias(name)
        defer { try? FileManager.default.removeItem(atPath: store) }

        let plain = try CLI.run(["show", name], store: store)
        #expect(plain.errors.contains("dnm: warning: "), "the override warning is printed without quiet mode")
        let quietRuns = [
            try CLI.run(["show", name, "-q"], store: store),
            try CLI.run(["show", name, "--quiet"], store: store),
            try CLI.run(["-q", "show", name], store: store),
            try CLI.run(["show", name], store: store, extraEnvironment: ["DNM_QUIET": "1"]),
            try CLI.run(["show", name, "-q"], store: store, extraEnvironment: ["DNM_QUIET": "1"]),
        ]
        for run in quietRuns {
            #expect(run.errors.isEmpty)
            #expect(run.output == plain.output && run.status == plain.status)
        }
        let notQuiet = try CLI.run(["show", name], store: store, extraEnvironment: ["DNM_QUIET": "0"])
        #expect(notQuiet.errors == plain.errors, "DNM_QUIET=0 does not turn quiet mode on")

        let json = try CLI.run(["show", name, "--json"], store: store)
        let quietJSON = try CLI.run(["show", name, "--json", "-q"], store: store)
        #expect(quietJSON.output == json.output && quietJSON.errors.isEmpty)
    }

    /// FR-007, clarification Q1: `dnm alias` keeps its marker and drops the separate warning line.
    @Test(.enabled(if: mainDisplayName != nil))
    func aliasKeepsItsMarkerAndDropsTheWarningLine() throws {
        let name = try #require(Self.mainDisplayName)
        let store = try Self.storeWithOverriddenAlias(name)
        defer { try? FileManager.default.removeItem(atPath: store) }

        let plain = try CLI.run(["alias"], store: store)
        let quiet = try CLI.run(["alias", "-q"], store: store)
        #expect(plain.output.contains("(overridden by connected display"))
        #expect(plain.errors.contains("dnm: warning: alias "))
        #expect(quiet.output == plain.output && quiet.errors.isEmpty && quiet.status == plain.status)
    }

    /// SC-002, FR-004: errors and usage errors are the same with and without quiet mode.
    @Test(.enabled(if: CLI.connectedDisplayCount() > 0), arguments: [
        ["show", "NoSuchDisplay"], ["set"], ["set", String(repeating: "x", count: 31)], ["prune"],
        ["cleanup", "--days", "-1"], ["undo", "--desktop", "0"],
    ])
    func errorsAreUnchanged(_ arguments: [String]) throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        let plain = try CLI.run(arguments, store: store)
        #expect(plain.status != 0, "\(arguments) is an error case")
        for quiet in [arguments + ["-q"], ["-q"] + arguments] {
            let run = try CLI.run(quiet, store: store)
            #expect(run.errors == plain.errors && run.status == plain.status && run.output == plain.output, "\(quiet)")
        }
    }

    /// SC-003: standard output of the read-only commands is the same, byte for byte, with and without quiet mode.
    /// The store is empty, so nothing is held back here: this shows `-q` leaves results alone. Output with a warning
    /// held back is compared for `show` and `alias` above, and for `set`, `remove` and `undo` by the live script.
    @Test(.enabled(if: CLI.connectedDisplayCount() > 0), arguments: [
        ["list"], ["list", "--json"], ["displays"], ["displays", "--json"], ["show"], ["show", "--json"],
        ["check"], ["check", "--json"], ["about"], ["alias"], ["alias", "--json"],
    ])
    func readOnlyOutputIsUnchanged(_ arguments: [String]) throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        let plain = try CLI.run(arguments, store: store)
        let quiet = try CLI.run(arguments + ["-q"], store: store)
        #expect(quiet.output == plain.output && quiet.status == plain.status, "\(arguments)")
    }

    // MARK: - Help (FR-008)

    @Test(.enabled(if: CLI.binary != nil), arguments: [
        [], ["set"], ["remove"], ["undo"], ["show"], ["list"], ["displays"], ["alias"], ["cleanup"], ["about"], ["check"],
    ])
    func everyHelpScreenListsIt(_ command: [String]) throws {
        let help = try CLI.run(command + ["--help"]).output
        let flattened = help.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(flattened.contains("-q, --quiet Hide warnings and notes; results and errors are always shown. DNM_QUIET=1 does the same."),
                "\(command)")
    }
}
