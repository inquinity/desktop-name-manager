import CoreGraphics
import DNMTestSupport
import Testing
@testable import DesktopNameCore

@Suite struct StylePickerTests {
    let geometry = DisplayGeometry(pointWidth: 800, pointHeight: 500, scale: 1, insetTop: 30, insetBottom: 60)

    func render(_ image: CGImage, options: LabelOptions = LabelOptions()) throws -> Legibility.Evaluation {
        try Legibility.evaluate(backdrop: image, text: LabelText("Status Report"), options: options, geometry: geometry)
    }

    @Test(arguments: [
        ("bright", SyntheticImages.bright()), ("dark", SyntheticImages.dark()), ("mid-gray", SyntheticImages.midGray()),
        ("gradient", SyntheticImages.gradient()), ("noise", SyntheticImages.noise()),
    ])
    func automaticStyleIsLegible(_ name: String, _ backdrop: CGImage) throws {
        let result = try render(backdrop)
        #expect(result.share >= Legibility.requiredShare, "\(name): \(result.share) of background pixels reach 3:1 (look \(result.label.look), \(result.label.textColor))")
    }

    @Test func choicesAreReportedAsAutomatic() throws {
        let rendered = try render(SyntheticImages.dark())
        #expect(rendered.label.automatic == [.look, .textColor])
        #expect(rendered.label.textColor == .light)
    }

    @Test func calmBrightBackdropGetsDarkPlainText() throws {
        let rendered = try render(SyntheticImages.bright())
        #expect(rendered.label.textColor == .dark)
        #expect(rendered.label.look == .plain)
    }

    @Test func busyBackdropGetsAFrostedBacking() throws {
        let rendered = try render(SyntheticImages.noise())
        #expect(rendered.label.look == .frosted)
    }

    @Test func explicitChoicesOverrideAndAreNotAutomatic() throws {
        let rendered = try render(SyntheticImages.dark(), options: LabelOptions(look: .halo, textColor: .dark))
        #expect(rendered.label.look == .halo)
        #expect(rendered.label.textColor == .dark)
        #expect(rendered.label.automatic.isEmpty)
    }

    @Test func theMeasureDetectsIllegibleText() throws {
        // Light text forced onto a bright backdrop must fail the legibility rule.
        let result = try render(SyntheticImages.bright(), options: LabelOptions(look: .plain, textColor: .light))
        #expect(result.share < Legibility.requiredShare)
    }
}
