import CoreGraphics
import Foundation
import Testing
@testable import DesktopNameCore

@MainActor
@Suite struct DesktopNavigatorTests {
    let display = FakeWallpaperSystem.makeDisplay(name: "DP", uuid: "DISPLAY-B", isMain: false)

    @Test(arguments: [(4, 1, 2), (4, 3, 2), (4, 4, 1), (4, 2, 4), (3, 1, 1)])
    func reachesTheDesktopActsThereAndReturns(_ desktops: Int, _ start: Int, _ target: Int) throws {
        let fake = FakeSwitcher(desktops: desktops, position: start)
        var actedOn: Int?
        let result = try DesktopNavigator(switcher: fake).visit(desktop: target, on: display) { () -> String in
            actedOn = fake.position
            return "done"
        }
        #expect(result == "done")
        #expect(actedOn == target)
        #expect(fake.position == start)
        #expect(fake.pointedAt == "DP" && fake.pointerRestored)
    }

    @Test func aMissingDesktopChangesNothingAndReturns() throws {
        let fake = FakeSwitcher(desktops: 3, position: 2)
        var ran = false
        do {
            try DesktopNavigator(switcher: fake).visit(desktop: 5, on: display) { ran = true }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect((error.errorDescription ?? "").contains("DP has 3 Desktops; there is no Desktop 5"))
        }
        #expect(!ran)
        #expect(fake.position == 2)
        #expect(fake.pointerRestored)
    }

    @Test func aSwitchByThePersonWhileSwitchingStopsBeforeLabeling() throws {
        let fake = FakeSwitcher(desktops: 4, position: 3)
        fake.personSwitchesAtStep = 2
        var ran = false
        do {
            try DesktopNavigator(switcher: fake).visit(desktop: 2, on: display) { ran = true }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            #expect((error.errorDescription ?? "").contains("Nothing was labeled"))
        }
        #expect(!ran)
        #expect(fake.pointerRestored)
    }

    @Test func aSwitchByThePersonDuringTheChangeIsReported() throws {
        let fake = FakeSwitcher(desktops: 4, position: 3)
        do {
            try DesktopNavigator(switcher: fake).visit(desktop: 2, on: display) { fake.personSwitches() }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            #expect((error.errorDescription ?? "").contains("dnm show"))
        }
    }

    @Test func withoutAccessibilityNothingMovesAndTheReasonIsGiven() throws {
        let fake = FakeSwitcher(desktops: 3, position: 2)
        fake.isTrusted = false
        do {
            try DesktopNavigator(switcher: fake).visit(desktop: 1, on: display) {}
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            let text = error.errorDescription ?? ""
            #expect(text.contains("Accessibility") && text.contains("Move left a space") && text.contains("Privacy & Security") && text.contains("Device Control and Data Access"))
            #expect(text.contains("every program run in that app"))
        }
        #expect(fake.steps == 0)
        #expect(fake.pointedAt == nil)
    }

    @Test func shortcutsOffOrASingleDesktopIsRefusedWithBothExplanations() throws {
        for fake in [FakeSwitcher(desktops: 3, position: 2), FakeSwitcher(desktops: 1, position: 1)] {
            if fake.desktops == 3 { fake.shortcutsOn = false }
            var ran = false
            do {
                try DesktopNavigator(switcher: fake).visit(desktop: 1, on: display) { ran = true }
                Issue.record("expected an error")
            } catch let error as DnmError {
                let text = error.errorDescription ?? ""
                #expect(text.contains("only one Desktop") && text.contains("shortcuts are off"))
                #expect(text.contains("Keyboard (near the bottom of the sidebar)") && text.contains("expand the Mission Control group"))
            }
            #expect(!ran)
            #expect(fake.pointerRestored)
        }
    }

    @Test func atDesktopOneAProbeConfirmsTheShortcutsWork() throws {
        let fake = FakeSwitcher(desktops: 3, position: 1)
        var actedOn: Int?
        try DesktopNavigator(switcher: fake).visit(desktop: 1, on: display) { actedOn = fake.position }
        #expect(actedOn == 1)
        #expect(fake.position == 1)
        #expect(fake.visitedPositions == [2, 1])   // the probe went right and came back
    }

    @Test func fromDesktopOneToALaterDesktopTheFirstStepIsTheProbe() throws {
        let fake = FakeSwitcher(desktops: 3, position: 1)
        var actedOn: Int?
        try DesktopNavigator(switcher: fake).visit(desktop: 3, on: display) { actedOn = fake.position }
        #expect(actedOn == 3)
        #expect(fake.visitedPositions == [2, 3, 2, 1])   // straight there and back, no step right and back first
        #expect(fake.steps == 5)                         // the one left press at the edge, then four moves
    }

    @Test(arguments: [2, 3])
    func fromDesktopOneWithNothingMovingBothExplanationsAreGiven(_ target: Int) throws {
        for fake in [FakeSwitcher(desktops: 3, position: 1), FakeSwitcher(desktops: 1, position: 1)] {
            if fake.desktops == 3 { fake.shortcutsOn = false }
            var ran = false
            do {
                try DesktopNavigator(switcher: fake).visit(desktop: target, on: display) { ran = true }
                Issue.record("expected an error")
            } catch let error as DnmError {
                let text = error.errorDescription ?? ""
                #expect(error.exitCode == 1)
                #expect(text.contains("only one Desktop") && text.contains("shortcuts are off"))
            }
            #expect(!ran)
            #expect(fake.position == 1)
        }
    }

    @Test func anErrorInTheBodyStillReturnsToTheStart() throws {
        struct Boom: Error {}
        let fake = FakeSwitcher(desktops: 4, position: 3)
        #expect(throws: Boom.self) { try DesktopNavigator(switcher: fake).visit(desktop: 1, on: display) { throw Boom() } }
        #expect(fake.position == 3)
        #expect(fake.pointerRestored)
    }

    @Test func aStepThatIsNotConfirmedOnTheWayBackIsReported() throws {
        // Start at 2: one step left (step 1) finds the edge, the edge check (step 2) fails, then right to 3
        // (steps 3 and 4), act, and back: step 5 goes from 3 to 2 but is never confirmed.
        let fake = FakeSwitcher(desktops: 4, position: 2)
        fake.unconfirmedSteps = [5]
        do {
            try DesktopNavigator(switcher: fake).visit(desktop: 3, on: display) {}
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("returning DP to Desktop 2"))
        }
        #expect(fake.pointerRestored)
    }

    @Test(arguments: [0, -1])
    func aDesktopNumberBelowOneIsInvalidInput(_ target: Int) {
        let fake = FakeSwitcher(desktops: 3, position: 1)
        do { try DesktopNavigator(switcher: fake).visit(desktop: target, on: display) {} } catch let error as DnmError {
            #expect(error.exitCode == 2)
        } catch { Issue.record("wrong error") }
        #expect(fake.steps == 0)
    }

    /// Spec 010 User Story 5: `--desktop 2` on two displays visits each in turn, with its own switcher as
    /// `Context.onDesktop` makes one per display. The second has no Desktop 2: it fails when reached, after the first
    /// was labeled, and the part-way message follows.
    @Test func severalDisplaysAreVisitedInTurnAndAMissingDesktopFailsWhenReached() throws {
        let main = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true)
        let switchers = ["DISPLAY-A": FakeSwitcher(desktops: 3, position: 3), "DISPLAY-B": FakeSwitcher(desktops: 1, position: 1)]
        var labeled: [String] = []
        do {
            try DisplayBatch.run(DisplayArguments.Targets(displays: [main, display], references: ["main", "DP"], notice: nil),
                                 undoArguments: ["--desktop", "2"]) { target, changed in
                let fake = try #require(switchers[target.uuid])
                try DesktopNavigator(switcher: fake).visit(desktop: 2, on: target) {
                    #expect(fake.position == 2)
                    labeled.append(target.name)
                    changed()
                }
            }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            let text = error.errorDescription ?? ""
            #expect(text.contains("No Desktop change happened on DP"), "\(text)")
            #expect(text.hasSuffix("Changed before this: Built-in Display. To put it back within 60 seconds: dnm undo main --desktop 2."), "\(text)")
        }
        #expect(labeled == ["Built-in Display"])
        let first = try #require(switchers["DISPLAY-A"]), second = try #require(switchers["DISPLAY-B"])
        #expect(first.position == 3 && first.pointedAt == "Built-in Display" && first.pointerRestored, "the first returned to where it was")
        #expect(second.position == 1 && second.pointedAt == "DP" && second.pointerRestored)
    }

    /// Review finding: a display changed on Desktop N whose step back is not confirmed is counted as changed, so the
    /// part-way message names it and the suggested undo includes it.
    @Test func aDisplayChangedBeforeItsWayBackFailedIsNamedAsChanged() throws {
        let main = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "DISPLAY-A", isMain: true)
        let lost = FakeSwitcher(desktops: 3, position: 1)
        lost.unconfirmedSteps = [3]   // 1: left (nothing), 2: right to Desktop 2, 3: left, back: not confirmed
        let switchers = ["DISPLAY-A": FakeSwitcher(desktops: 3, position: 1), "DISPLAY-B": lost]
        func run(_ displays: [Display], _ references: [String]) throws {
            try DisplayBatch.run(DisplayArguments.Targets(displays: displays, references: references, notice: nil),
                                 undoArguments: ["--desktop", "2"]) { target, changed in
                let fake = try #require(switchers[target.uuid])
                try DesktopNavigator(switcher: fake).visit(desktop: 2, on: target) { changed() }
            }
        }
        do {
            try run([main, display], ["main", "DP"])
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            #expect((error.errorDescription ?? "").hasSuffix("Changed: Built-in Display, DP. To put them back within 60 seconds: dnm undo main DP --desktop 2."), "\(error)")
        }

        // On the first of two displays: named too, and the second is never attempted.
        lost.unconfirmedSteps = [6]
        do {
            try run([display, main], ["DP", "main"])
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").hasSuffix("Changed: DP. To put it back within 60 seconds: dnm undo DP --desktop 2."), "\(error)")
        }

        // One display: the error exactly as a single command gives it.
        lost.unconfirmedSteps = [9]
        do {
            try run([display], ["DP"])
            Issue.record("expected an error")
        } catch let error as DnmError {
            if case .failure(let message) = error { #expect(message.contains("returning DP")) } else { Issue.record("\(error)") }
        }
    }

    // MARK: - walk (spec 012)

    @Test(arguments: [1, 2, 4])
    func aWalkReadsEveryDesktopInOrderAndReturns(_ start: Int) throws {
        let fake = FakeSwitcher(desktops: 4, position: start)
        var read: [Int] = []
        let outcome = try DesktopNavigator(switcher: fake).walk(on: display) { read.append(fake.position) }
        #expect(read == [1, 2, 3, 4])
        #expect(fake.position == start && fake.pointedAt == "DP" && fake.pointerRestored)
        #expect(outcome == .walked(steps: (start - 1) + 3 + (4 - start)))
        #expect(fake.steps == 8, "two presses per Desktop, the edges included")
    }

    @Test func oneDesktopAndShortcutsOffBothReportNothingMovedAfterOneRead() throws {
        for fake in [FakeSwitcher(desktops: 1, position: 1), FakeSwitcher(desktops: 3, position: 2)] {
            if fake.desktops == 3 { fake.shortcutsOn = false }
            var reads = 0
            #expect(try DesktopNavigator(switcher: fake).walk(on: display) { reads += 1 } == .nothingMoved)
            #expect(reads == 1 && fake.pointerRestored)
        }
    }

    @Test func aSwitchByThePersonDuringAWalkStopsWithoutSwitchingBack() throws {
        let fake = FakeSwitcher(desktops: 4, position: 2)
        fake.personSwitchesAtStep = 4
        do {
            _ = try DesktopNavigator(switcher: fake).walk(on: display) {}
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("changed while dnm was scanning"))
        }
        #expect(fake.pointerRestored)
    }

    @Test func aReadThatFailsStillReturns() throws {
        struct Boom: Error {}
        let fake = FakeSwitcher(desktops: 3, position: 3)
        var reads = 0
        #expect(throws: Boom.self) {
            _ = try DesktopNavigator(switcher: fake).walk(on: display) { reads += 1; if reads == 2 { throw Boom() } }
        }
        #expect(fake.position == 3 && fake.pointerRestored)
    }

    @Test func anInterruptStopsTheWalkAndReturns() throws {
        let fake = FakeSwitcher(desktops: 5, position: 4)
        var reads = 0
        do {
            _ = try DesktopNavigator(switcher: fake).walk(on: display, isInterrupted: { reads == 2 }) { reads += 1 }
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error == .interrupted(scanned: []))
        }
        #expect(reads == 2 && fake.position == 4 && fake.pointerRestored)
    }

    @Test func aWalkThatReachesTheStepLimitFailsInsteadOfStoppingShort() throws {
        let fake = FakeSwitcher(desktops: 40, position: 40)
        do {
            _ = try DesktopNavigator(switcher: fake).walk(on: display) {}
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("more than 32 Desktops"))
        }
        #expect(fake.position == 40, "it went back")
    }

    @Test func aSwitchByThePersonBeforeCtrlCIsReportedNotStepppedBackFrom() throws {
        let fake = FakeSwitcher(desktops: 4, position: 2)
        fake.personSwitchesAtStep = 3
        do {
            _ = try DesktopNavigator(switcher: fake).walk(on: display, isInterrupted: { fake.steps >= 4 }) {}
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect((error.errorDescription ?? "").contains("did not switch back"), "\(error)")
        }
    }
}
