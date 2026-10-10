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
            let aliases = try context.labeler.aliases()
            let report = Reports.displays(displays, aliases: aliases)
            if json {
                Output.out(try Reports.json(report))
                return
            }
            let width = report.displays.map(\.name.count).max() ?? 0
            for display in report.displays {
                let name = display.name.padding(toLength: width, withPad: " ", startingAt: 0)
                let names = display.aliases
                if names.isEmpty {
                    Output.out("\(name)\(display.isMain ? "  (main)" : "")")
                } else {
                    Output.out("\(name)\(display.isMain ? "  (main)" : "        ")  aliases: \(names.joined(separator: ", "))")
                }
            }
        }
    }
}
