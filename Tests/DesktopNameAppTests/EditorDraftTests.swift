import CoreGraphics
import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// The editor's model (spec 014, data-model.md EditorDraft), over the fake wallpaper system and a temporary store.
@MainActor
@Suite struct EditorDraftTests {
    final class Rig {
        let root: URL
        let display = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true, width: 800, height: 500, scale: 1)
        let system: FakeWallpaperSystem
        let labeler: DesktopLabeler
        var applied: [(LabelText, LabelOptions)] = []
        var removed = 0
        var failApply: Error?

        init(wallpaper: CGImage? = SyntheticImages.gradient()) throws {
            root = try SyntheticImages.temporaryDirectory()
            system = FakeWallpaperSystem(displays: [display])
            labeler = DesktopLabeler(system: system, store: Store(directory: root.appendingPathComponent("store", isDirectory: true)))
            if let wallpaper {
                system.show(try SyntheticImages.write(wallpaper, to: root.appendingPathComponent("wallpaper.png")), on: display)
            }
        }

        deinit { try? FileManager.default.removeItem(at: root) }

        @MainActor func draft(defaults: LabelOptions = LabelOptions()) async throws -> EditorDraft {
            let current = try labeler.currentLabel(on: display)
            let draft = EditorDraft(display: display, currentLabel: current, defaults: defaults, actions: EditorActions(
                apply: { [self] text, options in
                    if let failApply { throw failApply }
                    applied.append((text, options))
                    try labeler.setLabel(text, options: options, on: display)
                },
                remove: { [self] in removed += 1; try labeler.removeLabel(on: display) }), previewWidth: 400, chipWidth: 120)
            await draft.load { try labeler.previewOrigin(on: display) }
            return draft
        }
    }

    /// Waits until no render is running, so the newest request has been delivered (at most 10 s).
    func settle(_ draft: EditorDraft) async throws {
        for _ in 0..<1_000 {
            try await Task.sleep(for: .milliseconds(10))
            if !draft.isRendering { return }
        }
        Issue.record("the preview did not finish rendering within 10 s")
    }

    @Test func anUnlabeledDesktopStartsEmptyWithTheDefaultsAndApplyOff() async throws {
        let rig = try Rig()
        let draft = try await rig.draft(defaults: LabelOptions(look: .halo, position: .top, size: .large))
        #expect(draft.text.isEmpty)
        #expect(draft.style == .halo && draft.position == .top && draft.size == .large)
        #expect(draft.state == .invalid && draft.message == nil && !draft.canApply && !draft.canRemove)
        #expect(draft.preview != nil)   // the bare wallpaper
    }

    @Test func aLabeledDesktopStartsFromItsLabel() async throws {
        let rig = try Rig()
        try rig.labeler.setLabel(LabelText("Q4 budget"), options: LabelOptions(look: .frosted, position: .topRight, size: .small), on: rig.display)
        let draft = try await rig.draft(defaults: LabelOptions(look: .halo))
        #expect(draft.text == "Q4 budget")
        #expect(draft.style == .frosted && draft.color == nil && draft.position == .topRight && draft.size == .small)
        #expect(draft.canApply && draft.canRemove)
    }

    @Test func lineBreaksAndControlCharactersAreLeftOut() async throws {
        let draft = try await Rig().draft()
        draft.setText("Budget\tNo\ntes\u{202E}")
        #expect(draft.text == "BudgetNotes")
        #expect(draft.state == .ready && draft.message == nil)
    }

    @Test func tooLongTurnsApplyOffWithTheSentence() async throws {
        let draft = try await Rig().draft()
        draft.setText("Quarterly planning and budget review")
        #expect(draft.state == .invalid && !draft.canApply)
        #expect(draft.message == "A label can have at most 30 characters; this one has 36.")
        draft.setText("Q4 budget")
        #expect(draft.state == .ready && draft.message == nil)
    }

    @Test func clearingTheFieldSaysNothing() async throws {
        let draft = try await Rig().draft()
        draft.setText("Q4")
        draft.setText("   ")
        #expect(draft.state == .invalid && draft.message == nil)
    }

    @Test func applyLabelsTheDesktopOnceAndCloses() async throws {
        let rig = try Rig()
        let draft = try await rig.draft()
        draft.setText("Q4 budget")
        draft.setStyle(.frosted)
        await draft.apply()
        await draft.apply()   // a second press after closing does nothing
        #expect(rig.applied.count == 1)
        #expect(rig.applied.first?.1 == LabelOptions(look: .frosted, position: .bottomLeft, size: .medium))
        #expect(draft.state == .closed)
        #expect(try rig.labeler.currentLabel(on: rig.display)?.look == .frosted)
    }

    @Test func aFailedApplyKeepsTheEditorOpenWithTheSentence() async throws {
        let rig = try Rig()
        rig.failApply = DnmError.newerManifest(found: 4, supported: 3)
        let draft = try await rig.draft()
        draft.setText("Q4 budget")
        await draft.apply()
        #expect(draft.state == .ready)
        #expect(draft.message == "The stored data is format 4, newer than this app understands (3). Update the app. Nothing was changed.")
        #expect(rig.system.setCalls.isEmpty)
    }

    @Test func removeIsOfferedOnlyWithALabel() async throws {
        let rig = try Rig()
        try rig.labeler.setLabel(LabelText("Q4 budget"), on: rig.display)
        let draft = try await rig.draft()
        await draft.remove()
        #expect(rig.removed == 1 && draft.state == .closed)
        #expect(try rig.labeler.currentLabel(on: rig.display) == nil)

        let fresh = try await rig.draft()
        await fresh.remove()
        #expect(rig.removed == 1)
    }

    @Test func anUnsupportedWallpaperHasItsSentenceAndNoApply() async throws {
        let rig = try Rig(wallpaper: nil)
        let url = try SyntheticImages.writeMultiFrame(to: rig.root.appendingPathComponent("Dynamic.tiff"))
        rig.system.show(url, on: rig.display)
        let draft = try await rig.draft()
        #expect(draft.state == .unsupported)
        #expect(draft.message == "Dynamic wallpapers are not supported.")
        draft.setText("Q4 budget")
        #expect(!draft.canApply)
    }

    @Test func noWallpaperFile() async throws {
        let rig = try Rig(wallpaper: nil)
        let draft = try await rig.draft()
        #expect(draft.state == .unsupported && draft.message == "This Desktop has no wallpaper picture to label.")
    }

    @Test func cancelClosesWithNoChange() async throws {
        let rig = try Rig()
        let draft = try await rig.draft()
        draft.setText("Q4 budget")
        draft.cancel()
        #expect(draft.state == .closed && rig.applied.isEmpty && rig.system.setCalls.isEmpty)
    }

    @Test func thePreviewAndChipsRenderAndAutomaticSaysWhatItPicks() async throws {
        let rig = try Rig(wallpaper: SyntheticImages.noise())
        let draft = try await rig.draft()
        draft.setText("Q4 budget")
        try await settle(draft)
        #expect(draft.chips.count == 4)
        #expect(draft.preview?.width == 400)
        let applied = try rig.labeler.setLabel(LabelText("Q4 budget"), on: rig.display)
        #expect(draft.automaticLook == applied.label.look)
    }

    @Test func rapidChangesEndWithTheNewestRequest() async throws {
        let rig = try Rig()
        let draft = try await rig.draft()
        for text in ["Q", "Q4", "Q4 b", "Q4 bu", "Q4 budget"] { draft.setText(text) }
        draft.setStyle(.plain)
        try await settle(draft)
        // The preview on screen is the newest request: Plain, "Q4 budget".
        let expected = try LabelPreview.render(PreviewRequest(text: LabelText("Q4 budget"), options: draft.options, maxPixelWidth: 400),
                                               source: rig.labeler.previewSource(on: rig.display, maxPixelWidth: 400)).image
        #expect(Self.same(draft.preview, expected))
    }

    static func same(_ a: CGImage?, _ b: CGImage) -> Bool {
        guard let a, a.width == b.width, a.height == b.height,
              let da = a.dataProvider?.data, let db = b.dataProvider?.data else { return false }
        return (da as Data) == (db as Data)
    }
}
