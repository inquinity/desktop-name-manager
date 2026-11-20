import Foundation
import Testing
@testable import DesktopNameCore
import DNMTestSupport

/// `setAlias(_:on:)` (spec 014, the app's Displays pane): the same rules and sentences as `setAlias(_:display:)`, for a
/// display given itself.
@Suite struct AliasOnDisplayTests {
    static let side = FakeWallpaperSystem.makeDisplay(name: "LG Ultra HD", uuid: "DISPLAY-B", isMain: false)

    @Test func itSetsAndMovesAsTheNamedForm() throws {
        let h = try LabelerHarness(extraDisplays: [Self.side]); defer { h.cleanUp() }
        #expect(try h.labeler.setAlias("desk", on: Self.side) == SetAliasResult(name: "desk", displayName: "LG Ultra HD", isMain: false, change: .created))
        #expect(try h.labeler.setAlias("desk", on: h.display).change == .moved(from: "LG Ultra HD"))
    }

    @Test func aDisplayReadEarlierIsCheckedAsItIsNow() throws {
        let h = try LabelerHarness(extraDisplays: [Self.side]); defer { h.cleanUp() }
        let readEarlier = Self.side
        var now = Self.side
        now.name = "LG Ultra HD (renamed)"
        now.geometry.scale = 1
        h.system.connectedDisplays = [h.display, now]
        let result = try h.labeler.setAlias("desk", on: readEarlier)
        #expect(result.displayName == "LG Ultra HD (renamed)")
        #expect(try h.labeler.aliases().first?.displayName == "LG Ultra HD (renamed)")
    }

    @Test func aDisconnectedDisplayIsRefused() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        #expect(throws: DnmError.failure("The display \"LG Ultra HD\" is no longer connected.")) {
            try h.labeler.setAlias("desk", on: Self.side)
        }
    }

    @Test func refusalsMatchTheNamedForm() throws {
        let h = try LabelerHarness(extraDisplays: [Self.side]); defer { h.cleanUp() }
        for name in ["123", "main", "LG Ultra HD", String(repeating: "a", count: 31), "bad name"] {
            var named: String?, given: String?
            do { try h.labeler.setAlias(name, display: "LG") } catch { named = "\(error)" }
            do { try h.labeler.setAlias(name, on: Self.side) } catch { given = "\(error)" }
            #expect(named != nil && named == given, "\(name)")
        }
    }

    @Test func twinDisplaysAreRefused() throws {
        var twin = Self.side
        twin.name = "LG Ultra HD (2)"
        let h = try LabelerHarness(extraDisplays: [Self.side, twin]); defer { h.cleanUp() }
        #expect(throws: DnmError.invalidInput("LG Ultra HD and LG Ultra HD (2) report the same identity to macOS, so an alias could point at either. Nothing was changed.")) {
            try h.labeler.setAlias("desk", on: Self.side)
        }
        #expect(try h.labeler.aliases().isEmpty)
    }
}
