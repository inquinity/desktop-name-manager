import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct AboutTests {
    @Test func aboutStatesVersionDataAndPermissions() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let info = About.info(dataDirectory: home.appendingPathComponent("Library/Application Support/x"), version: "1.2.3")
        #expect(info.version == "1.2.3")
        #expect(info.license == "MIT")
        #expect(info.dataDirectory == "~/Library/Application Support/x")
        #expect(info.permissions.contains { $0.contains("needs no permissions") })
        #expect(info.permissions.contains { $0.contains("Accessibility") && $0.contains("Move left a space") })
        #expect(info.permissions.contains { $0.contains("No network") && $0.contains("telemetry") })
        #expect(info.permissions.contains { $0.contains("every program run in that app") })
    }
}

@Suite struct CheckTests {
    static let ready = Configuration(macOSVersion: "Version 26.0 (Build 25A1)", chip: "Apple M1", displaysHaveSeparateSpaces: true, accessibilityGranted: true)

    func item(_ name: String, in report: CheckReport) throws -> CheckItem {
        try #require(report.items.first { $0.name == name })
    }

    @Test func aReadyMacHasNothingToFixExceptWhatCannotBeRead() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let report = h.labeler.check(Self.ready)
        #expect(report.items.map(\.name) == ["macOS", "Separate Spaces", "Displays", "Accessibility", "Space shortcuts", "First Desktop", "Stored labels"])
        #expect(report.items.allSatisfy { $0.state != .attention })
        #expect(try item("Space shortcuts", in: report).state == .unknown)
        #expect(try item("Displays", in: report).detail == "Built-in Display (main)")
        #expect(try item("macOS", in: report).detail.contains("Apple M1"))
    }

    @Test func missingSettingsSayHowToFixThem() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        var configuration = Self.ready
        configuration.displaysHaveSeparateSpaces = false
        configuration.accessibilityGranted = false
        let report = h.labeler.check(configuration)
        let spaces = try item("Separate Spaces", in: report)
        #expect(spaces.state == .attention && spaces.fix?.contains("Displays have separate Spaces") == true)
        let access = try item("Accessibility", in: report)
        #expect(access.state == .attention && access.fix?.contains("Privacy & Security > Accessibility (macOS 26)") == true
            && access.fix?.contains("Device Control and Data Access (macOS 27)") == true)
        #expect(access.detail.contains("Only --desktop needs it"))
        #expect(access.detail.contains("every program run in that app"))
    }

    @Test func storedLabelsCountWhatPruneCouldFree() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("One"), on: h.display)
        try h.labeler.setLabel(LabelText("Two"), on: h.display)
        let detail = try item("Stored labels", in: h.labeler.check(Self.ready)).detail
        #expect(detail.hasPrefix("1 active label, 2 labeled images"))
        #expect(detail.contains("`dnm prune` could free"))
    }

    @Test func checkChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        _ = h.labeler.check(Self.ready)
        #expect(!FileManager.default.fileExists(atPath: h.store.directory.path))
    }

    @Test func checkJSONHasAnExplicitNullFix() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let json = try Reports.json(h.labeler.check(Self.ready))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let first = try #require((root["items"] as? [[String: Any]])?.first)
        #expect(Set(first.keys) == ["name", "state", "detail", "fix"])
        #expect(first["fix"] is NSNull)
    }
}
