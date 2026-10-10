import ArgumentParser
import DesktopNameCore
import Foundation

struct ShowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show the label details (the current Desktop, or pick one with a display and --desktop).",
        usage: "dnm show [<display>] [options]")

    @OptionGroup var words: DisplayWords
    @OptionGroup var target: DisplayOption
    @OptionGroup var place: DesktopOption

    @Flag(name: .long, help: "Print one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let context = Context()
            let display = try context.target(command: "show", words: words, option: target)
            var result = try context.onDesktop(place, of: display) { try context.labeler.showLabel(on: display) }
            if json {
                Output.out(try Reports.json(Reports.show(result)))
                return
            }
            result.displayName = place.describe(result.displayName)
            guard let label = result.label else {
                Output.out("No label on \(result.displayName).")
                return
            }
            func note(_ option: LabelOption) -> String { label.automatic.contains(option) ? " (automatic)" : "" }
            Output.out("\(result.displayName): \"\(label.text.value)\"")
            Output.out("  style:      \(label.look.rawValue)\(note(.look))")
            Output.out("  text color: \(label.textColor)\(note(.textColor))")
            Output.out("  position:   \(label.position.rawValue)")
            Output.out("  size:       \(label.size.rawValue)")
            if let createdAt = result.createdAt {
                Output.out("  set:        \(ISO8601DateFormatter().string(from: createdAt))")
            }
            Output.out("  original recorded: \(result.originalRecorded ? "yes" : "no")")
            if result.stampMissing {
                Output.out("  The labeled image file is missing; run `dnm set` again to rebuild it.")
            }
        }
    }
}
