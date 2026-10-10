import Foundation
import Testing

/// Spec 007: shell completions through the built binary, with a private store. The callbacks are the parser's
/// hidden `---completion` calls that the generated scripts make; nothing here changes a wallpaper.
@Suite struct CompletionTests {
    func lines(_ result: CLI.Result) -> [String] { result.output.split(separator: "\n").map(String.init) }

    func connectedDisplayNames() throws -> [String] {
        let result = try CLI.run(["displays", "--json"])
        let root = try #require(try JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any])
        return (root["displays"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func displayOffersMainTheDisplaysAndUsableAliases() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        _ = try CLI.run(["alias", "desk"], store: store)

        for command in ["set", "remove", "undo", "show"] {
            let result = try CLI.run(["---completion", command, "--", "--display", "4", "0", "dnm", command, "x", "--display", ""], store: store)
            #expect(result.status == 0 && result.errors.isEmpty, "\(command)")
            let offered = lines(result)
            #expect(offered.first == "main", "\(command)")
            for name in try connectedDisplayNames() { #expect(offered.contains(name), "\(command)") }
            #expect(offered.contains("desk"), "\(command)")
        }
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func theAliasCommandOffersDisplaysOrStoredAliasesAsAppropriate() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        _ = try CLI.run(["alias", "desk"], store: store)
        _ = try CLI.run(["alias", "other"], store: store)

        let target = try CLI.run(["---completion", "alias", "--", "positional@1", "3", "0", "dnm", "alias", "x", ""], store: store)
        #expect(target.status == 0 && target.errors.isEmpty)
        #expect(lines(target).first == "main")
        #expect(!lines(target).contains("desk"))   // a target is a display, never an alias

        let fresh = try CLI.run(["---completion", "alias", "--", "positional@0", "2", "0", "dnm", "alias", ""], store: store)
        #expect(fresh.status == 0 && fresh.output.isEmpty)   // a new name is typed freehand

        for flag in ["--remove"] {
            let removing = try CLI.run(["---completion", "alias", "--", "positional@0", "3", "0", "dnm", "alias", flag, ""], store: store)
            #expect(lines(removing) == ["desk", "other"], "\(flag)")
            let noTarget = try CLI.run(["---completion", "alias", "--", "positional@1", "4", "0", "dnm", "alias", flag, "x", ""], store: store)
            #expect(noTarget.output.isEmpty, "\(flag)")
        }
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0))
    func aCompletionNeverCreatesTheStoreOrWritesAnError() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent("dnm-completion-\(UUID().uuidString)")
        let store = parent.appendingPathComponent("s").path
        let result = try CLI.run(["---completion", "set", "--", "--display", "4", "0", "dnm", "set", "x", "--display", ""], store: store)
        #expect(result.status == 0 && result.errors.isEmpty)
        #expect(lines(result).first == "main")
        #expect(!FileManager.default.fileExists(atPath: parent.path))
    }

    @Test(.enabled(if: CLI.binary != nil))
    func aStoreTheToolCannotReadOffersNothingAndSaysNothing() throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        try FileManager.default.createDirectory(atPath: store, withIntermediateDirectories: true)
        let newer = #"{"schemaVersion": 99, "stamps": [], "changes": [], "aliases": []}"#
        try Data(newer.utf8).write(to: URL(fileURLWithPath: store + "/manifest.json"))
        let result = try CLI.run(["---completion", "set", "--", "--display", "4", "0", "dnm", "set", "x", "--display", ""], store: store)
        #expect(result.status == 0 && result.errors.isEmpty && result.output.isEmpty)
    }

    @Test(.enabled(if: CLI.binary != nil), arguments: ["zsh", "bash"])
    func theGeneratedScriptCarriesTheFixedValuesAndTheDisplayCallback(_ shell: String) throws {
        let result = try CLI.run(["--generate-completion-script", shell])
        #expect(result.status == 0 && result.errors.isEmpty)
        let script = result.output
        for value in ["plain", "halo", "frosted", "bottom-left", "bottom-right", "top-left", "top-right", "bottom", "top",
                      "small", "medium", "large", "light", "dark"] {
            #expect(script.contains(value), "\(shell): \(value)")
        }
        for command in ["set", "remove", "undo", "show", "alias", "displays", "prune", "check"] {
            #expect(script.contains(command), "\(shell): \(command)")
        }
        #expect(script.contains("---completion set -- --display"), "\(shell)")
        #expect(script.contains("---completion alias -- positional@1"), "\(shell)")
    }

    @Test(.enabled(if: CLI.binary != nil))
    func theScriptsRegisterTheBinary() throws {
        #expect(try CLI.run(["--generate-completion-script", "zsh"]).output.hasPrefix("#compdef dnm\n"))
        #expect(try CLI.run(["--generate-completion-script", "bash"]).output.contains("complete -o filenames -F _dnm dnm"))
    }

    @Test(.enabled(if: CLI.connectedDisplayCount() > 0), arguments: ["set", "remove", "undo", "show"])
    func theFirstWordOffersDisplaysAndUsableAliases(_ command: String) throws {
        let store = CLI.scratchStore()
        defer { try? FileManager.default.removeItem(atPath: store) }
        _ = try CLI.run(["alias", "desk"], store: store)
        let result = try CLI.run(["---completion", command, "--", "positional@0", "2", "0", "dnm", command, ""], store: store)
        #expect(result.status == 0 && result.errors.isEmpty, "\(command)")
        let offered = lines(result)
        #expect(offered.first == "main" && offered.contains("desk"), "\(command)")
        for name in try connectedDisplayNames() { #expect(offered.contains(name), "\(command)") }
    }

    @Test(.enabled(if: CLI.binary != nil), arguments: ["zsh", "bash"])
    func onlyTheFirstWordHasACallback(_ shell: String) throws {
        let script = try CLI.run(["--generate-completion-script", shell]).output
        for command in ["set", "remove", "undo", "show"] {
            #expect(script.contains("---completion \(command) -- positional@0"), "\(shell) \(command)")
        }
        // The label word and --label offer nothing: no callback for them.
        #expect(!script.contains("---completion set -- positional@1"), "\(shell)")
        #expect(!script.contains("---completion set -- --label"), "\(shell)")
    }
}
