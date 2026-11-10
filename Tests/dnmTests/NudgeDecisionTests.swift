@testable import DesktopNameCore
import Foundation
import Testing
@testable import dnm

/// Spec 009 SC-004: when the cleanup reminder appears. Whether one is due is the store's decision (NudgeTests); this is
/// the terminal rule and which commands ask at all. `set` and `remove` cannot run here without changing a wallpaper.
@Suite struct NudgeDecisionTests {
    /// The line without its prefix: `Output.note` adds `dnm: note: `, so on screen it reads as before.
    @Test func onATerminalADueReminderIsOneLine() {
        let line = Nudge.line(standardErrorIsTerminal: true, quiet: false, due: { CleanupNudge(bytes: 60_000_000, labels: 2) })
        #expect(line == "about 60 MB (2 labels) of old labeled images could be freed: run dnm cleanup.")
    }

    @Test func nothingDueMeansNothingPrinted() {
        #expect(Nudge.line(standardErrorIsTerminal: true, quiet: false, due: { nil }) == nil)
    }

    @Test func withoutATerminalTheStoreIsNotEvenAsked() {
        var asked = false
        let line = Nudge.line(standardErrorIsTerminal: false, quiet: false, due: { asked = true; return CleanupNudge(bytes: 60_000_000, labels: 1) })
        #expect(line == nil && !asked, "a script never sees it and never moves the throttle")
    }

    /// Spec 011 FR-006, SC-005: quiet mode holds the reminder back without using it up.
    @Test func inQuietModeTheStoreIsNotEvenAsked() {
        var asked = false
        let line = Nudge.line(standardErrorIsTerminal: true, quiet: true, due: { asked = true; return CleanupNudge(bytes: 60_000_000, labels: 1) })
        #expect(line == nil && !asked, "a quiet run prints nothing and does not count as the weekly showing")
    }

    /// Only `set` and `remove` ask for the reminder (so `undo` and the read-only commands never do).
    @Test func onlySetAndRemoveAskForIt() throws {
        let commands = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../Sources/dnm/Commands").standardizedFileURL
        let callers = try FileManager.default.contentsOfDirectory(atPath: commands.path).filter { name in
            name.hasSuffix(".swift")
                && (try? String(contentsOf: commands.appendingPathComponent(name), encoding: .utf8))?.contains("Nudge.") == true
        }
        #expect(Set(callers) == ["SetCommand.swift", "RemoveCommand.swift"])
    }
}
