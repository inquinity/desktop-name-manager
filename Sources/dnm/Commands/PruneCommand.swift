import ArgumentParser
import Foundation

/// `prune` became `cleanup` in 0.2.1 (spec 009). It stays only to say so, so that a script that uses it fails loudly with
/// the way forward instead of with a parser error.
struct PruneCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "prune", abstract: "Replaced by cleanup.", shouldDisplay: false)

    @Argument(parsing: .captureForPassthrough, help: .private)
    var arguments: [String] = []

    func run() throws {
        Output.err("dnm: prune was replaced by cleanup: run dnm cleanup (see dnm cleanup --help).")
        throw ExitCode(2)
    }
}
