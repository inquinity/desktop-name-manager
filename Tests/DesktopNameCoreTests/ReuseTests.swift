import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 009: `set` uses an existing labeled image when asked for the same thing, so a deleted and recreated Desktop
/// adds nothing to the store.
@Suite struct ReuseTests {
    func labeled(_ text: String = "Mail", options: LabelOptions = LabelOptions()) throws -> (h: LabelerHarness, original: URL) {
        let h = try LabelerHarness()
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText(text), options: options, on: h.display)
        return (h, original)
    }

    @Test func theSameRequestAgainOnTheSameDesktopAddsNoImage() throws {
        let (h, _) = try labeled(); defer { h.cleanUp() }
        let first = try #require(try h.manifest().stamps.first)
        let result = try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let manifest = try h.manifest()
        #expect(manifest.stamps.count == 1 && h.storeFiles.count == 1)
        #expect(result.replaced && result.label == first.label)
        #expect(manifest.stamps[0].isActive)
        #expect(h.system.current[h.display.uuid]?.url?.lastPathComponent == first.fileName)
    }

    @Test func aDeletedAndRecreatedDesktopReusesTheImage() throws {
        let (h, original) = try labeled(); defer { h.cleanUp() }
        let first = try #require(try h.manifest().stamps.first)
        // The Desktop is deleted; the new one starts on the original wallpaper again.
        h.system.show(original, on: h.display)
        h.clock.advance(minutes: 3 * 24 * 60)
        let result = try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let manifest = try h.manifest()
        #expect(manifest.stamps.count == 1 && h.storeFiles.count == 1, "no second image")
        #expect(!result.replaced)
        #expect(h.system.current[h.display.uuid]?.url?.lastPathComponent == first.fileName)
        #expect(manifest.stamps[0].lastSeen == h.clock.now, "seen again")
    }

    @Test func aRemovedLabelIsRevivedNotRemade() throws {
        let (h, _) = try labeled(); defer { h.cleanUp() }
        let id = try #require(try h.manifest().stamps.first).id
        try h.labeler.removeLabel(on: h.display)
        #expect(try h.manifest().stamps[0].isActive == false)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let manifest = try h.manifest()
        #expect(manifest.stamps.count == 1 && h.storeFiles.count == 1)
        #expect(manifest.stamps[0].isActive && manifest.stamps[0].supersededBy == nil)
        let record = try #require(manifest.changes.first)
        #expect(record.kind == .set && record.produced == .stamp(id: id))
    }

    @Test func aDifferentRequestMakesANewImage() throws {
        let (h, _) = try labeled(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Notes"), on: h.display)
        #expect(try h.manifest().stamps.count == 2)
        try h.labeler.setLabel(LabelText("Notes"), options: LabelOptions(look: .halo), on: h.display)
        #expect(try h.manifest().stamps.count == 3)
        try h.labeler.setLabel(LabelText("Notes"), options: LabelOptions(look: .halo, size: .large), on: h.display)
        #expect(try h.manifest().stamps.count == 4)
    }

    @Test func aChangedOriginalMakesANewImage() throws {
        let (h, original) = try labeled(); defer { h.cleanUp() }
        h.system.show(original, on: h.display)
        _ = try SyntheticImages.write(SyntheticImages.noise(width: 640, height: 400), to: original)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 7200)], ofItemAtPath: original.path)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        #expect(try h.manifest().stamps.count == 2)
    }

    @Test func anotherDisplayMakesItsOwnImage() throws {
        let other = FakeWallpaperSystem.makeDisplay(name: "Second", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other]); defer { h.cleanUp() }
        let url = try h.showOriginal()
        h.system.show(url, on: other)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: other)
        let manifest = try h.manifest()
        #expect(manifest.stamps.count == 2)
        #expect(Set(manifest.stamps.map(\.displayUUID)) == ["DISPLAY-A", "DISPLAY-B"])
    }

    @Test func aMissingImageFileIsNotReused() throws {
        let (h, original) = try labeled(); defer { h.cleanUp() }
        let stamp = try #require(try h.manifest().stamps.first)
        h.store.removeFile(named: stamp.fileName)
        h.system.show(original, on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let manifest = try h.manifest()
        #expect(manifest.stamps.count == 2)
        #expect(h.system.current[h.display.uuid]?.url?.lastPathComponent == manifest.stamps[1].fileName)
    }

    @Test func labelsFromBeforeTheKeyExistedAreNeverReused() throws {
        let (h, original) = try labeled(); defer { h.cleanUp() }
        try h.store.transaction { $0.stamps[0].reuseKey = nil }
        h.system.show(original, on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        #expect(try h.manifest().stamps.count == 2)
    }

    @Test func undoAfterAReusedSetRestoresWhatWasThere() throws {
        let (h, _) = try labeled("A"); defer { h.cleanUp() }
        let a = try #require(try h.manifest().stamps.first)
        try h.labeler.setLabel(LabelText("B"), on: h.display)
        let b = try #require(try h.manifest().stamps.last)
        try h.labeler.setLabel(LabelText("A"), on: h.display)             // reuses A, replacing B
        #expect(try h.manifest().stamps.count == 2 && h.storeFiles.count == 2)
        #expect(h.system.current[h.display.uuid]?.url?.lastPathComponent == a.fileName)
        try h.labeler.undoLastChange(on: h.display)
        #expect(h.system.current[h.display.uuid]?.url?.lastPathComponent == b.fileName)
        let manifest = try h.manifest()
        #expect(manifest.stamps.first { $0.id == b.id }?.isActive == true)
        #expect(manifest.stamps.first { $0.id == a.id }?.isActive == false)
    }

    @Test func aRetiredLabelStillShowingIsActiveAgainWhenAskedFor() throws {
        // Two Desktops of one display share the image; the label is removed on one, then asked for on the other.
        let (h, original) = try labeled(); defer { h.cleanUp() }
        let shared = try h.system.currentWallpaper(on: h.display)
        try h.labeler.removeLabel(on: h.display)
        #expect(try h.manifest().stamps[0].isActive == false)
        h.system.show(shared.url, placement: shared.placement, on: h.display)   // switch to the other Desktop
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let manifest = try h.manifest()
        #expect(manifest.stamps.count == 1 && manifest.stamps[0].isActive && manifest.stamps[0].supersededBy == nil)
        h.system.show(original, on: h.display)   // back to a Desktop without the label
        h.clock.advance(minutes: 40 * 24 * 60)
        #expect(try h.labeler.cleanupPlan(days: 30).candidates.map(\.reason) == [.notSeen], "aged as active, not as removed")
    }

    @Test func undoAfterReusingAnActiveLabelLeavesItActive() throws {
        // A labeled Desktop is kept; a new Desktop on the original wallpaper gets the same label, then undo.
        let (h, original) = try labeled(); defer { h.cleanUp() }
        let id = try #require(try h.manifest().stamps.first).id
        h.system.show(original, on: h.display)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        try h.labeler.undoLastChange(on: h.display)
        #expect(h.system.current[h.display.uuid]?.url?.lastPathComponent == original.lastPathComponent)
        #expect(try h.manifest().stamps.first { $0.id == id }?.isActive == true, "the kept Desktop still shows it")
    }

    @Test func undoAfterReusingARetiredLabelPutsItsStateBack() throws {
        let (h, _) = try labeled(); defer { h.cleanUp() }
        try h.labeler.removeLabel(on: h.display)
        let retired = try #require(try h.manifest().stamps.first).state
        h.clock.advance(minutes: 5)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        #expect(try h.manifest().stamps[0].isActive)
        try h.labeler.undoLastChange(on: h.display)
        #expect(try h.manifest().stamps[0].state == retired)
    }

    @Test func undoAfterAReuseThatReplacedALabelPutsTheReusedStateBack() throws {
        let (h, _) = try labeled("A"); defer { h.cleanUp() }
        let a = try #require(try h.manifest().stamps.first)
        try h.labeler.setLabel(LabelText("B"), on: h.display)
        let replaced = try #require(try h.manifest().stamps.first { $0.id == a.id }).state
        h.clock.advance(minutes: 5)
        try h.labeler.setLabel(LabelText("A"), on: h.display)             // reuses the retired A, replacing B
        try h.labeler.undoLastChange(on: h.display)
        #expect(try h.manifest().stamps.first { $0.id == a.id }?.state == replaced, "as it was, not retired again as undone")
    }

    @Test func aRecordFromBeforeReuseUndoesAsBefore() throws {
        // A change record written without `reusedFrom` still reads, and undo retires the label it produced.
        let (h, _) = try labeled(); defer { h.cleanUp() }
        try h.labeler.removeLabel(on: h.display)
        h.clock.advance(minutes: 5)
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        var root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: h.store.manifestURL)) as? [String: Any])
        var changes = try #require(root["changes"] as? [[String: Any]])
        #expect(changes.contains { $0["reusedFrom"] != nil })
        changes = changes.map { $0.filter { $0.key != "reusedFrom" } }
        root["changes"] = changes
        try JSONSerialization.data(withJSONObject: root).write(to: h.store.manifestURL)
        #expect(try h.manifest().changes.allSatisfy { $0.reusedFrom == nil })
        try h.labeler.undoLastChange(on: h.display)
        #expect(try h.manifest().stamps[0].state == .retired(at: h.clock.now, reason: .undone))
    }

    @Test func aFailedReuseLeavesTheManifestAsItWas() throws {
        let (h, original) = try labeled(); defer { h.cleanUp() }
        try h.labeler.removeLabel(on: h.display)
        h.system.show(original, on: h.display)
        let before = try h.manifest()
        h.system.setError = DnmError.failure("denied")
        #expect(throws: DnmError.self) { try h.labeler.setLabel(LabelText("Mail"), on: h.display) }
        h.system.setError = nil
        #expect(try h.manifest().stamps == before.stamps)
    }
}
