import ArgumentParser
import DesktopNameCore
import Foundation

/// `dnm`, also installed as `desktop-name`. Both names run this same code.
@main
struct Dnm: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dnm",
        abstract: "Label each macOS Desktop by stamping a name into its wallpaper.",
        discussion: """
        Exit codes: 0 success; 1 failure (access denied, file missing, undo not possible, …);
        2 invalid input (bad label, option or display); 3 unsupported wallpaper.
        """,
        version: DesktopNameCoreInfo.displayVersion,
        subcommands: [SetCommand.self, RemoveCommand.self, UndoCommand.self, ShowCommand.self, ListCommand.self, DisplaysCommand.self])

    /// Parsing failures exit 2 (invalid input), as documented, instead of ArgumentParser's default.
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let exit as ExitCode {
            Foundation.exit(exit.rawValue)
        } catch {
            if exitCode(for: error) == .success {
                exit(withError: error)   // --help and --version: print and exit 0
            }
            report(error)
        }
    }

    /// Prints an error and exits with its documented code.
    static func report(_ error: Error) -> Never {
        if let dnm = error as? DnmError {
            Output.err("dnm: \(dnm.errorDescription ?? "\(dnm)")")
            Foundation.exit(dnm.exitCode)
        }
        // A usage error from the parser: explain it and point to help, exit 2.
        let message = message(for: error)
        Output.err("dnm: \(message)")
        Output.err("Run `dnm --help` for usage.")
        Foundation.exit(2)
    }
}

extension ParsableCommand {
    /// Runs a command body, turning the tool's errors into their documented exit codes.
    static func guarded(_ body: () throws -> Void) throws {
        do { try body() } catch {
            if error is ExitCode { throw error }
            Dnm.report(error)
        }
    }
}
