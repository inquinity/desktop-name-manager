import ArgumentParser
import DesktopNameCore
import Foundation

struct PruneCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prune",
        abstract: "List, and with --yes delete, labeled images that are no longer an active label.",
        discussion: "macOS gives a new Desktop a copy of the left-most Desktop's wallpaper on that display, so a removed or replaced label can still be on another Desktop. Deleting its image would leave that Desktop without a wallpaper. Images shown on a display's current Desktop are never deleted.")

    @Flag(name: .long, help: "Delete the listed images. Without it, nothing is deleted.")
    var yes = false

    @Flag(name: .long, help: "Print one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let result = try Context().labeler.prune(confirm: yes)
            if json {
                Output.out(try Reports.json(Reports.prune(result)))
                return
            }
            guard !result.candidates.isEmpty else {
                Output.out("Nothing to prune.")
                return
            }
            let size = ByteCountFormatter()
            let age = RelativeDateTimeFormatter()
            for candidate in result.candidates {
                Output.out("  \"\(candidate.label)\" (\(candidate.reason.rawValue) \(age.localizedString(for: candidate.retiredAt, relativeTo: Date()))), \(size.string(fromByteCount: candidate.bytes))")
            }
            let total = size.string(fromByteCount: result.totalBytes)
            if result.deleted {
                Output.out("Deleted \(result.candidates.count) labeled image\(result.candidates.count == 1 ? "" : "s"), freeing \(total).")
            } else {
                Output.out("\(result.candidates.count) labeled image\(result.candidates.count == 1 ? "" : "s"), \(total) in all. Nothing was deleted.")
                Output.err("dnm: warning: a Desktop that still shows one of these (for example a Desktop macOS created with a copy of your first Desktop) would lose its wallpaper. Run `dnm prune --yes` to delete them.")
            }
        }
    }
}
