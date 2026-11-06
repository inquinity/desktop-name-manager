import Foundation

/// Runs one change on several displays, in order, and stops at the first failure (spec 010 FR-006, research R3).
/// Displays already changed stay changed; the error says which they are and how to put them back. There is no
/// rollback.
public enum DisplayBatch {
    /// Calls `each` for every display in `targets`, in order. `each` changes one display, prints its line, and returns
    /// true when it changed something (`remove` on a display without a label changes nothing).
    ///
    /// On an error from a later display, the error keeps its exit status and its message is followed by the displays
    /// changed before it and, when `undoArguments` is given, the `dnm undo` command that puts them back (with those
    /// arguments, `--desktop 2` say). `undo` passes nil: an undo cannot itself be undone. An error before anything
    /// changed is passed through unchanged, so one display behaves exactly as a single command (FR-009).
    public static func run(_ targets: DisplayArguments.Targets, undoArguments: [String]?,
                           _ each: (Display) throws -> Bool) throws {
        var changed: [(display: Display, reference: String)] = []
        for (display, reference) in zip(targets.displays, targets.references) {
            do {
                if try each(display) { changed.append((display, reference)) }
            } catch let error as DnmError where !changed.isEmpty {
                throw partWay(error, on: display, changed: changed, undoArguments: undoArguments)
            } catch where !changed.isEmpty {
                throw partWay(.failure(error.localizedDescription), on: display, changed: changed, undoArguments: undoArguments)
            }
        }
    }

    private static func partWay(_ error: DnmError, on display: Display, changed: [(display: Display, reference: String)],
                                undoArguments: [String]?) -> DnmError {
        let name = TerminalText.sanitized(display.name)
        var message = error.errorDescription ?? "\(error)"
        if !message.contains(display.name) { message = "On \(name): \(message)" }
        // "Nothing was changed" is true of the display that failed, not of the command.
        for phrase in ["Nothing was changed", "Nothing was labeled"] {
            message = message.replacingOccurrences(of: "\(phrase).", with: "\(phrase) on \(name).")
        }
        message += " Changed before this: \(changed.map { TerminalText.sanitized($0.display.name) }.joined(separator: ", "))."
        if let undoArguments {
            let words = changed.map { word(for: $0.reference) } + undoArguments
            message += " To put \(changed.count == 1 ? "it" : "them") back within \(Int(Housekeeping.undoWindow)) seconds: dnm undo \(words.joined(separator: " "))."
        }
        return .partWay(message, exitCode: error.exitCode)
    }

    /// A display word for a suggested command: quoted for a POSIX shell, and written `--display=` when it starts with a
    /// dash (quoting cannot stop the parser reading it as an option).
    private static func word(for reference: String) -> String {
        let quoted = ShellQuoting.quote(reference)
        return reference.hasPrefix("-") ? "--display=\(quoted)" : quoted
    }
}
