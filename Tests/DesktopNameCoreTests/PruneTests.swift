import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct PruneTests {
    /// Labels, relabels and removes, leaving two retired images and nothing active.
    func history() throws -> LabelerHarness {
        let h = try LabelerHarness()
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("One"), on: h.display)
        try h.labeler.setLabel(LabelText("Two"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        return h
    }

    @Test func aListingNamesRetiredImagesAndDeletesNothing() throws {
        let h = try history(); defer { h.cleanUp() }
        let result = try h.labeler.prune(confirm: false)
        #expect(result.candidates.map(\.label) == ["One", "Two"])
        #expect(result.candidates.map(\.reason) == [.replaced, .removed])
        #expect(result.totalBytes > 0)
        #expect(!result.deleted)
        #expect(h.storeFiles.count == 2)
        #expect(try h.manifest().stamps.count == 2)
    }

    @Test func confirmingDeletesTheImagesAndTheirRecords() throws {
        let h = try history(); defer { h.cleanUp() }
        let result = try h.labeler.prune(confirm: true)
        #expect(result.deleted && result.candidates.count == 2)
        #expect(h.storeFiles.isEmpty)
        #expect(try h.manifest().stamps.isEmpty)
    }

    @Test func anActiveLabelIsNeverACandidate() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Keep"), on: h.display)
        #expect(try h.labeler.prune(confirm: true).candidates.isEmpty)
        #expect(h.storeFiles.count == 1)
    }

    @Test func anImageShownOnACurrentDesktopIsNeverDeleted() throws {
        let other = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other]); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Shared"), on: h.display)
        let shown = try h.system.currentWallpaper(on: h.display)
        h.system.show(shown.url, placement: shown.placement, on: other)   // a copy, as macOS makes for a new Desktop
        try h.labeler.removeLabel(on: h.display)                         // retired, but still shown on the other display

        let result = try h.labeler.prune(confirm: true)
        #expect(result.candidates.isEmpty)
        #expect(h.storeFiles.count == 1)
    }

    @Test func nothingStoredMeansNothingToPrune() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        #expect(try h.labeler.prune(confirm: true).candidates.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: h.store.directory.path))
    }

    @Test func thePruneReportHasNoFileNames() throws {
        let h = try history(); defer { h.cleanUp() }
        let json = try Reports.json(Reports.prune(try h.labeler.prune(confirm: false)))
        #expect(!json.contains(".dnm."))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(Set(root.keys) == ["candidates", "totalBytes", "deleted"])
    }
}
