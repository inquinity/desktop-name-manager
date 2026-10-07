import ArgumentParser
import DesktopNameCore
import Foundation

struct AboutCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "about",
        abstract: "Show the version, license and acknowledgements, where data is kept, and what permissions the tool uses and why.")

    func run() throws {
        try Self.guarded {
            let info = About.info(dataDirectory: Store.defaultDirectory())
            Output.out(info.name)
            Output.out("Version \(info.version), \(info.license) license")
            Output.out("Source: \(info.source)")
            Output.out("Data:   \(info.dataDirectory)")
            Output.out("")
            Output.out("Permissions:")
            for line in info.permissions { Output.out("  - \(line)") }
            Output.out("")
            Output.out("Acknowledgements:")
            for component in info.acknowledgements {
                Output.out("  \(component.name) \(component.version) - \(component.license)")
                Output.out("    \(component.url)")
            }
            Output.out("Full license texts are in Licenses/.")
        }
    }
}
