import ArgumentParser
import Foundation

/// Options every command accepts, before or after the command's name (spec 011). The root command and each
/// subcommand include this group; the parser merges the values, so `dnm -q set …` and `dnm set … -q` mean the same.
struct GlobalOptions: ParsableArguments {
    @Flag(name: .shortAndLong, help: "Hide warnings and notes; results and errors are always shown. DNM_QUIET=1 does the same.")
    var quiet = false

    /// Quiet mode for this run: the flag, or `DNM_QUIET` set to exactly `1` (any other value leaves it off, silently).
    static func quiet(flag: Bool, environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        flag || environment["DNM_QUIET"] == "1"
    }
}

/// A command that includes `GlobalOptions`, so `Dnm.main` can read them from whichever command was parsed.
protocol HasGlobalOptions {
    var global: GlobalOptions { get }
}
