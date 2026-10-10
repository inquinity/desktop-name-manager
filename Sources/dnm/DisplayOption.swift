import ArgumentParser

/// The shared `--display` option (FR-023).
struct DisplayOption: ParsableArguments {
    @Option(name: .long, help: ArgumentHelp(
        "The display to act on: main, a display's name as macOS shows it, an alias (see `dnm alias`), or part of a name that matches one display. Default: main. See `dnm displays`.",
        valueName: "name"),
        completion: .custom { _, _, _ in Completions.displays(includeAliases: true) })
    var display: String?
}
