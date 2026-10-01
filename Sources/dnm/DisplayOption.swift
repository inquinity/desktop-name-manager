import ArgumentParser
import DesktopNameCore

/// The shared `--display` option (FR-023).
struct DisplayOption: ParsableArguments {
    @Option(name: .long, help: ArgumentHelp(
        "The display to act on: main, a display's name as macOS shows it, or part of a name that matches one display. Default: main. See `dnm displays`.",
        valueName: "name"))
    var display: String?
}
