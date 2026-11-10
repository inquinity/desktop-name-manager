import Foundation

/// Results go to standard output; messages, warnings, notes and errors go to standard error (contracts/cli.md).
/// In quiet mode (spec 011) warnings and notes are held back; results, messages and errors never are.
enum Output {
    /// The kinds of standard-error text that quiet mode holds back.
    enum Kind {
        case warning, note
    }

    /// Quiet mode for this run. Written once, in `Dnm.main`, after parsing and before the command runs; the CLI is
    /// single-threaded, and nothing reads it before then.
    nonisolated(unsafe) static var quiet = false

    static func out(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    /// Errors and messages. Never held back.
    static func err(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    /// A warning about a condition the person may already know about (`dnm: warning: <text>`).
    static func warning(_ text: String) {
        if shouldPrint(.warning, quiet: quiet) { err("dnm: warning: \(text)") }
    }

    /// A reminder (`dnm: note: <text>`).
    static func note(_ text: String) {
        if shouldPrint(.note, quiet: quiet) { err("dnm: note: \(text)") }
    }

    /// Whether text of `kind` is printed: every kind quiet mode covers is held back in quiet mode.
    static func shouldPrint(_ kind: Kind, quiet: Bool) -> Bool {
        switch kind {
        case .warning, .note: !quiet
        }
    }
}
