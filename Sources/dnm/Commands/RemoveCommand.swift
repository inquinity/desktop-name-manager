import ArgumentParser
import DesktopNameCore

struct RemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove the label and restore the original wallpaper.")

    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    func run() throws {
        try Self.guarded {
            let context = Context()
            let display = try context.resolveDisplay(target)
            var result = try context.onDesktop(place, of: display) { try context.labeler.removeLabel(on: display) }
            result.displayName = place.describe(result.displayName)
            switch result.outcome {
            case .noLabel: Output.out("No label on \(result.displayName).")
            case .removed(let label): Output.out("Removed the label \"\(label.text.value)\" from \(result.displayName) and restored the original wallpaper.")
            }
        }
    }
}
