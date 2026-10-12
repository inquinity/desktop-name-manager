import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 009: `cleanup` finds labeled images that no Desktop is known to show, and deletes exactly what was shown.
@Suite struct CleanupTests {
    /// Labels, relabels and removes, leaving two retired images and nothing active, then lets the undo window pass.
    func history() throws -> LabelerHarness {
        let h = try LabelerHarness()
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("One"), on: h.display)
        try h.labeler.setLabel(LabelText("Two"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        return h
    }

    // MARK: Retired labels

    @Test func aListingNamesRetiredImagesAndDeletesNothing() throws {
        let h = try history(); defer { h.cleanUp() }
        h.clock.advance(minutes: 40 * 24 * 60)
        let plan = try h.labeler.cleanupPlan(days: 30)
        #expect(plan.candidates.map(\.label) == ["One", "Two"])
        #expect(plan.candidates.map(\.reason) == [.replaced, .removed])
        #expect(plan.totalBytes > 0)
        #expect(h.storeFiles.count == 2)
        #expect(try h.manifest().stamps.count == 2)
    }

    @Test func theAgeIsCountedFromWhenTheLabelWasRetired() throws {
        let h = try history(); defer { h.cleanUp() }
        h.clock.advance(minutes: 20 * 24 * 60)
        #expect(try h.labeler.cleanupPlan(days: 30).candidates.isEmpty)
        #expect(try h.labeler.cleanupPlan(days: 20).candidates.count == 2, "exactly 20 days old counts")
        #expect(try h.labeler.cleanupPlan(days: 7).candidates.count == 2)
    }

    @Test func nothingInTheUndoWindowIsEverACandidate() throws {
        let h = try history(); defer { h.cleanUp() }
        // The removal can still be undone, so the label it would bring back is needed; the older one is not.
        #expect(try h.labeler.cleanupPlan(days: 0).candidates.map(\.label) == ["One"])
        h.clock.advance(minutes: 31)
        #expect(try h.labeler.cleanupPlan(days: 0).candidates.map(\.label) == ["One", "Two"])
    }

    // MARK: Labels not seen

    @Test func anActiveLabelNoDesktopShowsAndNobodySawIsACandidate() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Gone"), on: h.display)
        h.system.show(original, on: h.display)                           // the Desktop was deleted; its replacement shows the original
        h.clock.advance(minutes: 40 * 24 * 60)
        let plan = try h.labeler.cleanupPlan(days: 30)
        #expect(plan.candidates.map(\.reason) == [.notSeen] && plan.candidates.map(\.label) == ["Gone"])
        #expect(plan.candidates[0].since == h.clock.now.addingTimeInterval(-40 * 86_400))
    }

    @Test func aLabelShowingOnACurrentDesktopIsNeverACandidate() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Keep"), on: h.display)
        h.clock.advance(minutes: 400 * 24 * 60)
        #expect(try h.labeler.cleanupPlan(days: 0).candidates.isEmpty)
    }

    @Test func recentSightingsKeepALabelOut() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.addStamp("Seen lately", lastSeen: h.days(5), createdAt: h.days(100))
        try h.addStamp("Seen long ago", lastSeen: h.days(60), createdAt: h.days(100))
        try h.addStamp("Never seen since made", createdAt: h.days(45))
        let plan = try h.labeler.cleanupPlan(days: 30)
        #expect(Set(plan.candidates.map(\.label)) == ["Seen long ago", "Never seen since made"])
        #expect(plan.candidates.map(\.label).first == "Seen long ago", "oldest sighting first")
    }

    @Test func aLabelFromBeforeLastSeenExistedCountsFromWhenItWasMade() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.addStamp("Old format", lastSeen: nil, createdAt: h.days(50))
        try h.addStamp("New", lastSeen: nil, createdAt: h.days(2))
        #expect(try h.labeler.cleanupPlan(days: 30).candidates.map(\.label) == ["Old format"])
    }

    @Test func anImageShownOnAnotherDisplaysCurrentDesktopIsNeverACandidate() throws {
        let other = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other]); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Shared"), on: h.display)
        let shown = try h.system.currentWallpaper(on: h.display)
        h.system.show(shown.url, placement: shown.placement, on: other)   // a copy, as macOS makes for a new Desktop
        try h.labeler.removeLabel(on: h.display)                         // retired, but still shown on the other display
        h.clock.advance(minutes: 40 * 24 * 60)
        #expect(try h.labeler.cleanupPlan(days: 0).candidates.isEmpty)
    }

    // MARK: Deleting

    @Test func carryingOutDeletesTheImagesAndTheirRecords() throws {
        let h = try history(); defer { h.cleanUp() }
        h.clock.advance(minutes: 40 * 24 * 60)
        let plan = try h.labeler.cleanupPlan(days: 30)
        let deleted = try h.labeler.carryOut(plan)
        #expect(deleted.candidates.count == 2 && deleted.totalBytes == plan.totalBytes)
        #expect(h.storeFiles.isEmpty)
        #expect(try h.manifest().stamps.isEmpty)
    }

    @Test func itDeletesOnlyWhatWasShownAndIsStillACandidate() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let shownToThePerson = try h.addStamp("Listed")
        try h.store.transaction { $0.stamps[0].lastSeen = h.days(60); $0.stamps[0].createdAt = h.days(60) }
        let plan = try h.labeler.cleanupPlan(days: 30)
        #expect(plan.candidates.map(\.label) == ["Listed"])
        // After the list was shown, a label appears that was not on it (also old), and the listed one is on screen again.
        try h.addStamp("Added later", lastSeen: h.days(60), createdAt: h.days(60))
        h.system.show(h.store.fileURL(named: shownToThePerson.fileName), on: h.display)
        let deleted = try h.labeler.carryOut(plan)
        #expect(deleted.candidates.isEmpty, "the listed one is showing now; the new one was never listed")
        #expect(h.storeFiles.count == 2)
    }

    @Test func deletingResetsTheNudgeAndRecordsWhatIsShowing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Keep"), on: h.display)
        try h.addStamp("Old", lastSeen: h.days(60), createdAt: h.days(60))
        try h.store.transaction { $0.maintenance = Maintenance(nudgedAt: h.clock.now, nudgedBytes: 1) }
        _ = original
        h.clock.advance(minutes: 31)
        let deleted = try h.labeler.carryOut(try h.labeler.cleanupPlan(days: 30))
        #expect(deleted.candidates.map(\.label) == ["Old"])
        let manifest = try h.manifest()
        #expect(manifest.maintenance == nil)
        #expect(manifest.stamps.count == 1 && manifest.stamps[0].lastSeen == h.clock.now, "the label on screen was seen")
    }

    @Test func aMissingFileIsListedAtZeroBytesAndItsRecordRemoved() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let stamp = try h.addStamp("Lost", lastSeen: h.days(60), createdAt: h.days(60))
        h.store.removeFile(named: stamp.fileName)
        let plan = try h.labeler.cleanupPlan(days: 30)
        #expect(plan.candidates.map(\.bytes) == [0])
        try h.labeler.carryOut(plan)
        #expect(try h.manifest().stamps.isEmpty)
    }

    // MARK: Edges

    @Test func nothingStoredMeansNothingToCleanUpAndNoStoreIsCreated() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        #expect(try h.labeler.cleanupPlan(days: 0).candidates.isEmpty)
        #expect(try h.labeler.carryOut(CleanupPlan(days: 0, candidates: [])).candidates.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: h.store.directory.path))
    }

    @Test func aStoreNewerThanTheToolUnderstandsIsLeftAlone() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try FileManager.default.createDirectory(at: h.store.directory, withIntermediateDirectories: true)
        let newer = Data(#"{"schemaVersion": 99, "stamps": [], "changes": []}"#.utf8)
        try newer.write(to: h.store.manifestURL)
        #expect(throws: DnmError.self) { try h.labeler.cleanupPlan(days: 0) }
        #expect(try Data(contentsOf: h.store.manifestURL) == newer)
    }

    @Test func theReportHasNoFileNamesOrIdentifiers() throws {
        let h = try history(); defer { h.cleanUp() }
        h.clock.advance(minutes: 40 * 24 * 60)
        let json = try Reports.json(Reports.cleanup(try h.labeler.cleanupPlan(days: 30), deleted: false))
        #expect(!json.contains(".dnm.") && !json.contains("DISPLAY-A"))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(Set(root.keys) == ["days", "candidates", "totalBytes", "deleted"])
        let entry = try #require((root["candidates"] as? [[String: Any]])?.first)
        #expect(Set(entry.keys) == ["label", "display", "why", "since", "bytes"])
    }
}
