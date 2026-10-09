import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct ReportsTests {
    func object(_ json: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test func listJSONMatchesTheContract() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let json = try Reports.json(Reports.list(try h.labeler.listDesktops()))
        let root = try object(json)
        #expect(root["scope"] as? String == "Only labeled and current Desktops are shown.")
        let desktop = try #require((root["desktops"] as? [[String: Any]])?.first)
        #expect(Set(desktop.keys) == ["display", "connected", "current", "label", "stampMissing"])
        #expect(desktop["label"] as? String == "Email")
    }

    @Test func aMissingLabelIsAnExplicitNull() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let json = try Reports.json(Reports.list(try h.labeler.listDesktops()))
        let desktop = try #require((try object(json)["desktops"] as? [[String: Any]])?.first)
        #expect(desktop["label"] is NSNull)
    }

    @Test func showJSONMatchesTheContract() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), options: LabelOptions(look: .frosted), on: h.display)
        let root = try object(try Reports.json(Reports.show(try h.labeler.showLabel(on: h.display))))
        #expect(Set(root.keys) == ["display", "labeled", "label", "createdAt", "originalRecorded", "stampMissing"])
        let label = try #require(root["label"] as? [String: Any])
        #expect(Set(label.keys) == ["text", "look", "textColor", "position", "size", "automatic"])
        #expect(label["look"] as? String == "frosted")
        #expect(label["automatic"] as? [String] == ["textColor"])
        #expect((root["createdAt"] as? String)?.hasSuffix("Z") == true)
    }

    @Test func showOnAnUnlabeledDesktopHasNullLabelAndDate() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let root = try object(try Reports.json(Reports.show(try h.labeler.showLabel(on: h.display))))
        #expect(root["labeled"] as? Bool == false)
        #expect(root["label"] is NSNull && root["createdAt"] is NSNull)
    }

    @Test func displaysJSONMatchesTheContract() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let json = try Reports.json(Reports.displays(try h.system.displays()))
        let list = try #require(try object(json)["displays"] as? [[String: Any]])
        #expect(list.count == 1)
        #expect(list[0]["name"] as? String == "Built-in Display")
        #expect(list[0]["isMain"] as? Bool == true)
    }

    @Test func displaysJSONListsActiveAliasesAndAnEmptyArrayOtherwise() throws {
        let h = try LabelerHarness(extraDisplays: [FakeWallpaperSystem.makeDisplay(name: "LG Ultra HD", uuid: "DISPLAY-B", isMain: false)])
        defer { h.cleanUp() }
        try h.labeler.setAlias("work", display: "LG")
        try h.labeler.setAlias("DP1", display: "LG")
        let json = try Reports.json(Reports.displays(try h.system.displays(), aliases: try h.labeler.aliases()))
        let list = try #require(try object(json)["displays"] as? [[String: Any]])
        let byName = Dictionary(uniqueKeysWithValues: list.map { ($0["name"] as! String, $0["aliases"] as! [String]) })
        #expect(byName["LG Ultra HD"] == ["DP1", "work"])
        #expect(byName["Built-in Display"] == [])
        #expect(!json.contains("DISPLAY-"))
    }

    @Test func aliasesJSONIsOneObjectWithoutIdentifiers() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.labeler.setAlias("desk", display: nil)
        let json = try Reports.json(Reports.aliases(try h.labeler.listAliases()))
        let list = try #require(try object(json)["aliases"] as? [[String: Any]])
        #expect(list.count == 1)
        #expect(Set(list[0].keys) == ["name", "display", "connected", "isMain", "overridden"])
        #expect(!json.contains("DISPLAY-A"))
    }

    @Test func reportsNeverContainIdentifiersOrPaths() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("Email"), on: h.display)
        let all = try Reports.json(Reports.list(try h.labeler.listDesktops()))
            + (try Reports.json(Reports.show(try h.labeler.showLabel(on: h.display))))
            + (try Reports.json(Reports.displays(try h.system.displays())))
        #expect(!all.contains("DISPLAY-A"))
        #expect(!all.contains(h.root.path))
        #expect(!all.contains(".dnm."))
        #expect(!all.contains("/tmp") && !all.contains("/var/"))
    }

    @Test func customColorsPrintAsHex() {
        #expect(TextColor.custom(red: 1, green: 128.0 / 255, blue: 0).description == "#FF8000")
        #expect(TextColor.light.description == "light")
    }
}
