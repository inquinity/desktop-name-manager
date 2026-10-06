import ArgumentParser
import DesktopNameCore
import Foundation

struct AboutCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "about",
        abstract: "Show the version, where data is kept, and what permissions the tool uses and why.")

    @Flag(name: .long, help: "Print one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let info = About.info(dataDirectory: Store.defaultDirectory())
            if json {
                Output.out(try Reports.json(info))
                return
            }
            Output.out(info.name)
            Output.out("Version \(info.version), \(info.license) license")
            Output.out("Source: \(info.source)")
            Output.out("Data:   \(info.dataDirectory)")
            Output.out("")
            Output.out("Permissions:")
            for line in info.permissions { Output.out("  - \(line)") }
        }
    }
}
