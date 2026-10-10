import ArgumentParser

/// The shared `--display` option (FR-023). It is an array so that a repeat is seen and refused (spec 008).
struct DisplayOption: ParsableArguments {
    @Option(name: .long, parsing: .singleValue, help: ArgumentHelp(
        "The display to act on, instead of giving it as the first word: main, a display's name as macOS shows it, an alias (see `dnm alias`), or the beginning of a name that matches one display. Default: main. See `dnm displays`.",
        valueName: "name"),
        completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var display: [String] = []
}

/// The optional display word of `remove`, `undo` and `show` (spec 008). `extra` exists so that our own message, not the
/// parser's, reports too many words.
struct DisplayWords: ParsableArguments {
    @Argument(help: ArgumentHelp("The display: main, a display's name (quote it if it has spaces), an alias, or the beginning of a name. Default: main.", valueName: "display"),
              completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var first: String?

    @Argument(help: .private)
    var extra: [String] = []

    var words: [String] { (first.map { [$0] } ?? []) + extra }
}
