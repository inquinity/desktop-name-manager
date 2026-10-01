import ArgumentParser
import DesktopNameCore

struct DisplaysCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "displays",
        abstract: "List the connected displays by the names --display accepts.")

    @Flag(name: .long, help: "Print one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let context = Context()
            try context.labeler.cleanUp()
            let displays = try context.system.displays()
            if json {
                Output.out(try Reports.json(Reports.displays(displays)))
                return
            }
            let width = displays.map(\.name.count).max() ?? 0
            for display in displays {
                Output.out("\(display.name.padding(toLength: width, withPad: " ", startingAt: 0))\(display.isMain ? "  (main)" : "")")
            }
        }
    }
}
