import DesktopNameApp
import DesktopNameCore
import DNMTestSupport
import Foundation
import Testing

/// The main window's state (T039), Clean Up (T048), the Displays pane (T051) and the values the panes share with
/// `dnm about`, `dnm check` and `dnm list` (T051).
@MainActor
@Suite struct MenuBarStateTests {
    static let main = FakeWallpaperSystem.makeDisplay(name: "Studio Display", uuid: "DISPLAY-A", isMain: true, width: 800, height: 500, scale: 1)
    static let side = FakeWallpaperSystem.makeDisplay(name: "Side Display", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)

    @Test func theItemsTitleIsTheFixedTextAndNeverTheLabel() throws {
        #expect(MenuBarState.itemTitle(for: .iconAndText) == "dnm")
        #expect(MenuBarState.itemTitle(for: .icon) == nil)
        #expect(MenuBarState.itemTitle(for: .hidden) == nil)
        #expect(AppInfo.displayName == "Desktop Name Manager")   // the item's accessibility label
    }

    @Test func eachDisplayGetsItsOwnLabel() throws {
        let rig = try AppRig(displays: [Self.main, Self.side])
        try rig.labeler.setLabel(LabelText("Mail"), on: Self.side)
        #expect(MenuBarState.read(for: Self.side, controller: rig.controller).currentLabel?.text.value == "Mail")
        let other = MenuBarState.read(for: Self.main, controller: rig.controller)
        #expect(other.currentLabel == nil && other.undo == nil)
    }

    @Test func aStampFromAnotherStoreGivesNoLabel() throws {
        let rig = try AppRig()
        let foreign = rig.root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: foreign, withIntermediateDirectories: true)
        let file = foreign.appendingPathComponent("\(UUID().uuidString).dnm.png")
        try FileManager.default.copyItem(at: rig.wallpaper, to: file)
        rig.system.show(file, on: rig.display)
        #expect(MenuBarState.read(for: rig.display, controller: rig.controller).currentLabel == nil)
    }

    @Test func whichDisplay() {
        let displays = [Self.main, Self.side]
        #expect(MenuBarState.targetDisplay(chosen: Self.side, displays: displays, separateSpaces: true) == Self.side)
        // Separate Spaces off: one Desktop spans every display, so the main one is used.
        #expect(MenuBarState.targetDisplay(chosen: Self.side, displays: displays, separateSpaces: false) == Self.main)
        // A screen that is gone: the main display.
        #expect(MenuBarState.targetDisplay(chosen: nil, displays: displays, separateSpaces: true) == Self.main)
    }

    @Test func aFullScreenAppsSpaceShowsTheStampItReportsElseNoLabel() throws {
        let rig = try AppRig()
        try rig.labeler.setLabel(LabelText("Mail"), on: rig.display)
        // A full-screen app's Space reports the wallpaper of the Desktop beside it: the stamp's label, never a guess.
        #expect(MenuBarState.read(for: rig.display, controller: rig.controller).currentLabel?.text.value == "Mail")
        rig.system.show(nil, on: rig.display)
        let none = MenuBarState.read(for: rig.display, controller: rig.controller)
        #expect(none.currentLabel == nil)
    }

    @Test func theMainWindowFollowsAStoreChange() throws {
        let rig = try AppRig()
        let model = MainWindowModel(display: rig.display, controller: rig.controller, settings: rig.settings(), actions: LabelingTests.noActions)
        #expect(model.state.currentLabel == nil && model.quick.text.isEmpty)
        try rig.labeler.setLabel(LabelText("Mail"), on: rig.display)   // `dnm set` meanwhile
        model.storeChanged()
        #expect(model.state.currentLabel?.text.value == "Mail" && model.quick.text == "Mail")
        #expect(model.state.undo?.title == "Undo Label on Built-in Display")
    }
}

@MainActor
@Suite struct CleanUpTests {
    /// Labels "Old" then replaces it with "New", and moves the clock past `days`.
    func rigWithAnOldImage(days: Double = 31) throws -> AppRig {
        let rig = try AppRig()
        try rig.labeler.setLabel(LabelText("Old"), on: rig.display)
        try rig.labeler.setLabel(LabelText("New"), on: rig.display)
        rig.clock.advance(minutes: days * 24 * 60)
        return rig
    }

    @Test func theListEqualsDnmCleanups() throws {
        let rig = try rigWithAnOldImage()
        let model = CleanUpModel(labeler: rig.labeler)
        model.refresh(days: 30)
        #expect(model.candidates == (try rig.labeler.cleanupPlan(days: 30)).candidates)
        #expect(model.candidates.map(\.label) == ["Old"] && model.candidates.first?.reason.phrase == "Replaced")
        model.refresh(days: 60)
        #expect(model.candidates.isEmpty)
    }

    @Test func nothingIsDeletedBeforeConfirmingAndOnlyTheSelection() throws {
        let rig = try rigWithAnOldImage()
        let model = CleanUpModel(labeler: rig.labeler)
        model.refresh(days: 30)
        #expect(!model.canDelete)
        model.deleteSelected()   // nothing selected: nothing happens
        #expect(try rig.store.readManifest().stamps.count == 2)
        model.selectAll(true)
        #expect(model.allSelected && model.confirmation.hasPrefix("Delete 1 old labeled image ("))
        model.deleteSelected()
        #expect(model.deleted?.candidates.map(\.label) == ["Old"])
        #expect(try rig.store.readManifest().stamps.map(\.label.text.value) == ["New"])
        #expect(model.candidates.isEmpty && model.selection.isEmpty)
    }

    @Test func anImagePutBackOnScreenMeanwhileIsKept() throws {
        let rig = try rigWithAnOldImage()
        let model = CleanUpModel(labeler: rig.labeler)
        model.refresh(days: 30)
        model.selectAll(true)
        let old = try rig.store.readManifest().stamps.first { $0.label.text.value == "Old" }!
        rig.system.show(rig.store.fileURL(named: old.fileName), on: rig.display)   // showing again
        model.deleteSelected()
        #expect(model.deleted?.candidates.isEmpty == true)
        #expect(try rig.store.readManifest().stamps.count == 2)
    }

    @Test func theWarningIsAtFiftyMegabytes() {
        #expect(!StorageSummary(labelsInUse: 1, displaysWithLabels: 1, spaceUsed: 90_000_000, oldImages: 49_999_999).cleanUpWarning)
        #expect(StorageSummary(labelsInUse: 1, displaysWithLabels: 1, spaceUsed: 90_000_000, oldImages: 50_000_000).cleanUpWarning)
    }

    @Test func theStorageFiguresCountWhatIsThere() throws {
        let rig = try rigWithAnOldImage()
        let summary = try StorageSummary.read(rig.labeler, days: 30)
        #expect(summary.labelsInUse == 1 && summary.displaysWithLabels == 1)
        #expect(summary.oldImages > 0 && summary.spaceUsed > summary.oldImages)
    }
}

@MainActor
@Suite struct DisplaysPaneTests {
    @Test func addMoveAndRemove() throws {
        let rig = try AppRig(displays: [MenuBarStateTests.main, MenuBarStateTests.side])
        let model = DisplaysModel(labeler: rig.labeler)
        model.refresh()
        #expect(model.rows.map(\.display.name) == ["Studio Display", "Side Display"])
        model.add("desk", to: MenuBarStateTests.main)
        #expect(model.rows[0].aliases == ["desk"] && model.note == nil)
        model.add("desk", to: MenuBarStateTests.side)
        #expect(model.rows[0].aliases.isEmpty && model.rows[1].aliases == ["desk"])
        #expect(model.note?.text == "desk moved here from Studio Display." && model.note?.isError == false)
        model.remove("desk", from: MenuBarStateTests.side)
        #expect(model.rows.allSatisfy { $0.aliases.isEmpty })
        #expect(try rig.labeler.aliases().isEmpty)
    }

    @Test func refusalsUseTheCoresSentencesWithoutTheOptionClause() throws {
        let rig = try AppRig(displays: [MenuBarStateTests.main, MenuBarStateTests.side])
        let model = DisplaysModel(labeler: rig.labeler)
        model.refresh()
        model.add("123", to: MenuBarStateTests.main)
        #expect(model.note?.text == "An alias cannot be only digits." && model.note?.isError == true)
        for name in ["Side Display", "main", String(repeating: "a", count: 31)] {
            model.add(name, to: MenuBarStateTests.main)
            let note = model.note?.text ?? ""
            #expect(model.note?.isError == true && !note.isEmpty, "\(name)")
            #expect(!note.contains("--") && !note.contains("dnm"), "\(note)")
        }
        #expect(try rig.labeler.aliases().isEmpty)
    }
}

@MainActor
@Suite struct AboutConfigurationTests {
    static let machine = Configuration(macOSVersion: "Version 26.1 (Build 25B78)", chip: "Apple M4", displaysHaveSeparateSpaces: true,
                                       accessibilityGranted: false)

    @Test func theSharedValuesMatchDnmCheckAndAbout() throws {
        let rig = try AppRig()
        let summary = ConfigurationSummary.read(rig.labeler, configuration: Self.machine)
        let report = rig.labeler.check(Self.machine)
        #expect(summary.macOS == report.items.first { $0.name == "macOS" }?.detail)
        #expect(summary.separateSpaces == (report.items.first { $0.name == "Separate Spaces" }?.state == .ok))
        #expect(summary.dataFolder == About.info(dataDirectory: rig.store.directory).dataDirectory)
        #expect(summary.displayCount == 1)

        var shared = Self.machine
        shared.displaysHaveSeparateSpaces = false
        #expect(!ConfigurationSummary.read(rig.labeler, configuration: shared).separateSpaces)
    }

    @Test func theLabelsPaneListsWhatDnmListLists() throws {
        let rig = try AppRig(displays: [MenuBarStateTests.main, MenuBarStateTests.side])
        try rig.labeler.setLabel(LabelText("Mail"), on: MenuBarStateTests.main)
        try rig.labeler.setLabel(LabelText("Code"), on: MenuBarStateTests.side)
        let labels = try LabelInUse.read(rig.labeler)
        let listed = try rig.labeler.listDesktops().entries.filter { $0.label != nil }
        #expect(labels.map(\.label) == listed.map { $0.label! })
        #expect(labels.map(\.displayName) == listed.map(\.displayName))
        #expect(labels.allSatisfy { $0.bytes > 0 })
    }

    @Test func theAcknowledgementsMatchWhatShips() throws {
        #expect(AppAcknowledgement.all.map(\.name) == About.acknowledgements.map(\.name))
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for component in AppAcknowledgement.all {
            #expect(!component.authors.isEmpty && !component.license.contains(" "))   // an SPDX identifier
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Licenses/\(component.licenseFile)").path))
        }
    }

    @Test func settingsReadOpenAtLoginEachTimeGeneralIsShown() throws {
        let rig = try AppRig()
        let login = FakeLoginItem()
        let model = SettingsModel(settings: rig.settings(), labeler: rig.labeler, loginItem: login,
                                  hotkey: HotkeySetting(settings: rig.settings(), registrar: FakeRegistrar()), machine: { Self.machine })
        model.show(.general)
        #expect(!model.opensAtLogin)
        login.isEnabled = true   // turned on elsewhere
        model.show(.general)
        #expect(model.opensAtLogin)
        model.setOpensAtLogin(false)
        #expect(!login.isEnabled && !model.opensAtLogin)
        login.failure = DnmError.failure("Not allowed.")
        model.setOpensAtLogin(true)
        #expect(!model.opensAtLogin && model.message != nil)
    }
}
