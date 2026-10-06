import ArgumentParser

/// The shared `--desktop` option (spec 001 FR-027).
struct DesktopOption: ParsableArguments {
    @Option(name: .long, help: ArgumentHelp(
        "Act on this Desktop of the display (1 is the first, as Mission Control numbers them) instead of the one showing. The display switches there and back, which needs the Accessibility permission; see `dnm check`. Don't type while it runs. A full-screen app among the Desktops can shift the count.",
        valueName: "n"))
    var desktop: Int?

    func validate() throws {
        if let desktop, desktop < 1 { throw ValidationError("--desktop takes a Desktop number, 1 or more.") }
    }

    /// "DP" or "DP, Desktop 2", for messages.
    func describe(_ displayName: String) -> String {
        desktop.map { "\(displayName), Desktop \($0)" } ?? displayName
    }
}
