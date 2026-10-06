import ArgumentParser
import DesktopNameCore

struct UndoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "undo",
        abstract: "Undo the last label change on a display (one level, within 30 minutes).")

    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    func run() throws {
        try Self.guarded {
            let context = Context()
            let display = try context.resolveDisplay(target)
            var result = try context.onDesktop(place, of: display) { try context.labeler.undoLastChange(on: display) }
            result.displayName = place.describe(result.displayName)
            let change = switch result.undone { case .set: "set"; case .replace: "replaced"; case .remove: "removed" }
            let when = "\(change) \(result.minutesAgo) minute\(result.minutesAgo == 1 ? "" : "s") ago"
            if let label = result.restoredLabel {
                Output.out("Restored label \"\(label.text.value)\" on \(result.displayName) (\(when)).")
            } else {
                Output.out("Restored the original wallpaper on \(result.displayName) (label \(when)).")
            }
        }
    }
}
