import ArgumentParser
import DesktopNameCore
import Foundation

struct CleanupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cleanup",
        abstract: "List, and when you agree delete, old labeled images that no Desktop is known to show.",
        discussion: """
        Finds labeled images that no display's Desktop is showing now and that were removed or replaced at least N days \
        ago, or have not been seen showing for N days (a deleted Desktop leaves such a label behind: dnm is never told). \
        It describes what it found and asks before deleting; with no terminal it only describes, unless you pass --yes. \
        A Desktop that is not on screen now might still show one of these images, and would then fall back to the \
        Mac's default wallpaper until you choose another or label it again.
        """)

    @Option(name: .long, help: ArgumentHelp("How old, in days, counted from when the label was removed or last seen.", valueName: "n"))
    var days: Int = DesktopLabeler.defaultCleanupDays

    @Flag(name: .long, help: "Delete without asking.")
    var yes = false

    @Flag(name: .long, help: "Print one JSON document instead of text (nothing is asked; add --yes to delete).")
    var json = false

    func run() throws {
        try Self.guarded {
            guard days >= 0 else { throw DnmError.invalidInput("--days takes a whole number of days, 0 or more.") }
            let labeler = Context().labeler
            let plan = try labeler.cleanupPlan(days: days)

            if json {
                let deleted = yes ? try labeler.carryOut(plan) : plan
                Output.out(try Reports.json(Reports.cleanup(yes ? deleted : plan, deleted: yes)))
                return
            }
            guard !plan.candidates.isEmpty else {
                Output.out("Nothing to clean up (no labeled image is older than \(days) day\(days == 1 ? "" : "s")).")
                return
            }
            Self.describe(plan)
            if yes {
                Self.report(try labeler.carryOut(plan))
            } else if isatty(STDIN_FILENO) != 0 {
                let size = ByteCountFormatter().string(fromByteCount: plan.totalBytes)
                FileHandle.standardOutput.write(Data("Delete these \(Self.images(plan.candidates.count)) (\(size))? [y/N] ".utf8))
                if let answer = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(), answer == "y" || answer == "yes" {
                    Self.report(try labeler.carryOut(plan))
                } else {
                    Output.out("Nothing was deleted.")
                }
            } else {
                Output.out("Nothing was deleted: add --yes to delete these.")
            }
        }
    }

    static func images(_ count: Int) -> String { "\(count) labeled image\(count == 1 ? "" : "s")" }

    /// The list, the total and the plain warning (spec 009: say plainly what might go wrong).
    static func describe(_ plan: CleanupPlan, now: Date = Date()) {
        let size = ByteCountFormatter()
        Output.out("Old labeled images that no Desktop is known to show (\(plan.days) day\(plan.days == 1 ? "" : "s")):")
        let rows = plan.candidates.map { candidate in
            (label: "\"\(candidate.label)\"", display: candidate.displayName, why: why(candidate, now: now), size: size.string(fromByteCount: candidate.bytes))
        }
        let labelWidth = rows.map(\.label.count).max() ?? 0
        let displayWidth = rows.map(\.display.count).max() ?? 0
        let whyWidth = rows.map(\.why.count).max() ?? 0
        for row in rows {
            Output.out("  " + row.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0) + " "
                + row.display.padding(toLength: displayWidth, withPad: " ", startingAt: 0) + "  "
                + row.why.padding(toLength: whyWidth, withPad: " ", startingAt: 0) + "  " + row.size)
        }
        Output.out("\(images(plan.candidates.count)), \(size.string(fromByteCount: plan.totalBytes)) in all.")
        Output.out("A Desktop that is not on screen now might still show one of these; it would fall back to the Mac's default wallpaper until you choose another or label it again.")
    }

    static func why(_ candidate: CleanupCandidate, now: Date) -> String {
        let days = max(0, Int(now.timeIntervalSince(candidate.since) / 86_400))
        let ago = days == 0 ? "today" : "\(days) day\(days == 1 ? "" : "s") ago"
        switch candidate.reason {
        case .removed, .replaced, .undone: return "\(candidate.reason.rawValue) \(ago)"
        case .notSeen: return days == 0 ? "last seen today" : "not seen for \(days) day\(days == 1 ? "" : "s")"
        }
    }

    static func report(_ deleted: CleanupPlan) {
        let size = ByteCountFormatter().string(fromByteCount: deleted.totalBytes)
        Output.out("Deleted \(images(deleted.candidates.count)), freeing \(size).")
    }
}
