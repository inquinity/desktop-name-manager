import ArgumentParser
import DesktopNameCore

struct UndoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "undo",
        abstract: "Undo the last label change on a display (one level, within 60 seconds).",
        usage: "dnm undo [<display> ...] [options]",
        discussion: """
        Several displays may be named: dnm undo main DP. Each display's last change is undone; every display is checked \
        first, so if one has nothing to undo, nothing is changed.
        """)

    @OptionGroup var words: DisplayWords
    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    func run() throws {
        try Self.guarded {
            let context = Context()
            let targets = try context.targets(words: words, option: target)
            // Every display is checked before the first change. With --desktop, the checks that need Desktop N on
            // screen are made when each display is reached (spec 010 research R4).
            for display in targets.displays { try context.labeler.checkUndo(on: display, onScreen: place.desktop == nil) }
            try DisplayBatch.run(targets, undoArguments: nil) { display, changed in
                try context.onDesktop(place, of: display) {
                    var result = try context.labeler.undoLastChange(on: display)
                    changed()
                    result.displayName = place.describe(result.displayName)
                    if let label = result.restoredLabel {
                        Output.out("Restored label \"\(label.text.value)\" on \(result.displayName).")
                    } else {
                        Output.out("Restored the original wallpaper on \(result.displayName).")
                    }
                }
            }
        }
    }
}
