import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 010: one change on several displays, in order, stopping at the first failure (FR-006, FR-009, SC-002).
@Suite struct DisplayBatchTests {
    let main = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "A", isMain: true)
    let dp = FakeWallpaperSystem.makeDisplay(name: "DP", uuid: "B", isMain: false)
    let side = FakeWallpaperSystem.makeDisplay(name: "Side", uuid: "C", isMain: false)

    func targets(_ displays: [Display], _ references: [String]) -> DisplayArguments.Targets {
        DisplayArguments.Targets(displays: displays, references: references, notice: nil)
    }

    func message(_ error: Error) -> String { (error as? DnmError)?.errorDescription ?? "\(error)" }

    // MARK: the helper on its own

    @Test func everyDisplayRunsInOrder() throws {
        var order: [String] = []
        try DisplayBatch.run(targets([main, dp, side], ["main", "DP", "Side"]), undoArguments: []) { display, changed in order.append(display.name); changed() }
        #expect(order == ["Built-in Display", "DP", "Side"])
    }

    @Test func aFailureOnTheFirstDisplayIsTheErrorUnchanged() {
        let error = DnmError.unsupportedWallpaper("dynamic")
        var attempted: [String] = []
        #expect(throws: error) {
            try DisplayBatch.run(targets([main, dp], ["main", "DP"]), undoArguments: []) { display, changed in
                attempted.append(display.name)
                throw error
            }
        }
        #expect(attempted == ["Built-in Display"])
    }

    @Test func aFailureOnTheSecondOfThreeNamesWhatChangedAndKeepsTheExitStatus() {
        var attempted: [String] = []
        do {
            try DisplayBatch.run(targets([main, dp, side], ["main", "dp", "Side"]), undoArguments: []) { display, changed in
                attempted.append(display.name)
                if display.uuid == "B" { throw DnmError.unsupportedWallpaper("dynamic") }
                changed()
            }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 3)
            #expect(error.errorDescription == "On DP: This wallpaper is not supported yet: dynamic. Nothing was changed on DP. Changed before this: Built-in Display. To put it back within 60 seconds: dnm undo main.")
        } catch { Issue.record("wrong error: \(error)") }
        #expect(attempted == ["Built-in Display", "DP"], "the third display is never attempted")
    }

    @Test func anErrorThatNamesTheDisplayGetsNoPrefix() {
        #expect(throws: DnmError.partWay("Cannot undo: the wallpaper on DP has changed since that change. Changed before this: Built-in Display, Side. To put them back within 60 seconds: dnm undo main Side --desktop 2.", exitCode: 1)) {
            try DisplayBatch.run(targets([main, side, dp], ["main", "Side", "DP"]), undoArguments: ["--desktop", "2"]) { display, changed in
                if display.uuid == "B" { throw DnmError.cannotUndo("the wallpaper on DP has changed since that change") }
                changed()
            }
        }
    }

    @Test func anInputErrorPartWayStillExitsTwo() {
        do {
            try DisplayBatch.run(targets([main, dp], ["main", "DP"]), undoArguments: []) { display, changed in
                if display.uuid == "B" { throw DnmError.invalidInput("DP has 1 Desktop; there is no Desktop 2. Nothing was changed.") }
                changed()
            }
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect(message(error).hasPrefix("DP has 1 Desktop; there is no Desktop 2. Nothing was changed on DP. Changed before this: Built-in Display."))
        } catch { Issue.record("wrong error: \(error)") }
    }

    @Test func theSuggestedCommandIsQuotedForTheShell() {
        let lg = FakeWallpaperSystem.makeDisplay(name: "LG Ultra HD", uuid: "D", isMain: false)
        let odd = FakeWallpaperSystem.makeDisplay(name: "-odd", uuid: "E", isMain: false)
        let quote = FakeWallpaperSystem.makeDisplay(name: "Bob's", uuid: "F", isMain: false)
        do {
            try DisplayBatch.run(targets([lg, odd, quote, dp], ["LG Ultra HD", "-odd", "Bob's", "DP"]), undoArguments: []) { display, changed in
                if display.uuid == "B" { throw DnmError.failure("stop") }
                changed()
            }
        } catch {
            #expect(message(error).hasSuffix("dnm undo 'LG Ultra HD' --display=-odd 'Bob'\\''s'."), "\(message(error))")
        }
    }

    @Test func aDisplayThatChangedNothingIsNotNamed() {
        do {
            try DisplayBatch.run(targets([main, dp, side], ["main", "DP", "Side"]), undoArguments: []) { display, changed in
                if display.uuid == "C" { throw DnmError.failure("stop") }
                if display.uuid == "B" { changed() }   // main had no label to remove
            }
        } catch {
            #expect(message(error).hasSuffix("Changed before this: DP. To put it back within 60 seconds: dnm undo DP."), "\(message(error))")
        }
    }

    @Test func aLaterDisplayFailingWithNothingChangedIsNamed() {
        do {
            try DisplayBatch.run(targets([main, dp], ["main", "DP"]), undoArguments: []) { display, changed in
                if display.uuid == "B" { throw DnmError.failure("The store could not be read.") }
                // main had no label to remove: nothing changed
            }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            #expect(message(error) == "On DP: The store could not be read.")
        } catch { Issue.record("wrong error: \(error)") }
    }

    @Test func aDesktopSwitchPointsAtTheUndoBelowNotABareUndo() {
        do {
            try DisplayBatch.run(targets([main, dp], ["main", "DP"]), undoArguments: ["--desktop", "2"]) { display, changed in
                changed()
                if display.uuid == "B" {
                    throw DnmError.failure("The Desktop on DP changed while dnm was working on Desktop 2, so the change may have gone to another Desktop. Check with `dnm show`, and run `dnm undo` if needed. dnm did not switch back.")
                }
            }
            Issue.record("expected an error")
        } catch {
            #expect(!message(error).contains("run `dnm undo` if needed"), "\(message(error))")
            #expect(message(error).hasSuffix("run the undo below if needed. dnm did not switch back. Changed: Built-in Display, DP. To put them back within 60 seconds: dnm undo main DP --desktop 2."), "\(message(error))")
        }
    }

    @Test func undoSuggestsNoUndo() {
        do {
            try DisplayBatch.run(targets([main, dp], ["main", "DP"]), undoArguments: nil) { display, changed in
                if display.uuid == "B" { throw DnmError.failure("stop") }
                changed()
            }
        } catch {
            #expect(message(error) == "On DP: stop Changed before this: Built-in Display.")
        }
    }

    @Test func oneDisplayBehavesAsASingleCall() throws {
        let error = DnmError.accessDenied("no")
        #expect(throws: error) {
            try DisplayBatch.run(targets([main], ["main"]), undoArguments: []) { _, _ in throw error }
        }
        var ran = 0
        try DisplayBatch.run(targets([main], ["main"]), undoArguments: []) { _, changed in ran += 1; changed() }
        #expect(ran == 1)
    }

    @Test func aNameInsideAnotherWordDoesNotCountAsNamingTheDisplay() {
        do {
            try DisplayBatch.run(targets([main, dp], ["main", "DP"]), undoArguments: []) { display, changed in
                if display.uuid == "B" { throw DnmError.failure("DP2 is busy.") }
                changed()
            }
        } catch {
            #expect(message(error).hasPrefix("On DP: DP2 is busy."), "\(message(error))")
        }
    }

    @Test func aTypedWordWithControlCharactersIsReplacedByTheDisplaysName() {
        do {
            try DisplayBatch.run(targets([main, dp], ["ma\u{1B}[2Jin", "DP"]), undoArguments: []) { display, changed in
                if display.uuid == "B" { throw DnmError.failure("stop") }
                changed()
            }
        } catch {
            #expect(message(error).hasSuffix("dnm undo 'Built-in Display'."), "\(message(error))")
            #expect(!message(error).unicodeScalars.contains(where: TerminalText.isUnsafe))
        }
    }

    // MARK: with the labeler and the fake wallpaper system (User Stories 3 and 4)

    /// A harness with three displays, each showing its own original.
    func threeDisplays() throws -> (LabelerHarness, [Display]) {
        let h = try LabelerHarness(extraDisplays: [dp, side])
        try h.showOriginal()
        for display in [dp, side] {
            let url = try SyntheticImages.write(SyntheticImages.gradient(), to: h.root.appendingPathComponent("\(display.uuid).png"))
            h.system.show(url, on: display)
        }
        return (h, [h.display, dp, side])
    }

    func shown(_ h: LabelerHarness, _ displays: [Display]) throws -> [URL?] {
        try displays.map { try h.system.currentWallpaper(on: $0).url?.resolvingSymlinksInPath() }
    }

    @Test func setOnThreeDisplaysWithTheSecondFailingLeavesExactlyTheFirstChanged() throws {
        let (h, displays) = try threeDisplays(); defer { h.cleanUp() }
        let before = try shown(h, displays)
        h.system.setErrors["B"] = DnmError.accessDenied("the file is locked")
        let text = try LabelText("Mail")

        do {
            try DisplayBatch.run(targets(displays, ["main", "DP", "Side"]), undoArguments: []) { display, changed in
                try h.labeler.setLabel(text, on: display)
                changed()
            }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            #expect(message(error).contains("On DP: macOS denied access: the file is locked. Nothing was changed on DP. Changed before this: Built-in Display. To put it back within 60 seconds: dnm undo main."))
        }

        let after = try shown(h, displays)
        #expect(after[0] != before[0], "the first display is labeled")
        #expect(after[1] == before[1] && after[2] == before[2], "the second failed, the third was never attempted")
        #expect(try h.manifest().changes.map(\.displayUUID) == ["DISPLAY-A"])
        try h.labeler.undoLastChange(on: h.display)
        #expect(try shown(h, [h.display]) == [before[0]], "the suggested undo works")
    }

    @Test func removeOnThreeDisplaysWithTheSecondFailingLeavesExactlyTheFirstChanged() throws {
        let (h, displays) = try threeDisplays(); defer { h.cleanUp() }
        let originals = try shown(h, displays)
        let text = try LabelText("Mail")
        for display in displays { try h.labeler.setLabel(text, on: display) }
        let labeled = try shown(h, displays)
        h.system.setErrors["B"] = DnmError.accessDenied("the file is locked")

        #expect(throws: DnmError.self) {
            try DisplayBatch.run(targets(displays, ["main", "DP", "Side"]), undoArguments: []) { display, changed in
                try h.labeler.removeLabel(on: display)
                changed()
            }
        }
        let after = try shown(h, displays)
        #expect(after[0] == originals[0], "the first display's label is removed")
        #expect(after[1] == labeled[1] && after[2] == labeled[2])
    }

    @Test func anUndoRefusedOnOneDisplayChangesNoDisplayAndNoStoredData() throws {
        let (h, displays) = try threeDisplays(); defer { h.cleanUp() }
        let text = try LabelText("Mail")
        try h.labeler.setLabel(text, on: h.display)
        try h.labeler.setLabel(text, on: side)   // DP has nothing to undo
        let manifest = try Data(contentsOf: h.store.directory.appendingPathComponent("manifest.json"))
        let before = try shown(h, displays)

        // What `dnm undo main DP Side` does before its first change.
        #expect(throws: DnmError.cannotUndo("there is nothing to undo on DP; a change can be undone for 60 seconds")) {
            for display in displays { try h.labeler.checkUndo(on: display, onScreen: true) }
        }
        #expect(try shown(h, displays) == before)
        #expect(try Data(contentsOf: h.store.directory.appendingPathComponent("manifest.json")) == manifest)
    }

    @Test func aDisplayThatCannotBeResolvedChangesNothing() throws {
        let (h, displays) = try threeDisplays(); defer { h.cleanUp() }
        let before = try shown(h, displays)
        #expect(throws: DnmError.self) {
            _ = try DisplayArguments.targets(words: ["main", "DP", "NoSuchDisplay"], displayFlags: [], in: displays, aliases: [])
        }
        #expect(try shown(h, displays) == before)
        #expect(!h.store.hasManifest)
    }

    /// Review question: two displays labeled alike (same picture, same text) undo independently; images are reused
    /// per display, never across displays.
    @Test func twoDisplaysLabeledAlikeUndoIndependently() throws {
        let h = try LabelerHarness(extraDisplays: [dp]); defer { h.cleanUp() }
        let original = try h.showOriginal()
        h.system.show(original, on: dp)
        let text = try LabelText("Mail")
        try DisplayBatch.run(targets([h.display, dp], ["main", "DP"]), undoArguments: []) { display, changed in
            try h.labeler.setLabel(text, on: display)
            changed()
        }
        #expect(Set(try h.manifest().stamps.map(\.fileName)).count == 2, "one image per display")
        for display in [h.display, dp] { try h.labeler.checkUndo(on: display, onScreen: true) }
        try DisplayBatch.run(targets([h.display, dp], ["main", "DP"]), undoArguments: nil) { display, changed in
            try h.labeler.undoLastChange(on: display)
            changed()
        }
        let shown = try shown(h, [h.display, dp])
        #expect(shown == [original.resolvingSymlinksInPath(), original.resolvingSymlinksInPath()])
    }
}
