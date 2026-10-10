import ArgumentParser
import DesktopNameCore

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set the Desktop label (the current Desktop, or pick one with a display and --desktop).",
        usage: "dnm set [<display>] <label> [options]\n       dnm set [<display>] --label <text> [options]",
        discussion: """
        A label is one line of 1 to 30 characters. Options you leave out use their defaults; they never inherit from a label being replaced.

        With two words, the first is the display and the second the label: dnm set DP1 "Mail". With one word it is the label \
        for the main display, unless it is the name of a display or an alias (then it is refused: say which you mean). \
        Quote anything with spaces; an alias avoids quoting a display name. --label names the label outright.
        """)

    @Argument(help: ArgumentHelp("The display, or, when it is the only word, the label.", valueName: "display"),
              completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var first: String?

    @Argument(help: ArgumentHelp("The label: one line, 1 to 30 characters (emoji count as one).", valueName: "label"))
    var second: String?

    @Argument(help: .private)
    var extra: [String] = []

    @Option(name: .customLong("label"), parsing: .singleValue, help: ArgumentHelp("The label, named outright (a label that starts with a dash is written --label=-x). Any word given is then the display.", valueName: "text"))
    var labelFlag: [String] = []

    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    @Option(name: .long, help: "plain, halo or frosted. Default: chosen from the wallpaper.", completion: Completions.values(of: Look.self))
    var style: String?

    @Option(name: .long, help: "light, dark or #RRGGBB. Default: chosen from the wallpaper.", completion: .list(["light", "dark"]))
    var color: String?

    @Option(name: .long, help: "bottom-left (default), bottom-right, top-left, top-right, bottom or top.", completion: Completions.values(of: Position.self))
    var position: String?

    @Option(name: .long, help: "small, medium (default) or large.", completion: Completions.values(of: Size.self))
    var size: String?

    func run() throws {
        try Self.guarded {
            let options = try LabelOptions.parse(style: style, color: color, position: position, size: size)
            let context = Context()
            let request = try context.setRequest(words: (first.map { [$0] } ?? []) + (second.map { [$0] } ?? []) + extra,
                                                 option: target, labelFlags: labelFlag)
            let text = try LabelText(request.label)
            context.warn(request.target)
            let display = request.target.display
            var result = try context.onDesktop(place, of: display) { try context.labeler.setLabel(text, options: options, on: display) }
            result.displayName = place.describe(result.displayName)
            Output.out(result.confirmation)
        }
    }
}
