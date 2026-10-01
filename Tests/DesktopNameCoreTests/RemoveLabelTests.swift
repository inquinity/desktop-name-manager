import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct RemoveLabelTests {
    @Test func restoresTheOriginalImagePlacementAndFillExactly() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let placement = WallpaperPlacement(scaling: 2, clipping: false, fillColor: Data([9, 8, 7]))
        let original = try h.showOriginal(placement: placement)
        try h.labeler.setLabel(LabelText("Email"), on: h.display)

        let result = try h.labeler.removeLabel(on: h.display)

        guard case .removed(let label) = result.outcome else { Issue.record("expected removal"); return }
        #expect(label.text.value == "Email")
        let restored = try h.system.currentWallpaper(on: h.display)
        #expect(restored.url?.resolvingSymlinksInPath() == original.resolvingSymlinksInPath())
        #expect(restored.placement == placement)
    }

    @Test func aDesktopWithNoLabelChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let result = try h.labeler.removeLabel(on: h.display)
        #expect(result.outcome == .noLabel)
        #expect(h.system.setCalls.isEmpty)
        #expect(try h.manifest().stamps.isEmpty)
    }

    @Test func theStampIsRetiredButKeptForTheCoolDown() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.removeLabel(on: h.display)

        let stamp = try #require(try h.manifest().stamps.first)
        if case .retired(_, let reason) = stamp.state { #expect(reason == .removed) } else { Issue.record("should be retired") }
        #expect(h.storeFiles == [stamp.fileName])
        let record = try #require(try h.manifest().changes.first)
        #expect(record.kind == .remove)
        #expect(record.before == .stamp(id: stamp.id))
    }

    @Test func removingTwiceSaysThereIsNoLabelTheSecondTime() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        #expect(try h.labeler.removeLabel(on: h.display).outcome == .noLabel)
    }

    @Test func aWallpaperChosenByHandIsNotRestoredToAnOutdatedOriginal() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal(name: "first.png")
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let second = try h.showOriginal(SyntheticImages.dark(), name: "second.png")
        let callsBefore = h.system.setCalls.count

        #expect(try h.labeler.removeLabel(on: h.display).outcome == .noLabel)
        #expect(h.system.setCalls.count == callsBefore)
        #expect(try h.system.currentWallpaper(on: h.display).url == second)
    }

    @Test func aMovedOriginalIsFoundThroughItsBookmark() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let moved = h.root.appendingPathComponent("moved.png")
        try FileManager.default.moveItem(at: original, to: moved)

        try h.labeler.removeLabel(on: h.display)
        #expect(try h.system.currentWallpaper(on: h.display).url?.resolvingSymlinksInPath() == moved.resolvingSymlinksInPath())
    }

    @Test func aDeletedOriginalReportsWhyAndChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let manifestBefore = try h.manifest()
        let callsBefore = h.system.setCalls.count
        try FileManager.default.removeItem(at: original)

        do {
            try h.labeler.removeLabel(on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .originalMissing = error {} else { Issue.record("wrong error: \(error)") }
            #expect(error.exitCode == 1)
            #expect((error.errorDescription ?? "").contains("System Settings"))
        }
        #expect(try h.manifest() == manifestBefore)
        #expect(h.system.setCalls.count == callsBefore)
    }

    @Test func aFailureSettingTheOriginalRestoresTheBookkeeping() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let manifestBefore = try h.manifest()
        h.system.setError = SetLabelOrderTests.Boom()
        #expect(throws: DnmError.self) { try h.labeler.removeLabel(on: h.display) }
        #expect(try h.manifest() == manifestBefore)
    }
}
