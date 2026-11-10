import AppKit
import ArgumentParser
import DesktopNameCore
import Foundation

struct CleanupCommand: ParsableCommand, HasGlobalOptions {
    static let configuration = CommandConfiguration(
        commandName: "cleanup",
        abstract: "List, and when you agree delete, old labeled images that no Desktop is known to show.",
        discussion: """
        Finds labeled images that no display's Desktop is showing now and that were removed or replaced at least N days \
        ago, or have not been seen showing for N days (a deleted Desktop leaves such a label behind: dnm is never told). \
        It describes what it found and asks before deleting; with no terminal it only describes, unless you pass --yes. \
        A Desktop that is not on screen now (including one on a display that is not connected) might still show one of \
        these images, and would then fall back to the Mac's default wallpaper until you choose another or label it again.

        With --scan, dnm instead visits every Desktop of every connected display, as --desktop does (it needs the \
        Accessibility permission; the Desktops slide by and the pointer moves), notes which labeled image each shows, and \
        lists the labels that no Desktop shows, whatever their age. It asks before scanning and again before deleting. \
        Labels of displays that are not connected are left alone and named. Ctrl-C stops the scan, returns the display to \
        its Desktop and deletes nothing (exit 130), but only while the terminal window running dnm is in front. The scan sees the Desktops of the displays connected now; if you \
        move between display arrangements, a Desktop of another arrangement may still use a label it lists.
        """)

    @Option(name: .long, help: ArgumentHelp("How old, in days, counted from when the label was removed or last seen (default: \(DesktopLabeler.defaultCleanupDays)).", valueName: "n"))
    var days: Int?

    @Flag(name: .long, help: "Visit every Desktop of every connected display (needs Accessibility; the Desktops slide by), then list the labels that no Desktop shows and ask before deleting them.")
    var scan = false

    @Flag(name: .long, help: "Delete without asking (with --scan, also scan without asking).")
    var yes = false

    @Flag(name: .long, help: "Print one JSON document instead of text (nothing is asked; add --yes to delete, and with --scan to scan).")
    var json = false

    @OptionGroup var global: GlobalOptions

    func validate() throws {
        if scan && days != nil { throw ValidationError("--scan looks at every Desktop, so --days does not apply.") }
    }

    func run() throws {
        if scan { return try Self.guarded { try runScan() } }
        try Self.guarded {
            let days = days ?? DesktopLabeler.defaultCleanupDays
            guard days >= 0 else { throw DnmError.invalidInput("--days takes a whole number of days, 0 or more.") }
            let labeler = Context().labeler
            let plan = try labeler.cleanupPlan(days: days)

            if json {
                let result = yes ? try labeler.carryOut(plan) : plan
                Output.out(try Reports.json(Reports.cleanup(result, deleted: yes && !result.candidates.isEmpty)))
                return
            }
            guard !plan.candidates.isEmpty else {
                Output.out("Nothing to clean up (no labeled image is older than \(days) day\(days == 1 ? "" : "s")).")
                return
            }
            Self.describe(plan)
            if yes {
                Self.report(try labeler.carryOut(plan))
            } else if isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0 {   // the question must be seen
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
        let days = plan.days ?? DesktopLabeler.defaultCleanupDays
        Output.out("Old labeled images that no Desktop is known to show (\(days) day\(days == 1 ? "" : "s")):")
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
        Output.out("A Desktop that is not on screen now (including one on a display that is not connected) might still show one of these; it would fall back to the Mac's default wallpaper until you choose another or label it again.")
        Output.out("To check every Desktop of the connected displays first, run dnm cleanup --scan.")
    }

    static func why(_ candidate: CleanupCandidate, now: Date) -> String {
        let days = max(0, Int(now.timeIntervalSince(candidate.since) / 86_400))
        let ago = days == 0 ? "today" : "\(days) day\(days == 1 ? "" : "s") ago"
        switch candidate.reason {
        case .removed, .replaced, .undone: return "\(candidate.reason.rawValue) \(ago)"
        case .notSeen: return days == 0 ? "last seen today" : "not seen for \(days) day\(days == 1 ? "" : "s")"
        case .notOnAnyDesktop: return candidate.reason.rawValue
        }
    }

    static func report(_ deleted: CleanupPlan) {
        guard !deleted.candidates.isEmpty else {
            Output.out("Nothing was deleted: the labeled images changed since they were listed.")
            return
        }
        let size = ByteCountFormatter().string(fromByteCount: deleted.totalBytes)
        Output.out("Deleted \(images(deleted.candidates.count)), freeing \(size).")
    }

    // MARK: - --scan (spec 012)

    /// Follows `ScanFlow`; the text comes from `ScanText`. Nothing switches or is deleted without an answer or --yes.
    func runScan() throws {
        try MainActor.assumeIsolated {
            // The permission comes first, before anything is printed (FR-001), and never prompts.
            guard AXIsProcessTrusted() else { throw DesktopNavigator.permissionMissing(for: "cleanup --scan", to: "scan Desktops") }
            let labeler = Context().labeler
            let preview = try labeler.scanPreview()
            let terminal = isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0
            let names = preview.displays.map(\.name)
            guard preview.hasLabelsToCheck else {
                if json {
                    Output.out(try Reports.json(Reports.scan(CleanupPlan.emptyScan, scanned: [], notConnected: preview.notConnected, deleted: false, wouldScan: yes ? nil : [])))
                } else {
                    Output.out(ScanText.nothingToScan)
                    ScanText.notChecked(preview.notConnected).forEach(Output.out)
                }
                return
            }
            // screensHaveSeparateSpaces is read once the process has an application, which the switcher creates.
            let switcher = SystemDesktopSwitcher()
            defer { switcher.stop() }
            let separateSpaces = NSScreen.screensHaveSeparateSpaces

            if !json { ScanText.description(preview, separateSpaces: separateSpaces).forEach(Output.out) }
            switch ScanFlow.start(yes: yes, terminal: terminal, json: json) {
            case .describeOnly:
                if json {
                    Output.out(try Reports.json(Reports.scan(CleanupPlan.emptyScan, scanned: [], notConnected: preview.notConnected, deleted: false, wouldScan: names)))
                } else {
                    Output.out(ScanText.nothingScanned)
                }
                return
            case .askToScan:
                guard Self.ask("Scan every Desktop now? [y/N] ") else { return Output.out("Nothing was scanned.") }
            case .scan:
                break
            }

            let showProgress = !json && isatty(STDERR_FILENO) != 0
            Interrupt.install()
            let result: ScanResult
            do {
                result = try labeler.scan(switcher: switcher, separateSpaces: separateSpaces, isInterrupted: { Interrupt.isRequested }) { displays in
                    Interrupt.prepare(display: displays.map(\.name).joined(separator: ", "))
                    if showProgress { Output.err("Scanning \(displays.map(\.name).joined(separator: ", "))…") }
                }
            } catch {
                Interrupt.restore()
                throw error
            }
            // A Ctrl-C after the walk's last check, before the default handling is back, still deletes nothing.
            if Interrupt.restore() { throw DnmError.interrupted(scanned: result.scanned.map(\.name)) }

            let plan = try labeler.scanPlan(from: result)
            let scanned = result.scanned.map(\.name)
            switch ScanFlow.finish(candidates: plan.candidates.count, yes: yes, terminal: terminal, json: json) {
            case .nothingToDelete:
                try labeler.recordSeen(result)
                if json { return Output.out(try Reports.json(Reports.scan(plan, scanned: scanned, notConnected: result.notConnected, deleted: false, oneDesktop: result.oneDesktop))) }
                Output.out(ScanText.nothingToDelete)
                ScanText.notChecked(result.notConnected).forEach(Output.out)
            case .delete:
                // The list comes before the deletion (FR-005), as when asking.
                if !json { (ScanText.report(plan, notConnected: result.notConnected, now: Date()) + ScanText.oneDesktop(result.oneDesktop)).forEach(Output.out) }
                let deleted = try labeler.carryOut(plan, seen: result.seen)
                if json { return Output.out(try Reports.json(Reports.scan(deleted, scanned: scanned, notConnected: result.notConnected, deleted: !deleted.candidates.isEmpty, oneDesktop: result.oneDesktop))) }
                Output.out(ScanText.deleted(deleted))
            case .askToDelete:
                (ScanText.report(plan, notConnected: result.notConnected, now: Date()) + ScanText.oneDesktop(result.oneDesktop)).forEach(Output.out)
                if Self.ask(ScanText.question(plan)) {
                    Output.out(ScanText.deleted(try labeler.carryOut(plan, seen: result.seen)))
                } else {
                    try labeler.recordSeen(result)
                    Output.out("Nothing was deleted.")
                }
            case .keep:
                // Unreachable today: a scan without --yes needs a terminal and no --json. Kept for completeness.
                try labeler.recordSeen(result)
                if json { return Output.out(try Reports.json(Reports.scan(plan, scanned: scanned, notConnected: result.notConnected, deleted: false, oneDesktop: result.oneDesktop))) }
                (ScanText.report(plan, notConnected: result.notConnected, now: Date()) + ScanText.oneDesktop(result.oneDesktop)).forEach(Output.out)
                Output.out("Nothing was deleted: add --yes to delete these.")
            }
        }
    }

    /// Asks on the terminal; only y or yes is a yes.
    static func ask(_ question: String) -> Bool {
        // Keys typed while the Desktops slid by must not answer: drop whatever is waiting on the terminal.
        tcflush(STDIN_FILENO, TCIFLUSH)
        FileHandle.standardOutput.write(Data(question.utf8))
        return ScanFlow.isYes(readLine())
    }
}
