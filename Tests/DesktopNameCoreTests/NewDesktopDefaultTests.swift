import Foundation
import Testing
@testable import DesktopNameCore

/// Known issue KI-1: a label must not become the default for new Desktops, or spread to other Desktops, when
/// "Show on all Spaces" was on for the display.
@Suite struct NewDesktopDefaultTests {
    @Test func firstLabelOnADisplayWithShowOnAllSpacesLeavesTheDisplayDefaultAsTheOriginal() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        h.system.showOnAllSpaces[h.display.uuid] = true

        let result = try h.labeler.setLabel(LabelText("Belvedere"), on: h.display)

        // The wide, first set carried the original image; the stamp followed and reached only this Desktop.
        #expect(h.system.displayDefaultFile[h.display.uuid] == original.lastPathComponent)
        #expect(result.warnings.isEmpty)
        #expect(h.system.showOnAllSpaces[h.display.uuid] == false)
        #expect(h.system.setCalls.count == 2)
        #expect(h.system.setCalls[0].url.lastPathComponent == original.lastPathComponent)   // the re-applied wallpaper
        #expect(h.system.setCalls[1].url.lastPathComponent == (try h.manifest().stamps[0].fileName))
    }

    @Test func aReplacementDoesNotRepeatTheReapplyStep() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("One"), on: h.display)
        let callsBefore = h.system.setCalls.count
        try h.labeler.setLabel(LabelText("Two"), on: h.display)
        #expect(h.system.setCalls.count == callsBefore + 1)
    }

    @Test func theReapplyStepSetsTheSameImageAndPlacementTheDesktopAlreadyHad() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let placement = WallpaperPlacement(scaling: 2, clipping: false, fillColor: Data([4, 2]))
        let original = try h.showOriginal(placement: placement)
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let first = try #require(h.system.setCalls.first)
        #expect(first.url.resolvingSymlinksInPath() == original.resolvingSymlinksInPath())
        #expect(first.placement == placement)
    }

    @Test func ifTheLabelStillBecomesTheDefaultTheUserIsToldHowToFixIt() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        h.system.showOnAllSpaces[h.display.uuid] = true
        h.system.flipsAllSpacesAfterFirstSet = false   // macOS keeps writing the default on every set

        let result = try h.labeler.setLabel(LabelText("Belvedere"), on: h.display)

        let warning = try #require(result.warnings.first)
        #expect(warning.contains("default for new Desktops"))
        #expect(warning.contains("Built-in Display"))
        #expect(warning.contains("Show on all Spaces"))
        #expect(try h.manifest().stamps.count == 1)   // the label itself was applied
    }

    @Test func anUnreadableStoreGivesNoWarningAndDoesNotBlockLabeling() throws {
        let h = try LabelerHarness(settleTimeout: 0.2); defer { h.cleanUp() }
        try h.showOriginal()
        h.system.showOnAllSpaces[h.display.uuid] = true
        h.system.flipsAllSpacesAfterFirstSet = false
        h.inspector.unreadable = true
        let result = try h.labeler.setLabel(LabelText("Email"), on: h.display)
        #expect(result.warnings.isEmpty)
        #expect(try h.manifest().stamps.count == 1)
    }

    @Test func cleanupKeepsARetiredStampThatTheWallpaperStoreStillPointsAt() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        h.system.showOnAllSpaces[h.display.uuid] = true
        h.system.flipsAllSpacesAfterFirstSet = false          // the display default ends up pointing at the stamp
        try h.labeler.setLabel(LabelText("Belvedere"), on: h.display)
        let stamp = try #require(try h.manifest().stamps.first)
        h.system.showOnAllSpaces[h.display.uuid] = false      // the removal writes only the Desktop's own entry
        try h.labeler.removeLabel(on: h.display)

        h.clock.advance(minutes: 45)
        try h.labeler.cleanUp()

        // The default still references the stamp, so deleting it would leave macOS pointing at a missing image.
        #expect(h.store.stampFileExists(named: stamp.fileName))
        #expect(try h.manifest().stamps.contains { $0.id == stamp.id })
    }

    @Test func cleanupStillDeletesAnUnreferencedRetiredStamp() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let stamp = try #require(try h.manifest().stamps.first)
        try h.labeler.removeLabel(on: h.display)
        h.clock.advance(minutes: 45)
        try h.labeler.cleanUp()
        #expect(!h.store.stampFileExists(named: stamp.fileName))
    }

    @Test func whenTheStoreCannotBeReadTheCoolDownAloneDecides() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let stamp = try #require(try h.manifest().stamps.first)
        try h.labeler.removeLabel(on: h.display)
        h.inspector.unreadable = true
        h.clock.advance(minutes: 45)
        try h.labeler.cleanUp()
        #expect(!h.store.stampFileExists(named: stamp.fileName))
    }
}
