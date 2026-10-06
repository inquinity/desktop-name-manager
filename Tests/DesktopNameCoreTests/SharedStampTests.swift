import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 001 amendment (2026-10-05): macOS gives every new Desktop a copy of the first Desktop's wallpaper, so one
/// labeled image can be on several Desktops. Two displays showing the same stamp file model two such Desktops.
@Suite struct SharedStampTests {
    /// Labels the first display, then makes the second show the same labeled image, as macOS does for a new Desktop.
    func sharedLabel() throws -> (LabelerHarness, Display, Stamp) {
        let other = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other])
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Test"), on: h.display)
        let stamp = try #require(try h.manifest().stamps.first)
        let shown = try h.system.currentWallpaper(on: h.display)
        h.system.show(shown.url, placement: shown.placement, on: other)
        return (h, other, stamp)
    }

    @Test func removingOnACopyLeavesTheOriginalDesktopLabeled() throws {
        let (h, copy, stamp) = try sharedLabel(); defer { h.cleanUp() }

        guard case .removed = try h.labeler.removeLabel(on: copy).outcome else { Issue.record("expected a removal"); return }

        // The copy is back to the original; the first Desktop still shows the label, and dnm still knows it.
        #expect(try h.system.currentWallpaper(on: copy).url?.lastPathComponent != stamp.fileName)
        #expect(try h.system.currentWallpaper(on: h.display).url?.lastPathComponent == stamp.fileName)
        #expect(h.store.stampFileExists(named: stamp.fileName))
        #expect(try h.labeler.showLabel(on: h.display).label?.text.value == "Test")
    }

    @Test func theOtherDesktopCanStillBeUnlabeledAfterwards() throws {
        let (h, copy, stamp) = try sharedLabel(); defer { h.cleanUp() }
        try h.labeler.removeLabel(on: copy)

        // This was the "No label" error seen live.
        guard case .removed(let label) = try h.labeler.removeLabel(on: h.display).outcome else {
            Issue.record("the first Desktop's label must still be recognized"); return
        }
        #expect(label.text.value == "Test")
        #expect(try h.system.currentWallpaper(on: h.display).url?.lastPathComponent != stamp.fileName)
    }

    @Test func relabelingACopyGivesItItsOwnImageAndLeavesTheOtherAlone() throws {
        let (h, copy, stamp) = try sharedLabel(); defer { h.cleanUp() }

        let result = try h.labeler.setLabel(LabelText("Mine"), on: copy)

        #expect(result.replaced)
        let copyFile = try #require(try h.system.currentWallpaper(on: copy).url?.lastPathComponent)
        #expect(copyFile != stamp.fileName)
        #expect(try h.system.currentWallpaper(on: h.display).url?.lastPathComponent == stamp.fileName)
        #expect(h.store.stampFileExists(named: stamp.fileName))
        #expect(try h.labeler.showLabel(on: h.display).label?.text.value == "Test")
        #expect(try h.labeler.showLabel(on: copy).label?.text.value == "Mine")
        // The new label is rendered from the shared label's recorded original, not from the labeled image.
        let mine = try #require(try h.manifest().stamps.first { $0.fileName == copyFile })
        #expect(mine.original == stamp.original)
    }

    @Test func undoOnTheCopyBringsTheSharedLabelBack() throws {
        let (h, copy, stamp) = try sharedLabel(); defer { h.cleanUp() }
        try h.labeler.removeLabel(on: copy)
        let result = try h.labeler.undoLastChange(on: copy)
        #expect(result.restoredLabel?.text.value == "Test")
        #expect(try h.system.currentWallpaper(on: copy).url?.lastPathComponent == stamp.fileName)
    }

    @Test func listShowsTheLabelOnBothCurrentDesktops() throws {
        let (h, _, _) = try sharedLabel(); defer { h.cleanUp() }
        let labels = try h.labeler.listDesktops().entries.filter(\.current).compactMap(\.label)
        #expect(labels == ["Test", "Test"])
    }
}
