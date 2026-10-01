import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct UndoLabelTests {
    func currentName(_ h: LabelerHarness) throws -> String? {
        try h.system.currentWallpaper(on: h.display).url?.lastPathComponent
    }

    @Test func undoAfterRemoveBringsTheLabelBack() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let stamp = try #require(try h.manifest().stamps.first)
        try h.labeler.removeLabel(on: h.display)
        h.clock.advance(minutes: 4)

        let result = try h.labeler.undoLastChange(on: h.display)

        #expect(result.undone == .remove)
        #expect(result.restoredLabel?.text.value == "Email")
        #expect(result.minutesAgo == 4)
        #expect(try currentName(h) == stamp.fileName)
        #expect(try h.manifest().stamps.first?.isActive == true)
    }

    @Test func undoAfterAReplacementBringsThePreviousLabelBack() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let stamps = try h.manifest().stamps
        let first = stamps[0], second = stamps[1]

        let result = try h.labeler.undoLastChange(on: h.display)

        #expect(result.undone == .replace)
        #expect(result.restoredLabel?.text.value == "Email")
        #expect(try currentName(h) == first.fileName)
        let after = try h.manifest().stamps
        #expect(after.first { $0.id == first.id }?.isActive == true)
        if case .retired(_, let reason)? = after.first(where: { $0.id == second.id })?.state { #expect(reason == .undone) } else { Issue.record("second stamp should be retired") }
    }

    @Test func undoAfterTheFirstSetRestoresTheOriginal() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let placement = WallpaperPlacement(scaling: 2, clipping: false, fillColor: Data([5]))
        let original = try h.showOriginal(placement: placement)
        try h.labeler.setLabel(LabelText("Email"), on: h.display)

        let result = try h.labeler.undoLastChange(on: h.display)

        #expect(result.undone == .set)
        #expect(result.restoredLabel == nil)
        let now = try h.system.currentWallpaper(on: h.display)
        #expect(now.url?.resolvingSymlinksInPath() == original.resolvingSymlinksInPath())
        #expect(now.placement == placement)
    }

    @Test func aSecondUndoHasNothingToUndo() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        try h.labeler.undoLastChange(on: h.display)
        do {
            try h.labeler.undoLastChange(on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .cannotUndo = error {} else { Issue.record("wrong error: \(error)") }
            #expect(error.exitCode == 1)
        }
    }

    @Test func undoWorksUpToTheCoolDownAndNotAfter() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        h.clock.advance(minutes: 29)
        try h.labeler.undoLastChange(on: h.display)

        try h.labeler.removeLabel(on: h.display)
        h.clock.advance(minutes: 31)
        let callsBefore = h.system.setCalls.count
        #expect(throws: DnmError.self) { try h.labeler.undoLastChange(on: h.display) }
        #expect(h.system.setCalls.count == callsBefore)
    }

    @Test func undoRefusesWhenTheWallpaperChangedSince() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.showOriginal(SyntheticImages.dark(), name: "other.png")   // the user picks another picture
        let callsBefore = h.system.setCalls.count
        do {
            try h.labeler.undoLastChange(on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("changed"))
        }
        #expect(h.system.setCalls.count == callsBefore)
    }

    @Test func undoRefusesWhenThePreviousImageIsGone() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let first = try #require(try h.manifest().stamps.first)
        h.store.removeFile(named: first.fileName)
        let before = try h.manifest()
        #expect(throws: DnmError.self) { try h.labeler.undoLastChange(on: h.display) }
        #expect(try h.manifest() == before)
    }

    @Test func undoRefusesWhenTheOriginalIsGone() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try FileManager.default.removeItem(at: original)
        #expect(throws: DnmError.self) { try h.labeler.undoLastChange(on: h.display) }
    }

    @Test func undoOnADisplayWithNoChangesSaysSo() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        #expect(throws: DnmError.self) { try h.labeler.undoLastChange(on: h.display) }
    }

    @Test func eachDisplayHasItsOwnUndo() throws {
        let other = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other]); defer { h.cleanUp() }
        try h.showOriginal()
        let second = try SyntheticImages.write(SyntheticImages.dark(), to: h.root.appendingPathComponent("b.png"))
        h.system.show(second, on: other)
        try h.labeler.setLabel(LabelText("One"), on: h.display)
        try h.labeler.setLabel(LabelText("Two"), on: other)

        try h.labeler.undoLastChange(on: h.display)
        #expect(try h.manifest().changes.count == 1)   // the other display's record survives
        try h.labeler.undoLastChange(on: other)
        #expect(try h.system.currentWallpaper(on: other).url?.resolvingSymlinksInPath() == second.resolvingSymlinksInPath())
    }
}
