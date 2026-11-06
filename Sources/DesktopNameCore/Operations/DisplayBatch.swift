import Foundation

/// Runs one change on several displays, in order, and stops at the first failure (spec 010 FR-006, research R3).
/// Displays already changed stay changed; the error says which they are and how to put them back. There is no
/// rollback.
public enum DisplayBatch {
    /// Calls `each` for every display in `targets`, in order. `each` changes one display, prints its line, and calls
    /// `changed` as soon as the display's change is made (`remove` on a display without a label makes none). A display
    /// that fails after its change was made (with `--desktop`, a step back to its Desktop that macOS did not confirm,
    /// say) is counted as changed.
    ///
    /// When several displays were named and at least one was changed, the error keeps its exit status and its message
    /// is followed by the displays changed and, when `undoArguments` is given, the `dnm undo` command that puts them
    /// back (with those arguments, `--desktop 2` say). `undo` passes nil: an undo cannot itself be undone. Otherwise the
    /// error is passed through unchanged, so one display behaves exactly as a single command (FR-009).
    public static func run(_ targets: DisplayArguments.Targets, undoArguments: [String]?,
                           _ each: (_ display: Display, _ changed: () -> Void) throws -> Void) throws {
        var changed: [(display: Display, reference: String)] = []
        for (display, reference) in zip(targets.displays, targets.references) {
            var changedHere = false
            do {
                try each(display) { changedHere = true }
                if changedHere { changed.append((display, reference)) }
            } catch {
                let failedAfterChange = changedHere
                if failedAfterChange { changed.append((display, reference)) }
                guard targets.displays.count > 1, !changed.isEmpty else { throw error }
                let dnmError = error as? DnmError ?? .failure(error.localizedDescription)
                throw partWay(dnmError, on: display, changed: changed, includingFailed: failedAfterChange,
                              undoArguments: undoArguments)
            }
        }
    }

    private static func partWay(_ error: DnmError, on display: Display, changed: [(display: Display, reference: String)],
                                includingFailed: Bool, undoArguments: [String]?) -> DnmError {
        let name = TerminalText.sanitized(display.name)
        var message = error.errorDescription ?? "\(error)"
        if !names(message, name) { message = "On \(name): \(message)" }
        // "Nothing was changed" is true of the display that failed, not of the command.
        for phrase in ["Nothing was changed", "Nothing was labeled"] {
            message = message.replacingOccurrences(of: "\(phrase).", with: "\(phrase) on \(name).")
        }
        let names = changed.map { TerminalText.sanitized($0.display.name) }.joined(separator: ", ")
        message += includingFailed ? " Changed: \(names)." : " Changed before this: \(names)."
        if let undoArguments {
            let words = changed.map { word(for: $0.reference, of: $0.display) } + undoArguments
            message += " To put \(changed.count == 1 ? "it" : "them") back within \(Int(Housekeeping.undoWindow)) seconds: dnm undo \(words.joined(separator: " "))."
        }
        return .partWay(message, exitCode: error.exitCode)
    }

    /// True when `message` names the display as a whole word: "DP" is not named by a message about "DP2".
    private static func names(_ message: String, _ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        var searchRange = message.startIndex..<message.endIndex
        while let found = message.range(of: name, range: searchRange) {
            let before = found.lowerBound == message.startIndex ? nil : message[message.index(before: found.lowerBound)]
            let after = found.upperBound == message.endIndex ? nil : message[found.upperBound]
            let isWordCharacter = { (character: Character?) in character.map { $0.isLetter || $0.isNumber } ?? false }
            if !isWordCharacter(before) && !isWordCharacter(after) { return true }
            searchRange = found.upperBound..<message.endIndex
        }
        return false
    }

    /// A display word for a suggested command: the word that named the display, or, when that word has a character a
    /// terminal could act on, the display's own (already sanitized) name. Quoted for a POSIX shell, and written
    /// `--display=` when it starts with a dash (quoting cannot stop the parser reading it as an option).
    private static func word(for reference: String, of display: Display) -> String {
        let safe = reference.unicodeScalars.contains(where: TerminalText.isUnsafe) ? display.name : reference
        let quoted = ShellQuoting.quote(safe)
        return safe.hasPrefix("-") ? "--display=\(quoted)" : quoted
    }
}
