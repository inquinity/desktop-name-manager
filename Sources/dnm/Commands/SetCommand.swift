import ArgumentParser
import DesktopNameCore

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set the Desktop label (the current Desktop, or pick one with --display and --desktop).",
        discussion: "A label is one line of 1 to 30 characters. Options you leave out use their defaults; they never inherit from a label being replaced.")

    @Argument(help: "The label: one line, 1 to 30 characters (emoji count as one).")
    var label: String

    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    @Option(name: .long, help: "plain, halo or frosted. Default: chosen from the wallpaper.")
    var style: String?

    @Option(name: .long, help: "light, dark or #RRGGBB. Default: chosen from the wallpaper.")
    var color: String?

    @Option(name: .long, help: "bottom-left (default), bottom-right, top-left, top-right, bottom or top.")
    var position: String?

    @Option(name: .long, help: "small, medium (default) or large.")
    var size: String?

    func run() throws {
        try Self.guarded {
            let text = try LabelText(label)
            let options = try LabelOptions.parse(style: style, color: color, position: position, size: size)
            let context = Context()
            let display = try context.resolveDisplay(target)
            var result = try context.onDesktop(place, of: display) { try context.labeler.setLabel(text, options: options, on: display) }
            result.displayName = place.describe(result.displayName)
            Output.out(result.confirmation)
            if place.desktop == 1 {
                Output.err("dnm: note: macOS gives every new Desktop on \(display.name) a copy of Desktop 1's wallpaper, so new Desktops there will show this label too. Run `dnm remove` on such a Desktop, or keep Desktop 1 unlabeled.")
            }
        }
    }
}
