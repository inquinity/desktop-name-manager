import CoreGraphics
import Foundation
import Testing
@testable import DesktopNameCore

/// A display's Desktops as positions, moved by the fake shortcuts.
@MainActor
final class FakeSwitcher: DesktopSwitching {
    var desktops: Int
    var position: Int
    var isTrusted = true
    var shortcutsOn = true
    /// Steps (counted from 1) whose confirmation never arrives, to simulate a lost step.
    var unconfirmedSteps: Set<Int> = []
    private(set) var steps = 0
    private(set) var pointedAt: String?
    private(set) var pointerRestored = false
    private(set) var visitedPositions: [Int] = []

    init(desktops: Int, position: Int) {
        self.desktops = desktops
        self.position = position
    }

    func pointAt(_ display: Display) throws -> CGPoint {
        pointedAt = display.name
        return CGPoint(x: 1, y: 2)
    }

    func restorePointer(_ location: CGPoint) { pointerRestored = location == CGPoint(x: 1, y: 2) }

    func step(_ direction: StepDirection) -> Bool {
        steps += 1
        guard shortcutsOn else { return false }
        let next = direction == .left ? position - 1 : position + 1
        guard (1...desktops).contains(next) else { return false }
        position = next
        visitedPositions.append(next)
        return !unconfirmedSteps.contains(steps)
    }
}

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

    @Test func withoutAccessibilityNothingMovesAndTheReasonIsGiven() throws {
        let fake = FakeSwitcher(desktops: 3, position: 2)
        fake.isTrusted = false
        do {
            try DesktopNavigator(switcher: fake).visit(desktop: 1, on: display) {}
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 1)
            let text = error.errorDescription ?? ""
            #expect(text.contains("Accessibility") && text.contains("Move left a space") && text.contains("Privacy & Security"))
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
}
