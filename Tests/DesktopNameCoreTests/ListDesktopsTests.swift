import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct ListDesktopsTests {
    func twoDisplays() throws -> (LabelerHarness, Display) {
        let other = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)
        let h = try LabelerHarness(extraDisplays: [other])
        try h.showOriginal()
        let second = try SyntheticImages.write(SyntheticImages.dark(), to: h.root.appendingPathComponent("b.png"))
        h.system.show(second, on: other)
        return (h, other)
    }

    @Test func labeledDesktopsAndTheCurrentDesktopPerDisplayAreListed() throws {
        let (h, other) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.setLabel(LabelText("Music"), on: other)

        let listing = try h.labeler.listDesktops()
        #expect(listing.entries.count == 2)
        #expect(listing.entries[0] == DesktopEntry(displayName: "Built-in Display", connected: true, current: true, label: "Email", stampMissing: false))
        #expect(listing.entries[1] == DesktopEntry(displayName: "LG HDR 4K", connected: true, current: true, label: "Music", stampMissing: false))
        #expect(listing.scope == "Only labeled and current Desktops are shown.")
    }

    @Test func aCurrentDesktopWithNoLabelStillAppears() throws {
        let (h, _) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let listing = try h.labeler.listDesktops()
        #expect(listing.entries.contains { $0.displayName == "LG HDR 4K" && $0.current && $0.label == nil })
    }

    @Test func aLabeledDesktopThatIsNoLongerCurrentIsStillListed() throws {
        let (h, _) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        // The user switches to another Desktop on that display (it shows a different wallpaper).
        try h.showOriginal(SyntheticImages.dark(), name: "desktop2.png")

        let listing = try h.labeler.listDesktops()
        let builtIn = listing.entries.filter { $0.displayName == "Built-in Display" }
        #expect(builtIn.count == 2)
        #expect(builtIn[0].current && builtIn[0].label == nil)
        #expect(!builtIn[1].current && builtIn[1].label == "Email")
    }

    @Test func aLabelOnADisconnectedDisplayIsMarkedNotConnected() throws {
        let (h, other) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Music"), on: other)
        h.system.connectedDisplays.removeAll { $0.uuid == "DISPLAY-B" }

        let listing = try h.labeler.listDesktops()
        let entry = try #require(listing.entries.first { $0.label == "Music" })
        #expect(!entry.connected && !entry.current)
        #expect(entry.displayName == "LG HDR 4K")
    }

    @Test func aDeletedStampFileIsFlagged() throws {
        let (h, _) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        h.store.removeFile(named: try #require(try h.manifest().stamps.first).fileName)
        let entry = try #require(try h.labeler.listDesktops().entries.first { $0.label == "Email" })
        #expect(entry.stampMissing)
    }

    @Test func removedLabelsDoNotAppear() throws {
        let (h, _) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        try h.labeler.removeLabel(on: h.display)
        #expect(try h.labeler.listDesktops().entries.allSatisfy { $0.label == nil })
    }

    @Test func showReportsTheLabelDetails() throws {
        let (h, _) = try twoDisplays(); defer { h.cleanUp() }
        try h.labeler.setLabel(LabelText("Email"), options: LabelOptions(look: .halo, position: .topRight), on: h.display)
        let shown = try h.labeler.showLabel(on: h.display)
        #expect(shown.labeled)
        #expect(shown.displayName == "Built-in Display" && shown.isMain)
        #expect(shown.label?.look == .halo && shown.label?.position == .topRight)
        #expect(shown.label?.automatic == [.textColor])
        #expect(shown.originalRecorded && !shown.stampMissing && shown.createdAt != nil)
    }

    @Test func showOnAnUnlabeledDesktopSaysSo() throws {
        let (h, _) = try twoDisplays(); defer { h.cleanUp() }
        let shown = try h.labeler.showLabel(on: h.display)
        #expect(!shown.labeled && shown.label == nil && !shown.originalRecorded)
    }
}
