import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 012: `cleanup --scan` with the fake switcher and wallpaper system. Nothing switches a real Desktop.
@MainActor
@Suite struct ScanTests {
    nonisolated static let second = FakeWallpaperSystem.makeDisplay(name: "DP1", uuid: "DISPLAY-B", isMain: false, width: 800, height: 500, scale: 1)

    /// A harness with the built-in display and, when asked, DP1, and a switcher linked to its wallpaper system.
    @MainActor struct Rig {
        let h: LabelerHarness
        let switcher: FakeSwitcher

        init(twoDisplays: Bool = false) throws {
            h = try LabelerHarness(extraDisplays: twoDisplays ? [ScanTests.second] : [])
            switcher = FakeSwitcher(system: h.system)
        }

        var main: Display { h.display }

        /// A stored label on `display` (the built-in one by default); its image is in the store.
        @discardableResult
        func label(_ text: String, on display: Display? = nil, state: StampState = .active) throws -> Stamp {
            let display = display ?? h.display
            return try h.addStamp(text, state: state, lastSeen: h.days(10), createdAt: h.days(20), displayName: display.name, displayUUID: display.uuid)
        }

        func url(_ stamp: Stamp) -> URL { h.store.fileURL(named: stamp.fileName) }

        func scan(separateSpaces: Bool = true, isInterrupted: () -> Bool = { false }) throws -> ScanResult {
            try h.labeler.scan(switcher: switcher, separateSpaces: separateSpaces, isInterrupted: isInterrupted)
        }

        func manifestBytes() throws -> Data { try Data(contentsOf: h.store.manifestURL) }
    }

    // MARK: - User Story 1

    @Test func theLabelOfADeletedDesktopIsTheOnlyCandidateAndIsDeleted() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let a = try rig.label("A"), b = try rig.label("B"), c = try rig.label("C")
        // B's Desktop was deleted: the display has the Desktops of A and C, and is on C.
        rig.switcher.attach(rig.main, wallpapers: [rig.url(a), rig.url(c)], position: 2)

        let result = try rig.scan()
        #expect(result.scanned.map(\.name) == ["Built-in Display"])
        let plan = try rig.h.labeler.scanPlan(from: result)
        #expect(plan.candidates.map(\.label) == ["B"] && plan.candidates.map(\.reason) == [.notOnAnyDesktop] && plan.days == nil)
        #expect(rig.switcher.position(of: rig.main) == 2 && rig.switcher.pointerRestored, "back where it started")

        rig.h.clock.advance(minutes: 5)
        let deleted = try rig.h.labeler.carryOut(plan, seen: result.seen)
        #expect(deleted.candidates.map(\.label) == ["B"])
        let stamps = try rig.h.manifest().stamps
        #expect(stamps.map(\.label.text.value) == ["A", "C"])
        #expect(stamps.allSatisfy { $0.lastSeen == rig.h.clock.now }, "both were seen by the scan")
        #expect(!FileManager.default.fileExists(atPath: rig.url(b).path))
        _ = b
    }

    @Test func everyDesktopIsReadOnceInOrderWhereverTheDisplayStarts() throws {
        for start in 1...4 {
            let rig = try Rig(); defer { rig.h.cleanUp() }
            let stamps = try (1...4).map { try rig.label("D\($0)") }
            rig.switcher.attach(rig.main, wallpapers: stamps.map(rig.url), position: start)
            let result = try rig.scan()
            #expect(result.seen == Set(stamps.map(\.fileName)), "start \(start)")
            #expect(try rig.h.labeler.scanPlan(from: result).candidates.isEmpty)
            #expect(rig.switcher.position(of: rig.main) == start)
            #expect(rig.switcher.steps <= 2 * 4, "at most two presses per Desktop (SC-004): \(rig.switcher.steps)")
        }
    }

    @Test func anImageOnTwoDesktopsIsSeenAndARetiredOneShownNowhereIsACandidate() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let shared = try rig.label("Shared")
        try rig.label("Retired", state: .retired(at: rig.h.days(1), reason: .removed))
        rig.switcher.attach(rig.main, wallpapers: [rig.url(shared), rig.url(shared), nil], position: 1)
        let plan = try rig.h.labeler.scanPlan(from: try rig.scan())
        #expect(plan.candidates.map(\.label) == ["Retired"])
    }

    @Test func aLabelWhoseImageIsMissingIsACandidateOfSizeZero() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let kept = try rig.label("Kept"), lost = try rig.label("Lost")
        try FileManager.default.removeItem(at: rig.url(lost))
        rig.switcher.attach(rig.main, wallpapers: [rig.url(kept), nil], position: 1)
        let plan = try rig.h.labeler.scanPlan(from: try rig.scan())
        #expect(plan.candidates.map(\.label) == ["Lost"] && plan.candidates.map(\.bytes) == [0])
        try rig.h.labeler.carryOut(plan, seen: [])
        #expect(try rig.h.manifest().stamps.map(\.label.text.value) == ["Kept"], "its record is removed")
    }

    @Test func eachDisplayIsWalkedInTurnAndReadsOnlyItself() throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        let a1 = try rig.label("A1"), a2 = try rig.label("A2")
        let b1 = try rig.label("B1", on: Self.second), b2 = try rig.label("B2", on: Self.second)
        try rig.label("B gone", on: Self.second)
        rig.switcher.attach(rig.main, wallpapers: [rig.url(a1), rig.url(a2)], position: 2)
        rig.switcher.attach(Self.second, wallpapers: [rig.url(b1), rig.url(b2), nil], position: 1)
        let result = try rig.scan()
        #expect(result.scanned.map(\.name) == ["Built-in Display", "DP1"])
        #expect(rig.switcher.pointedAtNames == ["Built-in Display", "DP1"])
        #expect(try rig.h.labeler.scanPlan(from: result).candidates.map(\.label) == ["B gone"])
        #expect(rig.switcher.position(of: rig.main) == 2 && rig.switcher.position(of: Self.second) == 1)
    }

    @Test func withSharedSpacesOneWalkReadsEveryDisplayAtEachStop() throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        rig.switcher.separateSpaces = false
        let a = try (1...3).map { try rig.label("A\($0)") }
        let b = try (1...3).map { try rig.label("B\($0)", on: Self.second) }
        try rig.label("A gone")
        rig.switcher.attach(rig.main, wallpapers: a.map(rig.url), position: 2)
        rig.switcher.attach(Self.second, wallpapers: b.map(rig.url), position: 2)
        var walks: [[String]] = []
        let result = try rig.h.labeler.scan(switcher: rig.switcher, separateSpaces: false, progress: { walks.append($0.map(\.name)) })
        #expect(walks == [["Built-in Display", "DP1"]], "one walk, both displays")
        #expect(rig.switcher.pointedAtNames == ["Built-in Display"])
        #expect(try rig.h.labeler.scanPlan(from: result).candidates.map(\.label) == ["A gone"])
        #expect(rig.switcher.position(of: rig.main) == 2 && rig.switcher.position(of: Self.second) == 2)
    }

    @Test func aWallpaperThatIsReportedLateIsStillRead() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let stamps = try (1...3).map { try rig.label("D\($0)") }
        rig.switcher.attach(rig.main, wallpapers: stamps.map(rig.url), position: 1)
        for late in [1, 2] {
            rig.switcher.lateReads = late
            #expect(try rig.h.labeler.scanPlan(from: try rig.scan()).candidates.isEmpty, "\(late) late reads")
        }
    }

    // MARK: - One Desktop or shortcuts off (FR-017)

    @Test func oneDisplayWithOneDesktopCannotBeToldFromShortcutsOff() throws {
        for shortcutsOn in [true, false] {
            let rig = try Rig(twoDisplays: !shortcutsOn); defer { rig.h.cleanUp() }
            let a = try rig.label("A")
            rig.switcher.shortcutsOn = shortcutsOn
            rig.switcher.attach(rig.main, wallpapers: shortcutsOn ? [rig.url(a)] : [rig.url(a), nil], position: 1)
            if !shortcutsOn { rig.switcher.attach(Self.second, wallpapers: [nil, nil], position: 2) }
            let before = try rig.manifestBytes()
            do {
                _ = try rig.scan()
                Issue.record("expected an error")
            } catch let error as DnmError {
                let text = error.errorDescription ?? ""
                #expect(error.exitCode == 1 && text.contains("No Desktop change happened") && text.hasSuffix("Nothing was deleted."), "\(text)")
            }
            #expect(try rig.manifestBytes() == before)
        }
    }

    @Test(arguments: [true, false])
    func aDisplayWithOneDesktopBesideOneThatSwitchesIsScanned(_ oneDesktopFirst: Bool) throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        let only = try rig.label("Only")
        let b = try (1...3).map { try rig.label("B\($0)", on: Self.second) }
        rig.switcher.attach(rig.main, wallpapers: [rig.url(only)], position: 1)
        rig.switcher.attach(Self.second, wallpapers: b.map(rig.url), position: 3)
        if !oneDesktopFirst { rig.h.system.connectedDisplays.reverse() }
        let plan = try rig.h.labeler.scanPlan(from: try rig.scan())
        #expect(plan.candidates.isEmpty, "the one-Desktop display's label is seen")
    }

    // MARK: - User Story 2: displays that are not connected

    @Test func labelsOfADisplayThatIsNotConnectedAreNamedAndNeverCandidates() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let a = try rig.label("A")
        try rig.label("Away 1", on: Display(name: "Studio Display", uuid: "DISPLAY-Z", isMain: false, geometry: rig.main.geometry))
        try rig.label("Away 2", on: Display(name: "Studio Display", uuid: "DISPLAY-Z", isMain: false, geometry: rig.main.geometry))
        rig.switcher.attach(rig.main, wallpapers: [rig.url(a), nil], position: 1)
        let result = try rig.scan()
        #expect(result.notConnected == [NotConnectedDisplay(name: "Studio Display", labels: 2)])
        #expect(try rig.h.labeler.scanPlan(from: result).candidates.isEmpty)
        #expect(ScanText.notChecked(result.notConnected) == ["Not checked: Studio Display is not connected (2 labels)."])
    }

    @Test func withOnlyLabelsOfAbsentDisplaysThereIsNothingToScan() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.label("Away", on: Display(name: "Studio Display", uuid: "DISPLAY-Z", isMain: false, geometry: rig.main.geometry))
        let preview = try rig.h.labeler.scanPreview()
        #expect(!preview.hasLabelsToCheck && preview.notConnected == [NotConnectedDisplay(name: "Studio Display", labels: 1)])
        #expect(preview.displays.map(\.name) == ["Built-in Display"])
    }

    // MARK: - User Story 3: a scan that stops changes nothing

    @Test func withoutThePermissionNothingIsPointedAtOrWritten() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 1)
        rig.switcher.isTrusted = false
        let before = try rig.manifestBytes()
        do {
            _ = try rig.scan()
            Issue.record("expected an error")
        } catch let error as DnmError {
            let text = error.errorDescription ?? ""
            #expect(error.exitCode == 1 && text.hasPrefix("cleanup --scan needs the Accessibility permission") && text.hasSuffix("Nothing was deleted."))
        }
        #expect(rig.switcher.steps == 0 && rig.switcher.pointedAt == nil)
        #expect(try rig.manifestBytes() == before)
    }

    @Test func aSwitchByThePersonOnTheSecondDisplayStopsAndNamesTheFirst() throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 2)
        rig.switcher.attach(Self.second, wallpapers: [nil, nil, nil], position: 1)
        // Main: left (1), left at the edge (2), right (3), right at the edge (4); it is back. DP1 starts at press 5.
        rig.switcher.personSwitchesAtStep = 7
        let before = try rig.manifestBytes()
        do {
            _ = try rig.scan()
            Issue.record("expected an error")
        } catch let error as DnmError {
            let text = error.errorDescription ?? ""
            #expect(error.exitCode == 1 && text.contains("The Desktop on DP1 changed while dnm was scanning. Nothing was deleted."), "\(text)")
            #expect(text.hasSuffix("Scanned and returned: Built-in Display."), "\(text)")
        }
        #expect(rig.switcher.position(of: rig.main) == 2, "the first display is back")
        #expect(try rig.manifestBytes() == before)
    }

    @Test func aStepNotConfirmedOnTheWayBackIsReported() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil, nil], position: 2)
        // Left (1), edge (2), right (3), right (4), edge (5), back left (6) is not confirmed.
        rig.switcher.unconfirmedSteps = [6]
        do {
            _ = try rig.scan()
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("while returning Built-in Display to the Desktop it started on. Nothing was deleted"))
        }
        #expect(rig.switcher.pointerRestored)
    }

    @Test func anInterruptReturnsTheDisplayAndNamesWhatWasScanned() throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 1)
        rig.switcher.attach(Self.second, wallpapers: [nil, nil, nil, nil], position: 2)
        // Main takes 4 presses; DP1's walk is interrupted after its step 3 (press 7).
        var interrupted = false
        rig.switcher.interruptAtStep = 7
        rig.switcher.onInterruptStep = { interrupted = true }
        let before = try rig.manifestBytes()
        do {
            _ = try rig.scan(isInterrupted: { interrupted })
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error == .interrupted(scanned: ["Built-in Display"]) && error.exitCode == 130)
            #expect(error.errorDescription == "Stopped. Scanned: Built-in Display. Nothing was deleted.")
        }
        #expect(rig.switcher.position(of: rig.main) == 1 && rig.switcher.position(of: Self.second) == 2, "both are back")
        #expect(rig.switcher.pointerRestored)
        #expect(try rig.manifestBytes() == before)
    }

    @Test func anInterruptBeforeTheFirstDisplayIsFinishedNamesNone() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil, nil], position: 3)
        do {
            _ = try rig.scan(isInterrupted: { rig.switcher.steps >= 1 })
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.errorDescription == "Stopped before any display was scanned. Nothing was deleted.")
        }
        #expect(rig.switcher.position(of: rig.main) == 3)
    }

    // MARK: - Review findings (2026-11-09)

    /// A Ctrl-C while the last display returns is still an interrupt: nothing is deleted, exit 130.
    @Test func anInterruptOnTheWayBackOfTheLastWalkStillStops() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil, nil], position: 1)
        // Edge (1), right (2), right (3), edge (4), then back: left (5), left (6). Ctrl-C during press 5.
        var interrupted = false
        rig.switcher.interruptAtStep = 5
        rig.switcher.onInterruptStep = { interrupted = true }
        let before = try rig.manifestBytes()
        #expect(throws: DnmError.interrupted(scanned: ["Built-in Display"])) { _ = try rig.scan(isInterrupted: { interrupted }) }
        #expect(rig.switcher.position(of: rig.main) == 1)
        #expect(try rig.manifestBytes() == before)
    }

    /// A display that cannot be read during its walk (disconnected) stops the scan; its labels are never candidates.
    @Test(arguments: [true, false])
    func aDisplayThatCannotBeReadStopsTheScan(_ separateSpaces: Bool) throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        rig.switcher.separateSpaces = separateSpaces
        try rig.label("B", on: Self.second)
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 1)
        rig.switcher.attach(Self.second, wallpapers: [nil, nil], position: 1)
        // Separate: main takes presses 1-4 (edge, right, edge, back); DP1's first move is press 6. Shared: press 2.
        rig.switcher.disconnectAtStep = (separateSpaces ? 6 : 2, Self.second)
        let before = try rig.manifestBytes()
        do {
            _ = try rig.scan(separateSpaces: separateSpaces)
            Issue.record("expected an error")
        } catch let error as DnmError {
            let text = error.errorDescription ?? ""
            #expect(text.contains("could not read the wallpaper of DP1") && text.contains("Nothing was deleted."), "\(text)")
            if separateSpaces { #expect(text.hasSuffix("Scanned and returned: Built-in Display."), "\(text)") }
        }
        #expect(try rig.manifestBytes() == before)
    }

    @Test func aDisplayConnectedOrDisconnectedDuringTheScanStopsIt() throws {
        let rig = try Rig(twoDisplays: true); defer { rig.h.cleanUp() }
        try rig.label("A")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 1)
        rig.switcher.attach(Self.second, wallpapers: [nil, nil], position: 1)
        var walks = 0
        do {
            _ = try rig.h.labeler.scan(switcher: rig.switcher, separateSpaces: true, progress: { _ in
                walks += 1
                if walks == 2 { rig.h.system.connectedDisplays.removeLast() }
            })
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("connected or disconnected during the scan"))
        }
    }

    /// A step that gave up but moved after all is announced late; the walk counts it and stops instead of taking
    /// the Desktop before it for the last one.
    @Test func aLateNoticeAtTheEndOfAWalkStopsTheScan() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let a = try (1...3).map { try rig.label("D\($0)") }
        rig.switcher.attach(rig.main, wallpapers: a.map(rig.url), position: 1)
        rig.switcher.lateAnnouncedSteps = [3]   // edge (1), right (2), right (3): moves to Desktop 3, noticed late
        do {
            _ = try rig.scan()
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("changed while dnm was scanning"))
        }
    }

    // MARK: - Writes (FR-006, FR-007)

    @Test func keepingRecordsOnlyWhatWasSeen() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let a = try rig.label("A"), gone = try rig.label("Gone")
        rig.switcher.attach(rig.main, wallpapers: [rig.url(a), nil], position: 2)
        let result = try rig.scan()
        var expected = try rig.h.manifest()
        rig.h.clock.advance(minutes: 5)
        try rig.h.labeler.recordSeen(result)
        expected.stamps[0].lastSeen = rig.h.clock.now
        #expect(try rig.h.manifest() == expected, "only A's lastSeen changed")
        #expect(FileManager.default.fileExists(atPath: rig.url(gone).path))
    }

    @Test func deletionRechecksWhatShowsNowAndClearsTheNudge() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        let a = try rig.label("A"), back = try rig.label("Back"), gone = try rig.label("Gone")
        try rig.h.store.transaction { $0.maintenance = Maintenance(nudgedAt: rig.h.days(1), nudgedBytes: 1) }
        rig.switcher.attach(rig.main, wallpapers: [rig.url(a), nil], position: 1)
        let result = try rig.scan()
        let plan = try rig.h.labeler.scanPlan(from: result)
        #expect(Set(plan.candidates.map(\.label)) == ["Back", "Gone"])
        rig.h.system.show(rig.url(back), on: rig.main)   // put on screen after the list was shown
        let deleted = try rig.h.labeler.carryOut(plan, seen: result.seen)
        #expect(deleted.candidates.map(\.label) == ["Gone"])
        #expect(try rig.h.manifest().stamps.map(\.label.text.value) == ["A", "Back"])
        #expect(try rig.h.manifest().maintenance == nil)
        #expect(!FileManager.default.fileExists(atPath: rig.url(gone).path))
    }

    // MARK: - The flow and the text

    @Test func deletionNeedsTwoYesAnswersOrYes() {
        // (yes, terminal, json) → the start and, with candidates, the finish.
        let table: [(Bool, Bool, Bool, ScanFlow.Start, ScanFlow.Finish)] = [
            (false, true, false, .askToScan, .askToDelete),
            (false, false, false, .describeOnly, .keep),
            (false, true, true, .describeOnly, .keep),
            (false, false, true, .describeOnly, .keep),
            (true, true, false, .scan, .delete),
            (true, false, false, .scan, .delete),
            (true, false, true, .scan, .delete),
        ]
        for (yes, terminal, json, start, finish) in table {
            #expect(ScanFlow.start(yes: yes, terminal: terminal, json: json) == start, "\(yes) \(terminal) \(json)")
            #expect(ScanFlow.finish(candidates: 2, yes: yes, terminal: terminal, json: json) == finish, "\(yes) \(terminal) \(json)")
            #expect(ScanFlow.finish(candidates: 0, yes: yes, terminal: terminal, json: json) == .nothingToDelete)
        }
        for answer in ["y", "Y", " yes ", "YES"] { #expect(ScanFlow.isYes(answer), "\(answer)") }
        for answer in [nil, "", "n", "no", "yep", "y es"] as [String?] { #expect(!ScanFlow.isYes(answer), "\(answer ?? "nil")") }
    }

    @Test func theDescriptionSaysWhatThePersonWillSee() {
        let geometry = DisplayGeometry(pointWidth: 800, pointHeight: 500, scale: 1)
        let preview = ScanPreview(displays: [Display(name: "Built-in Display", uuid: "A", isMain: true, geometry: geometry),
                                             Display(name: "DP1", uuid: "B", isMain: false, geometry: geometry)],
                                  notConnected: [], hasLabelsToCheck: true)
        let separate = ScanText.description(preview, separateSpaces: true)
        #expect(separate[0] == "dnm will visit every Desktop of these displays, one display at a time: Built-in Display, DP1.")
        #expect(separate[1].contains("about 2 seconds per Desktop") && separate[1].contains("do not type"))
        #expect(separate[2] == "Each display returns to the Desktop it started on.")
        #expect(ScanText.description(preview, separateSpaces: false)[0].contains("switch together"))
    }

    @Test func theReportListsEachCandidateAndTheTotal() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.h.addStamp("Mail", lastSeen: rig.h.days(41), createdAt: rig.h.days(60), bytes: 4_100_000, displayName: "Built-in Display")
        try rig.h.addStamp("Old", lastSeen: nil, createdAt: rig.h.days(60), bytes: 1_000_000, displayName: "Built-in Display")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 1)
        let plan = try rig.h.labeler.scanPlan(from: try rig.scan())
        let lines = ScanText.report(plan, notConnected: [NotConnectedDisplay(name: "Studio Display", labels: 1)], now: rig.h.clock.now)
        #expect(lines.first == "Not on any Desktop (2 labels, 5.1 MB):", "\(lines)")
        #expect(lines.contains { $0.contains("\"Mail\"") && $0.contains("4.1 MB") && $0.hasSuffix("last seen 41 days ago") }, "\(lines)")
        #expect(lines.contains { $0.contains("\"Old\"") && $0.hasSuffix("never seen") }, "\(lines)")
        #expect(lines.last == "Not checked: Studio Display is not connected (1 label).")
        #expect(ScanText.question(plan) == "Delete these 2 labeled images (5.1 MB)? [y/N] ")
        #expect(ScanText.deleted(plan) == "Deleted 2 labeled images (5.1 MB).")
    }

    @Test func theScanDocumentHasItsModeAnExplicitNullDaysAndNoIdentifiers() throws {
        let rig = try Rig(); defer { rig.h.cleanUp() }
        try rig.label("Gone")
        rig.switcher.attach(rig.main, wallpapers: [nil, nil], position: 1)
        let result = try rig.scan()
        let plan = try rig.h.labeler.scanPlan(from: result)
        let json = try Reports.json(Reports.scan(plan, scanned: result.scanned.map(\.name),
                                                 notConnected: [NotConnectedDisplay(name: "Studio Display", labels: 2)], deleted: false))
        #expect(!json.contains(".dnm.") && !json.contains("DISPLAY-A"))
        #expect(json.contains("\"days\" : null"))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(Set(root.keys) == ["mode", "days", "candidates", "totalBytes", "deleted", "scanned", "notChecked"])
        #expect(root["mode"] as? String == "scan" && root["scanned"] as? [String] == ["Built-in Display"])
        #expect((root["candidates"] as? [[String: Any]])?.first?["why"] as? String == "not on any Desktop")
        #expect((root["notChecked"] as? [[String: Any]])?.first?["labels"] as? Int == 2)
        let would = try JSONSerialization.jsonObject(with: Data(try Reports.json(Reports.scan(.emptyScan, scanned: [], notConnected: [], deleted: false, wouldScan: ["DP1"])).utf8)) as? [String: Any]
        #expect(would?["wouldScan"] as? [String] == ["DP1"] && would?["scanned"] as? [String] == [])
    }

    @Test func theSecondInterruptLineNamesTheDisplay() {
        #expect(Interrupt.secondInterruptLine(display: "DP1") == "\ndnm: Stopped; DP1 may be on another Desktop. Nothing was deleted.\n")
    }
}
