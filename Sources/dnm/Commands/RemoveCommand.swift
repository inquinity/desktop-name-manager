import ArgumentParser
import DesktopNameCore

struct RemoveCommand: ParsableCommand {
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

    func run() throws {
        try Self.guarded {
            let context = Context()
            let targets = try context.targets(words: words, option: target)
            try DisplayBatch.run(targets, undoArguments: context.undoArguments(place)) { display in
                var result = try context.onDesktop(place, of: display) { try context.labeler.removeLabel(on: display) }
                result.displayName = place.describe(result.displayName)
                switch result.outcome {
                case .noLabel:
                    Output.out("No label on \(result.displayName).")
                    return false
                case .removed(let label):
                    Output.out("Removed the label \"\(label.text.value)\" from \(result.displayName) and restored the original wallpaper.")
                    return true
                }
            }
            Nudge.showIfDue(context)
        }
    }
}
