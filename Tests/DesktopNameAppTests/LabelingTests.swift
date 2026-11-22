import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// Apply, Remove and Undo through the app's models give what `dnm` gives (spec 014, T029, FR-007, SC-003).
@MainActor
@Suite struct LabelingTests {
    /// What a store holds, without the random identities: each stamp's label and state, the change records' kinds, and
    /// the image bytes showing.
    struct Outcome: Equatable {
        var stamps: [String]
        var changes: [String]
        var shown: Data?
    }

    static func outcome(_ rig: AppRig) throws -> Outcome {
        let manifest = try rig.store.readManifest()
        return Outcome(stamps: manifest.stamps.map { stamp in
                           let label = stamp.label
                           return "\(label.text.value) \(label.look) \(label.textColor) \(label.position) \(label.size) "
                               + "\(label.automatic.map(\.rawValue).sorted()) \(stamp.isActive)"
                       },
                       changes: manifest.changes.map { "\($0.kind) \($0.at)" },
                       shown: try rig.shownBytes())
    }

    static let options = LabelOptions(look: .frosted, textColor: .light, position: .topRight, size: .large)

    func editor(_ rig: AppRig, settings: AppSettings) async -> EditorDraft {
        let display = rig.display, controller = rig.controller
        let draft = EditorDraft(display: display, currentLabel: try? rig.labeler.currentLabel(on: display),
                                defaults: settings.newLabelOptions, actions: EditorActions(
                                    apply: { text, options in try controller.apply(text, options: options, on: display) },
                                    remove: { try controller.remove(on: display) }), previewWidth: 200, chipWidth: 80)
        await draft.load { try rig.labeler.previewOrigin(on: display) }
        return draft
    }

    @Test func applyFromTheEditorEqualsSetLabel() async throws {
        let app = try AppRig(), cli = try AppRig()
        let draft = await editor(app, settings: app.settings())
        draft.setText("Q4 budget")
        draft.setStyle(.frosted); draft.setColor(.light); draft.setPosition(.topRight); draft.setSize(.large)
        await draft.apply()
        try cli.labeler.setLabel(LabelText("Q4 budget"), options: Self.options, on: cli.display)
        #expect(draft.state == .closed)
        #expect(try Self.outcome(app) == Self.outcome(cli))
    }

    @Test func applyFromTheMainWindowEqualsSetLabelWithTheDefaults() async throws {
        let app = try AppRig(), cli = try AppRig()
        let settings = app.settings()
        settings.defaultLook = .halo
        settings.defaultPosition = .top
        let main = MainWindowModel(display: app.display, controller: app.controller, settings: settings, actions: Self.noActions)
        main.quick.setText("Mail")
        await main.quick.apply()
        try cli.labeler.setLabel(LabelText("Mail"), options: LabelOptions(look: .halo, position: .top, size: .medium), on: cli.display)
        #expect(main.quick.state == .closed)
        #expect(try Self.outcome(app) == Self.outcome(cli))
    }

    @Test func removeAndUndoEqualTheCoreCalls() async throws {
        let app = try AppRig(), cli = try AppRig()
        for rig in [app, cli] { try rig.labeler.setLabel(LabelText("Mail"), options: Self.options, on: rig.display) }
        app.clock.advance(seconds: 5); cli.clock.advance(seconds: 5)

        let main = MainWindowModel(display: app.display, controller: app.controller, settings: app.settings(), actions: Self.noActions)
        await main.remove()
        try cli.labeler.removeLabel(on: cli.display)
        #expect(try Self.outcome(app) == Self.outcome(cli))

        let again = MainWindowModel(display: app.display, controller: app.controller, settings: app.settings(), actions: Self.noActions)
        #expect(again.state.undo?.title == "Undo Remove on Built-in Display")
        await again.undo()
        try cli.labeler.undoLastChange(on: cli.display)
        #expect(try Self.outcome(app) == Self.outcome(cli))
        #expect(try app.labeler.currentLabel(on: app.display)?.text.value == "Mail")
    }

    @Test func aChangeMadeWithDnmIsUndoableForSixtySeconds() throws {
        let rig = try AppRig()
        try rig.labeler.setLabel(LabelText("Mail"), on: rig.display)   // what `dnm set` does
        rig.clock.advance(seconds: 30)
        #expect(rig.controller.undoOffer(on: rig.display)?.title == "Undo Label on Built-in Display")
        rig.clock.advance(seconds: 31)
        #expect(rig.controller.undoOffer(on: rig.display) == nil)
        #expect(throws: DnmError.self) { try rig.controller.undo(on: rig.display) }
    }

    @Test func invalidTextShowsTheSentenceAndKeepsApplyOff() async throws {
        let rig = try AppRig()
        let main = MainWindowModel(display: rig.display, controller: rig.controller, settings: rig.settings(), actions: Self.noActions)
        main.quick.setText("Quarterly planning and budget review")
        #expect(!main.quick.canApply)
        #expect(main.quick.message == "A label can have at most 30 characters; this one has 36.")
        main.quick.setText("")
        #expect(!main.quick.canApply && main.quick.message == nil)
        let draft = await editor(rig, settings: rig.settings())
        draft.setText("Quarterly planning and budget review")
        #expect(!draft.canApply && draft.message == "A label can have at most 30 characters; this one has 36.")
    }

    @Test func anUnsupportedWallpaperHasNoApply() async throws {
        let rig = try AppRig()
        rig.system.show(try SyntheticImages.writeMultiFrame(to: rig.root.appendingPathComponent("Dynamic.tiff")), on: rig.display)
        let draft = await editor(rig, settings: rig.settings())
        #expect(draft.state == .unsupported && draft.message == "Dynamic wallpapers are not supported.")
        draft.setText("Mail")
        #expect(!draft.canApply)
    }

    @Test func aFailureLeavesTheWallpaperAndTheManifestAsTheyWere() async throws {
        let rig = try AppRig()
        try rig.labeler.setLabel(LabelText("Mail"), on: rig.display)
        // Compared decoded: a set (the automatic options) is written in no fixed order.
        let before = try rig.store.readManifest(), shown = try rig.system.currentWallpaper(on: rig.display)
        rig.system.setError = DnmError.failure("The wallpaper could not be set.")
        let main = MainWindowModel(display: rig.display, controller: rig.controller, settings: rig.settings(), actions: Self.noActions)
        main.quick.setText("Calendar")
        await main.quick.apply()
        #expect(main.quick.state == .ready)
        #expect(main.quick.message != nil)
        #expect(try rig.store.readManifest() == before)
        #expect(try rig.system.currentWallpaper(on: rig.display) == shown)
    }

    @Test func closingTheWindowWhileWorkingMakesNoChange() async throws {
        let rig = try AppRig()
        let main = MainWindowModel(display: rig.display, controller: rig.controller, settings: rig.settings(), actions: Self.noActions)
        main.quick.setText("Mail")
        let applying = Task { await main.quick.apply() }
        await Self.waitUntil { main.quick.state == .applying }   // the working state is showing
        main.close()   // a click outside before the change is made
        await applying.value
        #expect(rig.system.setCalls.isEmpty && !FileManager.default.fileExists(atPath: rig.store.manifestURL.path))

        let draft = await editor(rig, settings: rig.settings())
        draft.setText("Mail")
        let editorApplying = Task { await draft.apply() }
        await Self.waitUntil { draft.state == .applying }
        draft.cancel()
        await editorApplying.value
        #expect(rig.system.setCalls.isEmpty && draft.state == .closed && !draft.changed)
    }

    /// Lets other main-actor work run until `condition` holds (at most 2 s).
    static func waitUntil(_ condition: @MainActor () -> Bool) async {
        // Yields only: a sleep, with the timer's slack, could outlast the ~16 ms working state.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if condition() { return }
            await Task.yield()
        }
        Issue.record("the condition did not hold within 2 s")
    }

    static let noActions = MainWindowActions(openEditor: {}, openSettings: { _ in }, quit: {}, close: {})
}
