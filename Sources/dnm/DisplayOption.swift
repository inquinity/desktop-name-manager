import ArgumentParser

/// The shared `--display` option (FR-023). It is an array so that a repeat is seen and refused (spec 008).
struct DisplayOption: ParsableArguments {
    @Option(name: .long, parsing: .singleValue, help: ArgumentHelp(
        "A display to act on (repeat it for several; `show` takes one), instead of or after the display words: main, a display's name as macOS shows it, an alias (see `dnm alias`), or the beginning of a name that matches one display. Default: main. See `dnm displays`.",
        valueName: "name"),
        completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var display: [String] = []
}

/// The display words of `remove` and `undo` (spec 010): any number, each completed with displays and aliases.
struct DisplayWords: ParsableArguments {
    @Argument(help: ArgumentHelp("The displays: main, a display's name (quote it if it has spaces), an alias, or the beginning of a name. Several may be named. Default: main.", valueName: "display"),
              completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var words: [String] = []
}

/// The optional display word of `show` (spec 008), which acts on one display. `extra` exists so that our own message,
/// not the parser's, reports too many words.
struct ShowWords: ParsableArguments {
    @Argument(help: ArgumentHelp("The display: main, a display's name (quote it if it has spaces), an alias, or the beginning of a name. Default: main.", valueName: "display"),
              completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var first: String?

    @Argument(help: .private)
    var extra: [String] = []

    var words: [String] { (first.map { [$0] } ?? []) + extra }
}
