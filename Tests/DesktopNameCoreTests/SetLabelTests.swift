import Foundation
import ImageIO
import Testing
@testable import DesktopNameCore

@Suite struct SetLabelTests {
    @Test func labelsOnlyTheTargetDisplay() throws {
        let other = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other]); defer { h.cleanUp() }
        let originalA = try h.showOriginal(name: "a.png")
        let originalB = try SyntheticImages.write(SyntheticImages.dark(), to: h.root.appendingPathComponent("b.png"))
        h.system.show(originalB, on: other)

        try h.labeler.setLabel(LabelText("Email"), on: h.display)

        // A first label re-applies the current wallpaper (see KI-1), then sets the stamp: both on the target display.
        #expect(h.system.setCalls.count == 2)
        #expect(h.system.setCalls.allSatisfy { $0.displayUUID == "DISPLAY-A" })
        #expect(try h.system.currentWallpaper(on: other).url == originalB)
        #expect(try SyntheticImages.pixelSize(of: originalA) == (800, 500))   // original untouched
    }

    @Test func writesAStampNamedLikeOurFilesAndSetsItScaledToFill() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let result = try h.labeler.setLabel(LabelText("Email"), on: h.display)

        let stamp = try #require(try h.manifest().stamps.first)
        #expect(Cleanup.isOurFileName(stamp.fileName))
        #expect(stamp.fileName.hasSuffix(".dnm.jpg"))
        #expect(stamp.isActive)
        #expect(stamp.pixelWidth == 800 && stamp.pixelHeight == 500)
        #expect(try SyntheticImages.pixelSize(of: h.store.fileURL(named: stamp.fileName)) == (800, 500))
        #expect(h.system.setCalls.last?.url.lastPathComponent == stamp.fileName)
        #expect(h.system.setCalls.last?.placement.scaling == 3)   // scale proportionally up or down (fill)
        #expect(result.label.text.value == "Email")
        #expect(!result.replaced)
        #expect(result.displayName == "Built-in Display")
    }

    @Test func recordsTheOriginalOnTheFirstLabel() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let placement = WallpaperPlacement(scaling: 2, clipping: false, fillColor: Data([1, 2, 3]))
        let url = try h.showOriginal(placement: placement)
        try h.labeler.setLabel(LabelText("Email"), on: h.display)

        let original = try #require(try h.manifest().stamps.first).original
        #expect(URL(fileURLWithPath: original.path).resolvingSymlinksInPath() == url.resolvingSymlinksInPath())
        #expect(original.scaling == 2 && original.clipping == false && original.fillColor == Data([1, 2, 3]))
        #expect(original.bookmark != nil)
    }

    @Test func replacementKeepsTheOriginalAndRetiresTheOldStamp() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let first = try #require(try h.manifest().stamps.first)

        let result = try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        #expect(result.replaced)

        let stamps = try h.manifest().stamps
        #expect(stamps.count == 2)
        let old = try #require(stamps.first { $0.id == first.id }), new = try #require(stamps.first { $0.id != first.id })
        #expect(new.original == first.original)
        #expect(new.isActive)
        if case .retired(_, let reason) = old.state { #expect(reason == .replaced) } else { Issue.record("old stamp should be retired") }
        #expect(old.supersededBy == new.id)
        #expect(h.storeFiles.count == 2)   // the old stamp stays for the cool-down
    }

    @Test func replacementDoesNotInheritOptionsFromTheOldLabel() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), options: LabelOptions(look: .halo, textColor: .dark, position: .topRight, size: .large), on: h.display)
        let result = try h.labeler.setLabel(LabelText("Mail"), on: h.display)

        #expect(result.label.position == .bottomLeft)
        #expect(result.label.size == .medium)
        #expect(result.label.automatic.isSuperset(of: [.look, .textColor]))
    }

    @Test func everySetUsesANewRandomFileName() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Same"), on: h.display)
        try h.labeler.setLabel(LabelText("Same"), on: h.display)
        let names = try h.manifest().stamps.map(\.fileName)
        #expect(Set(names).count == 2)
    }

    @Test func changeRecordPointsAtWhatTheSetProduced() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let manifest = try h.manifest()
        let record = try #require(manifest.changes.first)
        #expect(record.kind == .set)
        #expect(record.displayUUID == "DISPLAY-A")
        #expect(record.produced == .stamp(id: manifest.stamps[0].id))
        #expect(record.before == .original(manifest.stamps[0].original))
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        #expect(try h.manifest().changes.count == 1)   // one record per display
        #expect(try h.manifest().changes[0].kind == .replace)
    }

    @Test func aFileMadeByThisToolButUnknownToTheStoreIsNeverUsedAsAnOriginal() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        // A stamp from another store (another build, or a lost manifest) is showing on the Desktop.
        let stray = try SyntheticImages.write(SyntheticImages.dark(), to: h.root.appendingPathComponent("\(UUID().uuidString).dnm.png"))
        h.system.show(stray, on: h.display)
        do {
            try h.labeler.setLabel(LabelText("Email"), on: h.display)
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            #expect((error.errorDescription ?? "").contains("not in this store"))
        }
        #expect(h.system.setCalls.isEmpty)
        #expect(try h.manifest().stamps.isEmpty)
    }

    @Test func theConfirmationLineNamesTheSize() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let large = try h.labeler.setLabel(LabelText("Mail"), options: LabelOptions(look: .halo, textColor: .light, size: .large), on: h.display)
        #expect(large.confirmation == "Labeled \"Mail\" on Built-in Display (halo, light text, bottom-left, large).")
        let medium = try h.labeler.setLabel(LabelText("Mail"), options: LabelOptions(look: .halo, textColor: .light), on: h.display)
        #expect(medium.confirmation.hasSuffix("bottom-left, medium)."))
    }
}
