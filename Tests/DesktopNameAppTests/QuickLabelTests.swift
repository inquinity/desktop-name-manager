import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// The main window's label field (spec 014, T033, data-model.md QuickLabel, FR-013a).
@MainActor
@Suite struct QuickLabelTests {
    final class Recorder {
        var applied: [(LabelText, LabelOptions)] = []
    }

    func quick(label: Label?, defaults: LabelOptions = LabelOptions(), recorder: Recorder) -> QuickLabel {
        let display = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true)
        return QuickLabel(display: display, currentLabel: label, defaults: defaults) { recorder.applied.append(($0, $1)) }
    }

    @Test func aNewLabelGetsTheDefaults() async throws {
        let recorder = Recorder()
        let defaults = LabelOptions(look: .halo, textColor: .dark, position: .top, size: .small)
        let quick = quick(label: nil, defaults: defaults, recorder: recorder)
        #expect(quick.text.isEmpty && !quick.canApply && quick.message == nil)
        quick.setText("Mail")
        await quick.apply()
        #expect(recorder.applied.map(\.1) == [defaults])
        #expect(quick.state == .closed)
    }

    @Test func aRelabelKeepsTheLabelsOptions() async throws {
        let recorder = Recorder()
        let label = Label(text: try LabelText("Mail"), look: .frosted, textColor: .light, position: .bottomRight, size: .large,
                          automatic: [.textColor])
        let quick = quick(label: label, defaults: LabelOptions(look: .plain), recorder: recorder)
        #expect(quick.text == "Mail")
        #expect(!quick.canApply)   // unchanged
        quick.setText("Mail and calendar")
        await quick.apply()
        #expect(recorder.applied.first?.1 == LabelOptions(look: .frosted, textColor: nil, position: .bottomRight, size: .large))
    }

    @Test func invalidTextKeepsLabelOffWithTheEditorsSentence() {
        let quick = quick(label: nil, recorder: Recorder())
        quick.setText("Quarterly planning and budget review")
        #expect(!quick.canApply)
        #expect(quick.message == "A label can have at most 30 characters; this one has 36.")
        quick.setText("Line\none")
        #expect(quick.text == "Lineone" && quick.canApply && quick.message == nil)
    }

    @Test func theResultEqualsSetLabel() async throws {
        let app = try AppRig(), cli = try AppRig()
        let defaults = LabelOptions(look: .plain, position: .bottom)
        let quick = QuickLabel(display: app.display, currentLabel: nil, defaults: defaults) { text, options in
            try app.controller.apply(text, options: options, on: app.display)
        }
        quick.setText("Mail")
        await quick.apply()
        try cli.labeler.setLabel(LabelText("Mail"), options: defaults, on: cli.display)
        #expect(try app.labeler.currentLabel(on: app.display) == cli.labeler.currentLabel(on: cli.display))
        #expect(try app.shownBytes() == cli.shownBytes())
    }
}
