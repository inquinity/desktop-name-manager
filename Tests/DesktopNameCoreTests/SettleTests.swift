import Foundation
import Testing
@testable import DesktopNameCore

/// Found in the first live run: macOS reports a newly set wallpaper a moment late, so `remove`, `undo` or
/// a second `set` run straight after `set` read the old wallpaper and misjudged the Desktop.
@Suite struct SettleTests {
    @Test func removeRightAfterSetStillSeesTheLabelWhenTheSystemIsSlowToReport() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        h.system.readsBeforeSetShows = 8
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        h.system.readsBeforeSetShows = 8
        let result = try h.labeler.removeLabel(on: h.display)
        guard case .removed = result.outcome else { Issue.record("remove must see the label just set"); return }
    }

    @Test func undoRightAfterRemoveWorksWhenTheSystemIsSlowToReport() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        h.system.readsBeforeSetShows = 8
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        try h.labeler.undoLastChange(on: h.display)
        #expect(try h.manifest().stamps.filter(\.isActive).count == 1)
    }

    @Test func aSecondSetRightAfterTheFirstReplacesInsteadOfLeavingTwoActiveLabels() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        h.system.readsBeforeSetShows = 8
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Mail"), options: LabelOptions(size: .large), on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let stamps = try h.manifest().stamps
        #expect(stamps.count == 2)
        #expect(stamps.filter(\.isActive).count == 1)
        #expect(try h.labeler.listDesktops().entries.filter { $0.label != nil }.count == 1)
    }

    @Test func aSystemThatNeverReportsTheChangeDoesNotFailTheSet() throws {
        let h = try LabelerHarness(settleTimeout: 0.2); defer { h.cleanUp() }
        h.system.readsBeforeSetShows = Int.max
        try h.showOriginal()
        let started = Date()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        #expect(Date().timeIntervalSince(started) < 5)
        #expect(try h.manifest().stamps.count == 1)
    }
}
