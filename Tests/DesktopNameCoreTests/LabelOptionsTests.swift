import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct LabelOptionsTests {
    @Test func omittedOptionsStayAutomaticOrDefault() throws {
        let options = try LabelOptions.parse(style: nil, color: nil, position: nil, size: nil)
        #expect(options == LabelOptions())
        #expect(Position.default == .bottomLeft)
        #expect(Size.default == .medium)
    }

    @Test func acceptedValuesParse() throws {
        let options = try LabelOptions.parse(style: "Halo", color: "dark", position: "top-right", size: "large")
        #expect(options == LabelOptions(look: .halo, textColor: .dark, position: .topRight, size: .large))
        #expect(try LabelOptions.parse(style: nil, color: "light", position: "bottom", size: "small").textColor == .light)
    }

    @Test func hexColorsParse() throws {
        guard case .custom(let red, let green, let blue)? = try LabelOptions.parse(style: nil, color: "#FF8000", position: nil, size: nil).textColor else {
            Issue.record("expected a custom color"); return
        }
        #expect(red == 1 && abs(green - 128.0 / 255) < 0.0001 && blue == 0)
    }

    @Test(arguments: [("frost", nil, nil, nil), (nil, "red", nil, nil), (nil, "#12", nil, nil), (nil, "#GGGGGG", nil, nil),
                      (nil, nil, "middle", nil), (nil, nil, nil, "huge")] as [(String?, String?, String?, String?)])
    func invalidValuesAreRejectedWithTheAcceptedChoices(_ style: String?, _ color: String?, _ position: String?, _ size: String?) {
        do {
            _ = try LabelOptions.parse(style: style, color: color, position: position, size: size)
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect((error.errorDescription ?? "").contains("Use"))
        } catch { Issue.record("wrong error") }
    }

    @Test func explicitChoicesReachTheLabelAndAreNotAutomatic() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        let options = try LabelOptions.parse(style: "frosted", color: "#102030", position: "top-left", size: "small")
        let result = try h.labeler.setLabel(LabelText("Email"), options: options, on: h.display)
        #expect(result.label.look == .frosted)
        #expect(result.label.position == .topLeft)
        #expect(result.label.size == .small)
        #expect(result.label.automatic.isEmpty)
        if case .custom = result.label.textColor {} else { Issue.record("expected the custom color") }
    }

    @Test func aFailedParseChangesNothing() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        #expect(throws: DnmError.self) { try LabelOptions.parse(style: "nope", color: nil, position: nil, size: nil) }
        #expect(h.system.setCalls.isEmpty)
    }
}
