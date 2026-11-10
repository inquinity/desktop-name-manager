import ArgumentParser
import DesktopNameCore

struct RemoveCommand: ParsableCommand, HasGlobalOptions {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove the label and restore the original wallpaper.",
        usage: "dnm remove [<display> ...] [options]",
        discussion: """
        Several displays may be named: dnm remove main DP. They are changed in order; if one fails, the command stops \
        and says which were already changed and how to undo them.
        """)

    @OptionGroup var words: DisplayWords
    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    @OptionGroup var global: GlobalOptions

    func run() throws {
        try Self.guarded {
            let context = Context()
            let targets = try context.targets(words: words, option: target)
            try DisplayBatch.run(targets, undoArguments: context.undoArguments(place)) { display, changed in
                try context.onDesktop(place, of: display) {
                    var result = try context.labeler.removeLabel(on: display)
                    result.displayName = place.describe(result.displayName)
                    switch result.outcome {
                    case .noLabel:
                        Output.out("No label on \(result.displayName).")
                    case .removed(let label):
                        changed()
                        Output.out("Removed the label \"\(label.text.value)\" from \(result.displayName) and restored the original wallpaper.")
                    }
                }
            }
            Nudge.showIfDue(context)
        }
    }
}
