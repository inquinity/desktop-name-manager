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
