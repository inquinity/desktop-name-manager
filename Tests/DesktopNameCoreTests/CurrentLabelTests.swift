import Foundation
import Testing
@testable import DesktopNameCore
import DNMTestSupport

/// `currentLabel(on:)` (spec 014, contracts/core-additions.md §2): the rule `dnm show` uses, read only.
@Suite struct CurrentLabelTests {
    @Test func aLabeledDesktopGivesItsLabel() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Q4 budget"), on: h.display)
        #expect(try h.labeler.currentLabel(on: h.display)?.text.value == "Q4 budget")
    }

    @Test func anUnlabeledDesktopGivesNil() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        #expect(try h.labeler.currentLabel(on: h.display) == nil)
    }

    @Test func aDesktopWithNoWallpaperFileGivesNil() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        h.system.show(nil, on: h.display)
        #expect(try h.labeler.currentLabel(on: h.display) == nil)
    }

    @Test func aStampFromAnotherStoreGivesNil() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Q4 budget"), on: h.display)
        let other = DesktopLabeler(system: h.system, store: Store(directory: h.root.appendingPathComponent("other", isDirectory: true)),
                                   time: h.clock)
        #expect(try other.currentLabel(on: h.display) == nil)
    }

    @Test func aNewerManifestThrows() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try FileManager.default.createDirectory(at: h.store.directory, withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 99, "stamps": [], "changes": []}"#.utf8).write(to: h.store.manifestURL)
        #expect(throws: DnmError.newerManifest(found: 99, supported: Manifest.currentSchemaVersion)) {
            try h.labeler.currentLabel(on: h.display)
        }
    }

    @Test func itChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Q4 budget"), on: h.display)
        let before = try Data(contentsOf: h.store.manifestURL)
        h.clock.advance(minutes: 60 * 24 * 400)   // long enough for housekeeping to want to act
        _ = try h.labeler.currentLabel(on: h.display)
        #expect(try Data(contentsOf: h.store.manifestURL) == before)
    }

    @Test func showLabelAgreesWithIt() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Q4 budget"), on: h.display)
        #expect(try h.labeler.showLabel(on: h.display).label == h.labeler.currentLabel(on: h.display))
    }
}
