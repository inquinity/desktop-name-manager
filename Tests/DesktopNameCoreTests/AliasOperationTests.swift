import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 006: setting, moving, removing and listing aliases. No wallpaper is ever touched.
@Suite struct AliasOperationTests {
    func harness() throws -> LabelerHarness {
        try LabelerHarness(extraDisplays: [FakeWallpaperSystem.makeDisplay(name: "LG Ultra HD", uuid: "DISPLAY-B", isMain: false)])
    }

    @Test func aliasingNothingTargetsTheMainDisplay() throws {
        let h = try harness(); defer { h.cleanUp() }
        let result = try h.labeler.setAlias("desk", display: nil)
        #expect(result == SetAliasResult(name: "desk", displayName: "Built-in Display", isMain: true, change: .created))
        #expect(try h.labeler.aliases() == [DisplayAlias(name: "desk", displayUUID: "DISPLAY-A", displayName: "Built-in Display")])
        #expect(h.system.setCalls.isEmpty)
    }

    @Test func aPartialNameChoosesTheDisplay() throws {
        let h = try harness(); defer { h.cleanUp() }
        let result = try h.labeler.setAlias("dp", display: "ultra")
        #expect(result.displayName == "LG Ultra HD" && !result.isMain)
    }

    @Test func settingTheSameAliasAgainIsUnchanged() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.labeler.setAlias("dp", display: "LG")
        #expect(try h.labeler.setAlias("dp", display: "LG").change == .unchanged)
        #expect(try h.labeler.aliases().count == 1)
    }

    @Test func movingAnAliasNamesTheOldDisplayAndKeepsTheNewCapitalization() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.labeler.setAlias("dp", display: "LG")
        let result = try h.labeler.setAlias("DP", display: "main")
        #expect(result.change == .moved(from: "LG Ultra HD"))
        #expect(result.name == "DP")
        #expect(try h.labeler.aliases() == [DisplayAlias(name: "DP", displayUUID: "DISPLAY-A", displayName: "Built-in Display")])
    }

    @Test func oneDisplayCanHaveSeveralAliases() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.labeler.setAlias("dp", display: "LG")
        try h.labeler.setAlias("work", display: "LG")
        #expect(try h.labeler.aliases().count == 2)
    }

    @Test func aliasesAreNotAcceptedAsTheTargetDisplay() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.labeler.setAlias("dp", display: "LG")
        #expect(throws: DnmError.self) { try h.labeler.setAlias("other", display: "dp") }
        #expect(try h.labeler.aliases().count == 1)
    }

    @Test func aNameThatIsAConnectedDisplayIsRefused() throws {
        let h = try LabelerHarness(extraDisplays: [FakeWallpaperSystem.makeDisplay(name: "DP1", uuid: "DISPLAY-B", isMain: false)])
        defer { h.cleanUp() }
        do {
            try h.labeler.setAlias("dp1", display: "main")
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect((error.errorDescription ?? "").contains("DP1 is already the name of a connected display and cannot be used as an alias."))
        }
        #expect(!h.store.hasManifest)
    }

    @Test func aDisplayWithoutAStableIdentityIsRefused() throws {
        let h = try LabelerHarness(extraDisplays: [FakeWallpaperSystem.makeDisplay(name: "Capture", uuid: "no-uuid-1-2-3-4", isMain: false)])
        defer { h.cleanUp() }
        #expect(throws: DnmError.self) { try h.labeler.setAlias("cap", display: "Capture") }
        #expect(!h.store.hasManifest)
    }

    @Test func twoDisplaysWithTheSameIdentityAreRefused() throws {
        let h = try LabelerHarness(extraDisplays: [FakeWallpaperSystem.makeDisplay(name: "Twin", uuid: "DISPLAY-A", isMain: false)])
        defer { h.cleanUp() }
        do {
            try h.labeler.setAlias("one", display: "Built-in")
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("report the same identity"))
        }
        #expect(!h.store.hasManifest)
    }

    @Test func invalidNamesStoreNothing() throws {
        let h = try harness(); defer { h.cleanUp() }
        for name in ["main", "7", "a b"] { #expect(throws: DnmError.self) { try h.labeler.setAlias(name, display: nil) } }
        #expect(!h.store.hasManifest)
    }

    @Test func removingIsCaseInsensitiveAndReturnsTheStoredName() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.labeler.setAlias("Desk", display: nil)
        #expect(try h.labeler.removeAlias(named: "DESK") == "Desk")
        #expect(try h.labeler.aliases().isEmpty)
    }

    @Test func removingAMissingAliasIsInvalidInputAndCreatesNothing() throws {
        let h = try harness(); defer { h.cleanUp() }
        do {
            try h.labeler.removeAlias(named: "nope")
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect(error.errorDescription == "No alias named nope exists.")
        }
        #expect(!h.store.hasManifest)
    }

    @Test func settingAnAliasKeepsLabelsAndHistory() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Mail"), on: h.display)
        let before = try h.manifest()
        try h.labeler.setAlias("desk", display: nil)
        let after = try h.manifest()
        #expect(after.stamps == before.stamps && after.changes == before.changes)
        #expect(after.aliases.count == 1)
    }

    @Test func listingShowsConnectedAbsentAndOverriddenAliases() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.labeler.setAlias("desk", display: nil)
        try h.labeler.setAlias("dp", display: "LG")
        h.system.connectedDisplays.append(FakeWallpaperSystem.makeDisplay(name: "Lg_Ultra", uuid: "DISPLAY-C", isMain: false))
        // An alias for a display that is gone, and one whose name a connected display now carries.
        try h.store.transaction {
            $0.aliases.append(DisplayAlias(name: "old", displayUUID: "GONE", displayName: "Studio Display"))
            $0.aliases.append(DisplayAlias(name: "nameless", displayUUID: "GONE-2", displayName: nil))
            $0.aliases.append(DisplayAlias(name: "lg_ultra", displayUUID: "DISPLAY-A", displayName: "Built-in Display"))
        }
        let entries = try h.labeler.listAliases()
        #expect(entries.map(\.name) == ["desk", "dp", "lg_ultra", "nameless", "old"])
        #expect(entries[0] == AliasEntry(name: "desk", display: "Built-in Display", connected: true, isMain: true, overridden: false, overriddenBy: nil))
        #expect(entries[2].overridden && entries[2].overriddenBy == "Lg_Ultra")
        #expect(entries[3].display == "GONE-2" && !entries[3].connected)
        #expect(entries[4] == AliasEntry(name: "old", display: "Studio Display", connected: false, isMain: false, overridden: false, overriddenBy: nil))
    }

    @Test func listingCreatesNoStore() throws {
        let h = try harness(); defer { h.cleanUp() }
        #expect(try h.labeler.listAliases().isEmpty)
        #expect(!h.store.hasManifest)
    }

    @Test func storedTextIsSanitizedOnTheWayOut() throws {
        let h = try harness(); defer { h.cleanUp() }
        try h.store.transaction {
            $0.aliases.append(DisplayAlias(name: "bad\u{1B}[31m", displayUUID: "GONE", displayName: "Studio\u{1B}[2J"))
        }
        let entry = try #require(try h.labeler.listAliases().first)
        #expect(!entry.name.contains("\u{1B}") && !entry.display.contains("\u{1B}"))
    }
}
