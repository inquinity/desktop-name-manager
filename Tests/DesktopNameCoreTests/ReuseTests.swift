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
