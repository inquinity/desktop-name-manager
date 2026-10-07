import Foundation
import Testing
@testable import DesktopNameCore

/// Findings from the first security pass (review-notes.md): the manifest is data on disk that another
/// process of the same user could edit, so nothing in it may steer a delete or write outside the store.
@Suite struct StoreSecurityTests {
    func makeStore() throws -> (Store, URL) {
        let root = try SyntheticImages.temporaryDirectory()
        return (Store(directory: root.appendingPathComponent("store", isDirectory: true)), root)
    }

    /// Writes a manifest whose single stamp is long retired and carries the given file name.
    func plantHostileManifest(_ store: Store, fileName: String) throws {
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        var stamp = Fixtures.stamp(state: .retired(at: Date(timeIntervalSince1970: 0), reason: .removed))
        stamp.fileName = fileName
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(Manifest(stamps: [stamp])).write(to: store.manifestURL)
    }

    @Test(arguments: ["../victim.txt", "../../victim.txt", "/etc/hosts", "sub/\(UUID().uuidString).dnm.jpg", "..", "victim.txt"])
    func aManifestNamingAFileOutsideTheStoreIsRefusedAndNothingIsDeleted(_ fileName: String) throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let victim = root.appendingPathComponent("victim.txt")
        try Data("precious".utf8).write(to: victim)
        try plantHostileManifest(store, fileName: fileName)
        let manifestBefore = try Data(contentsOf: store.manifestURL)

        #expect(throws: DnmError.self) { try store.readManifest() }
        try? Cleanup.run(store: store, now: Date())   // would have deleted the victim before the fix
        #expect(try Data(contentsOf: victim) == Data("precious".utf8))
        #expect(try Data(contentsOf: store.manifestURL) == manifestBefore)   // left alone
    }

    @Test func removeFileIgnoresNamesCarryingAPath() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let victim = root.appendingPathComponent("victim.txt")
        try Data("precious".utf8).write(to: victim)
        store.removeFile(named: "../victim.txt")
        #expect(FileManager.default.fileExists(atPath: victim.path))
        #expect(!store.stampFileExists(named: "../victim.txt"))
    }

    @Test func removeFileNeverDeletesAFolderWithOurName() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = store.fileURL(named: "\(UUID().uuidString).dnm.jpg")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("inside".utf8).write(to: folder.appendingPathComponent("keep.txt"))
        store.removeFile(named: folder.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("keep.txt").path))
    }

    @Test func removeFileNeverReachesThroughALink() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("target.jpg")
        try Data("precious".utf8).write(to: target)
        let link = store.fileURL(named: "\(UUID().uuidString).dnm.jpg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        store.removeFile(named: link.lastPathComponent)
        #expect(FileManager.default.fileExists(atPath: target.path))
    }

    @Test func writeStampFileRefusesNamesThatAreNotOurs() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: DnmError.self) { try store.writeStampFile(Data([1]), named: "../evil.txt") }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("evil.txt").path))
    }

    @Test func theStoreIsOwnerOnly() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try store.transaction { _ in }
        let name = "\(UUID().uuidString).dnm.jpg"
        try store.writeStampFile(Data([1, 2]), named: name)
        func mode(_ url: URL) throws -> Int {
            (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue ?? -1
        }
        #expect(try mode(store.directory) == 0o700)
        #expect(try mode(store.manifestURL) == 0o600)
        #expect(try mode(store.fileURL(named: name)) == 0o600)
    }

    @Test func anExistingLooseStoreFolderIsTightened() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o755])
        try store.transaction { _ in }
        let mode = (try FileManager.default.attributesOfItem(atPath: store.directory.path)[.posixPermissions] as? NSNumber)?.intValue
        #expect(mode == 0o700)
    }

    @Test func filesAreOwnerOnlyEvenWithAPermissiveUmask() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let previous = umask(0)
        defer { umask(previous) }
        try store.transaction { _ in }
        let name = "\(UUID().uuidString).dnm.jpg"
        try store.writeStampFile(Data([1, 2, 3]), named: name)
        for url in [store.manifestURL, store.fileURL(named: name)] {
            let mode = (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue
            #expect(mode == 0o600, "\(url.lastPathComponent)")
        }
        #expect(try Data(contentsOf: store.fileURL(named: name)) == Data([1, 2, 3]))
        // No temporary file is left behind.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: store.directory.path).filter { $0.hasSuffix(".tmp") }
        #expect(leftovers.isEmpty)
    }

    @Test func aPlantedSymlinkAsTheLockFileIsNotFollowed() throws {
        let (store, root) = try makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("target.txt")
        try Data("untouched".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: store.lockURL, withDestinationURL: target)
        #expect(throws: DnmError.self) { try store.transaction { _ in } }
        #expect(try Data(contentsOf: target) == Data("untouched".utf8))
    }
}

/// Findings from the cloud review: decisions must be made under the lock, not from a manifest read before it.
@Suite struct ExclusiveOperationTests {
    @Test func anOperationHoldsTheLockForItsWholeRun() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()

        // A second run on another thread must wait for the lock this thread holds.
        let finished = DispatchSemaphore(value: 0)
        try h.store.exclusive {
            let worker = Thread {
                _ = try? h.labeler.setLabel(LabelText("Waits"), on: h.display)
                finished.signal()
            }
            worker.start()
            Thread.sleep(forTimeInterval: 0.4)
            #expect(h.system.setCalls.isEmpty, "the second run must not proceed while the lock is held")
        }
        #expect(finished.wait(timeout: .now() + 20) == .success)
        #expect(h.system.setCalls.count == 1)
        #expect(try h.manifest().stamps.count == 1)
    }

    @Test func theLockIsReentrantOnTheSameThread() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.store.exclusive {
            try h.store.transaction { $0.changes.append(Fixtures.change()) }
            try h.store.exclusive { _ = try h.store.readManifest() }
        }
        #expect(try h.manifest().changes.count == 1)
    }

    @Test func twoRunsLabelingTheSameDisplayLeaveExactlyOneActiveStamp() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        try h.labeler.setLabel(LabelText("First"), on: h.display)

        // Two "processes" (two stores on the same directory, each its own thread) replace the label at once.
        // The fake wallpaper system is shared, so run them one after the other through the lock.
        let group = DispatchGroup()
        for name in ["Second", "Third"] {
            group.enter()
            let thread = Thread {
                let other = DesktopLabeler(system: h.system, store: Store(directory: h.store.directory), time: h.clock)
                _ = try? other.setLabel(LabelText(name), on: h.display)
                group.leave()
            }
            thread.start()
        }
        #expect(group.wait(timeout: .now() + 30) == .success)

        let stamps = try h.manifest().stamps
        #expect(stamps.filter(\.isActive).count == 1)
        #expect(try h.manifest().changes.count == 1)
        #expect(Set(stamps.map(\.fileName)).count == stamps.count)
    }

    @Test func removeAndUndoWithNothingStoredDoNotCreateTheStore() throws {
        let h = try LabelerHarness(); defer { h.cleanUp() }
        try h.showOriginal()
        #expect(try h.labeler.removeLabel(on: h.display).outcome == .noLabel)
        #expect(throws: DnmError.self) { try h.labeler.undoLastChange(on: h.display) }
        #expect(!FileManager.default.fileExists(atPath: h.store.directory.path))
    }
}
