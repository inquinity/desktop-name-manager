import ArgumentParser
import DesktopNameCore
import Foundation

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Report display, label and setup information; check for issues.",
        discussion: "Changes nothing and never asks for a permission.")

    @Flag(name: .long, help: "Print one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let configuration = MainActor.assumeIsolated { Configuration.current() }
            let report = Context().labeler.check(configuration)
            if json {
                Output.out(try Reports.json(report))
                return
            }
            let width = report.items.map(\.name.count).max() ?? 0
            for item in report.items {
                let mark = switch item.state {
                case .ok: "ok  "
                case .attention: "fix "
                case .unknown: "?   "
                case .info: "    "
                }
                Output.out("\(mark)\(item.name.padding(toLength: width, withPad: " ", startingAt: 0))  \(item.detail)")
                if let fix = item.fix { Output.out("    \(String(repeating: " ", count: width))  \(fix)") }
            }
        }
    }
}
