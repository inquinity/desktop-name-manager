import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 009: commands that already write record which labels they saw showing; read-only ones change nothing.
@Suite struct LastSeenTests {
    func twoLabeled() throws -> (h: LabelerHarness, other: Display, first: Stamp, second: Stamp) {
        let other = FakeWallpaperSystem.makeDisplay(name: "Second", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other])
        let url = try h.showOriginal()
        h.system.show(url, on: other)
        try h.labeler.setLabel(LabelText("One"), on: h.display)
        try h.labeler.setLabel(LabelText("Two"), on: other)
        let stamps = try h.manifest().stamps
        return (h, other, stamps[0], stamps[1])
    }

    @Test func aNewLabelIsSeenWhenItIsMade() throws {
        let (h, _, first, _) = try twoLabeled(); defer { h.cleanUp() }
        #expect(first.lastSeen == first.createdAt)
    }

    @Test func aWritingCommandRecordsWhatIsShowingOnEveryDisplay() throws {
        let (h, _, first, second) = try twoLabeled(); defer { h.cleanUp() }
        h.clock.advance(minutes: 5 * 24 * 60)
        try h.labeler.setLabel(LabelText("Three"), on: h.display)        // acts on display A; B's label is also showing
        let stamps = try h.manifest().stamps
        #expect(stamps.first { $0.id == second.id }?.lastSeen == h.clock.now, "seen on the other display")
        #expect(stamps.first { $0.id == first.id }?.lastSeen == h.clock.now, "seen as it was replaced")
        #expect(stamps.last?.lastSeen == h.clock.now)
    }

    @Test func removeAndUndoRecordToo() throws {
        let (h, other, first, second) = try twoLabeled(); defer { h.cleanUp() }
        h.clock.advance(minutes: 5)
        try h.labeler.removeLabel(on: other)
        #expect(try h.manifest().stamps.first { $0.id == first.id }?.lastSeen == h.clock.now)
        h.clock.advance(minutes: 5)
        try h.labeler.undoLastChange(on: other)
        #expect(try h.manifest().stamps.first { $0.id == first.id }?.lastSeen == h.clock.now)
        #expect(try h.manifest().stamps.first { $0.id == second.id }?.lastSeen == h.clock.now)
    }

    @Test func readOnlyCommandsLeaveTheManifestUntouched() throws {
        let (h, other, _, _) = try twoLabeled(); defer { h.cleanUp() }
        let before = try Data(contentsOf: h.store.manifestURL)
        // Inside the undo window, so housekeeping (which every command runs, and which drops expired undo records) has
        // nothing to do; what is checked is that no read-only command records a sighting.
        h.clock.advance(minutes: 1)
        _ = try h.labeler.listDesktops()
        _ = try h.labeler.showLabel(on: h.display)
        _ = try h.labeler.showLabel(on: other)
        _ = try h.labeler.listAliases()
        _ = try h.labeler.check(Configuration(macOSVersion: "26", chip: "M", displaysHaveSeparateSpaces: true, accessibilityGranted: true))
        #expect(try Data(contentsOf: h.store.manifestURL) == before)
    }
}
