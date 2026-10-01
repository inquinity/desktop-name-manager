import ArgumentParser
import DesktopNameCore

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List labeled Desktops and the current Desktop of each display.")

    @Flag(name: .long, help: "Print one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let listing = try Context().labeler.listDesktops()
            if json {
                Output.out(try Reports.json(Reports.list(listing)))
                return
            }
            let width = listing.entries.map { $0.displayName.count + ($0.connected ? 0 : " (not connected)".count) }.max() ?? 0
            for entry in listing.entries {
                let name = entry.displayName + (entry.connected ? "" : " (not connected)")
                let marker = entry.current ? "current" : "       "
                let label = entry.label.map { "\"\($0)\"" + (entry.stampMissing ? "  (image file missing)" : "") } ?? "(no label)"
                Output.out("\(name.padding(toLength: width, withPad: " ", startingAt: 0))  \(marker)  \(label)")
            }
            Output.out("")
            Output.out(listing.scope)
        }
    }
}
