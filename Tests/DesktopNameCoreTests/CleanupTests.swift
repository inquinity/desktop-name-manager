import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct CleanupTests {
    struct Harness {
        let root: URL
        let store: Store
        let clock = FakeTimeSource()

        init() throws {
            root = try SyntheticImages.temporaryDirectory()
            store = Store(directory: root.appendingPathComponent("store", isDirectory: true))
            try store.transaction { _ in }   // creates directory and manifest
        }

        func cleanUp() { try? FileManager.default.removeItem(at: root) }

        @discardableResult
        func add(_ stamp: Stamp, fileAge minutes: Double = 0) throws -> Stamp {
            try store.transaction { $0.stamps.append(stamp) }
            try writeFile(stamp.fileName, ageMinutes: minutes)
            return stamp
        }

        func writeFile(_ name: String, ageMinutes: Double = 0) throws {
            try store.writeStampFile(Data([1, 2, 3]), named: name)
            try FileManager.default.setAttributes([.modificationDate: clock.now.addingTimeInterval(-ageMinutes * 60)],
                                                  ofItemAtPath: store.fileURL(named: name).path)
        }

        func exists(_ name: String) -> Bool { store.stampFileExists(named: name) }
        func run() throws { try Cleanup.run(store: store, now: clock.now) }
    }

    @Test func coolDownIsThirtyMinutes() {
        #expect(Cleanup.coolDown == 1800)
    }

    @Test func nothingIsDeletedBeforeTheCoolDown() throws {
        let h = try Harness(); defer { h.cleanUp() }
        let stamp = try h.add(Fixtures.stamp(state: .retired(at: h.clock.now, reason: .removed)))
        h.clock.advance(minutes: 29)
        try h.run()
        #expect(h.exists(stamp.fileName))
        #expect(try h.store.readManifest().stamps.count == 1)
    }

    @Test func retiredStampsAreDeletedAfterTheCoolDown() throws {
        let h = try Harness(); defer { h.cleanUp() }
        let stamp = try h.add(Fixtures.stamp(state: .retired(at: h.clock.now, reason: .replaced)))
        h.clock.advance(minutes: 31)
        try h.run()
        #expect(!h.exists(stamp.fileName))
        #expect(try h.store.readManifest().stamps.isEmpty)
    }

    @Test func activeStampsAreNeverDeleted() throws {
        let h = try Harness(); defer { h.cleanUp() }
        let stamp = try h.add(Fixtures.stamp(), fileAge: 60 * 24 * 30)
        h.clock.advance(minutes: 60 * 24 * 30)
        try h.run()
        #expect(h.exists(stamp.fileName))
        #expect(try h.store.readManifest().stamps.count == 1)
    }

    @Test func unreferencedOurFilesAreDeletedOnlyAfterTheCoolDown() throws {
        let h = try Harness(); defer { h.cleanUp() }
        let young = "\(UUID().uuidString).dnm.jpg", old = "\(UUID().uuidString).dnm.png"
        try h.writeFile(young, ageMinutes: 10)
        try h.writeFile(old, ageMinutes: 45)
        try h.run()
        #expect(h.exists(young))
        #expect(!h.exists(old))
    }

    @Test func otherFilesAreNeverTouched() throws {
        let h = try Harness(); defer { h.cleanUp() }
        let names = ["photo.jpg", "\(UUID().uuidString).jpg", "\(UUID().uuidString).dnm", "notes.txt", "x.dnm.jpg", "\(UUID().uuidString).dnm.jpg.bak"]
        for name in names { try h.writeFile(name, ageMinutes: 60 * 24) }
        let subfolder = h.store.fileURL(named: "keep")
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        try Data([9]).write(to: subfolder.appendingPathComponent("\(UUID().uuidString).dnm.jpg"))
        h.clock.advance(minutes: 60 * 24)
        try h.run()
        for name in names { #expect(h.exists(name), "\(name) must survive") }
        #expect(FileManager.default.fileExists(atPath: subfolder.path))
        #expect(h.store.hasManifest)
        #expect(FileManager.default.fileExists(atPath: h.store.lockURL.path))
    }

    @Test func nothingHappensInAFolderWithoutOurManifest() throws {
        let root = try SyntheticImages.temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let name = "\(UUID().uuidString).dnm.jpg"
        try Data([1]).write(to: root.appendingPathComponent(name))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: root.appendingPathComponent(name).path)
        try Cleanup.run(store: Store(directory: root), now: Date())
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(Store.manifestFileName).path))
    }

    @Test func expiredUndoRecordsAreDropped() throws {
        let h = try Harness(); defer { h.cleanUp() }
        try h.store.transaction { $0.changes = [Fixtures.change(at: h.clock.now)] }
        h.clock.advance(minutes: 10)
        try h.run()
        #expect(try h.store.readManifest().changes.count == 1)
        h.clock.advance(minutes: 25)
        try h.run()
        #expect(try h.store.readManifest().changes.isEmpty)
    }

    @Test func manyRelabelingsLeaveOnlyActiveAndRecentStamps() throws {
        let h = try Harness(); defer { h.cleanUp() }
        // 100 consecutive relabelings, one per minute; each replaces the previous stamp.
        var active: Stamp?
        for _ in 0..<100 {
            h.clock.advance(minutes: 1)
            if let previous = active {
                try h.store.transaction { manifest in
                    let index = manifest.stamps.firstIndex { $0.id == previous.id }!
                    manifest.stamps[index].state = .retired(at: h.clock.now, reason: .replaced)
                }
            }
            active = try h.add(Fixtures.stamp(), fileAge: 0)
            try h.run()
        }
        h.clock.advance(minutes: 31)
        try h.run()
        let remaining = try h.store.readManifest().stamps
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == active?.id)
        let files = try FileManager.default.contentsOfDirectory(atPath: h.store.directory.path).filter(Cleanup.isOurFileName)
        #expect(files == [active!.fileName])
    }

    @Test func fileNamePatternIsExact() {
        #expect(Cleanup.isOurFileName("\(UUID().uuidString).dnm.jpg"))
        #expect(Cleanup.isOurFileName("\(UUID().uuidString.lowercased()).dnm.heic"))
        #expect(!Cleanup.isOurFileName("manifest.json"))
        #expect(!Cleanup.isOurFileName("manifest.lock"))
        #expect(!Cleanup.isOurFileName("\(UUID().uuidString).jpg"))
    }
}
