import ArgumentParser
import DesktopNameCore

struct RemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove the label and restore the original wallpaper exactly.")

    @OptionGroup var target: DisplayOption

    func run() throws {
        try Self.guarded {
            let context = Context()
            let display = try context.resolveDisplay(target)
            let result = try context.labeler.removeLabel(on: display)
            switch result.outcome {
            case .noLabel: Output.out("No label on \(result.displayName).")
            case .removed(let label): Output.out("Removed the label \"\(label.text.value)\" from \(result.displayName) and restored the original wallpaper.")
            }
        }
    }
}
