import Foundation
import Testing
@testable import DesktopNameCore

/// Spec 009: the reminder that old labeled images have piled up. It deletes nothing and does not nag.
@Suite struct NudgeTests {
    func store(withOldMegabytes megabytes: Int) throws -> LabelerHarness {
        let h = try LabelerHarness()
        try h.showOriginal()
        try h.addStamp("Big", lastSeen: h.days(60), createdAt: h.days(60), bytes: megabytes * 1_000_000)
        return h
    }

    @Test func belowTheThresholdThereIsNoNudge() throws {
        let h = try store(withOldMegabytes: 49); defer { h.cleanUp() }
        #expect(try h.labeler.nudgeIfDue() == nil)
        #expect(try h.manifest().maintenance == nil)
    }

    @Test func atTheThresholdItAppearsOnceAndRecordsIt() throws {
        let h = try store(withOldMegabytes: 50); defer { h.cleanUp() }
        let nudge = try #require(try h.labeler.nudgeIfDue())
        #expect(nudge == CleanupNudge(bytes: 50_000_000, labels: 1))
        #expect(try h.manifest().maintenance == Maintenance(nudgedAt: h.clock.now, nudgedBytes: 50_000_000))
        #expect(try h.labeler.nudgeIfDue() == nil, "not again at once")
    }

    @Test func notAgainWithinAWeekUnlessTheAmountDoubled() throws {
        let h = try store(withOldMegabytes: 60); defer { h.cleanUp() }
        #expect(try h.labeler.nudgeIfDue() != nil)
        h.clock.advance(minutes: 3 * 24 * 60)
        try h.addStamp("More", lastSeen: h.days(60), createdAt: h.days(60), bytes: 30_000_000)   // 90 MB: not doubled
        #expect(try h.labeler.nudgeIfDue() == nil)
        try h.addStamp("Much more", lastSeen: h.days(60), createdAt: h.days(60), bytes: 40_000_000)   // 130 MB: more than twice 60
        #expect(try h.labeler.nudgeIfDue()?.bytes == 130_000_000)
    }

    @Test func againAfterAWeek() throws {
        let h = try store(withOldMegabytes: 60); defer { h.cleanUp() }
        #expect(try h.labeler.nudgeIfDue() != nil)
        h.clock.advance(minutes: 6 * 24 * 60 + 23 * 60)
        #expect(try h.labeler.nudgeIfDue() == nil)
        h.clock.advance(minutes: 2 * 60)
        #expect(try h.labeler.nudgeIfDue() != nil)
    }

    @Test func aCleanupResetsIt() throws {
        let h = try store(withOldMegabytes: 60); defer { h.cleanUp() }
        #expect(try h.labeler.nudgeIfDue() != nil)
        try h.labeler.carryOut(try h.labeler.cleanupPlan(days: 30))
        try h.addStamp("Big again", lastSeen: h.days(60), createdAt: h.days(60), bytes: 60_000_000)
        #expect(try h.labeler.nudgeIfDue() != nil, "reset, so due again at once")
    }

    @Test func itCountsOnlyWhatCleanupCouldFree() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        let original = try h.showOriginal()
        try h.labeler.setLabel(LabelText("Showing"), on: h.display)
        try h.store.transaction { $0.stamps[0].lastSeen = h.days(60); $0.stamps[0].createdAt = h.days(60) }
        try h.addStamp("Recent", lastSeen: h.days(3), bytes: 80_000_000)         // seen lately: not old
        try h.addStamp("Old but small", lastSeen: h.days(60), createdAt: h.days(60), bytes: 10_000_000)
        _ = original
        #expect(try h.labeler.nudgeIfDue() == nil, "the big one is recent and the showing one is on screen")
    }

    @Test func noStoreMeansNoNudge() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        #expect(try h.labeler.nudgeIfDue() == nil)
        #expect(!FileManager.default.fileExists(atPath: h.store.directory.path))
    }

    @Test func itDeletesNothing() throws {
        let h = try store(withOldMegabytes: 80); defer { h.cleanUp() }
        _ = try h.labeler.nudgeIfDue()
        #expect(h.storeFiles.count == 1)
        #expect(try h.manifest().stamps.count == 1)
    }

    @Test func aThousandLabelsAreEstimatedQuickly() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        // One transaction and small files: a thousand separate manifest rewrites would only slow the test down.
        var stamps: [Stamp] = []
        for index in 0..<1_000 {
            let id = UUID()
            stamps.append(Stamp(id: id, fileName: "\(id.uuidString).dnm.jpg", label: Fixtures.label("Label \(index)"), original: Fixtures.original(),
                                displayUUID: h.display.uuid, displayName: "Display A", pixelWidth: 800, pixelHeight: 500,
                                createdAt: h.days(100), reuseKey: nil, lastSeen: h.days(Double(index % 90))))
            try h.store.writeStampFile(Data(count: 1_000), named: stamps[index].fileName)
        }
        try h.store.transaction { $0.stamps = stamps }
        let manifest = try h.manifest()
        let clock = ContinuousClock()
        var best = Duration.seconds(10)
        for _ in 0..<5 {
            let elapsed = try clock.measure { _ = try h.labeler.reclaimableBytes(in: manifest) }
            best = min(best, elapsed)
        }
        #expect(best < .milliseconds(50), "took \(best)")
    }
}
