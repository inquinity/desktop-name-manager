import Foundation

/// The tool's storage: one directory holding a versioned manifest, a lock file and stamp images.
public final class Store: Sendable {
    /// Shared by the CLI and the later app, so it does not depend on any app bundle.
    public static let storeName: String = {
        let base = "com.altmansoftwaredesign.desktop-name-manager"
        #if DEBUG
        return base + ".dev"
        #else
        return base
        #endif
    }()

    public static let manifestFileName = "manifest.json"
    public static let lockFileName = "manifest.lock"
    /// Name of the environment variable that overrides the store directory (tests, live checks).
    public static let directoryOverrideVariable = "DNM_STORE_DIR"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `DNM_STORE_DIR` if set, otherwise `~/Library/Application Support/<store name>/`.
    public static func defaultDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment[directoryOverrideVariable], !override.isEmpty {
            return URL(fileURLWithPath: (override as NSString).expandingTildeInPath, isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent(storeName, isDirectory: true)
    }

    public var manifestURL: URL { directory.appendingPathComponent(Self.manifestFileName) }
    var lockURL: URL { directory.appendingPathComponent(Self.lockFileName) }

    public func fileURL(named fileName: String) -> URL { directory.appendingPathComponent(fileName) }

    public var hasManifest: Bool { FileManager.default.fileExists(atPath: manifestURL.path) }

    // MARK: - Manifest

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    /// Reads the manifest without changing anything. A missing manifest is an empty one.
    public func readManifest() throws -> Manifest {
        guard hasManifest else { return Manifest() }
        return try loadManifest()
    }

    private func loadManifest() throws -> Manifest {
        let data: Data
        do { data = try Data(contentsOf: manifestURL) } catch {
            throw DnmError.failure("Cannot read the stored data: \(error.localizedDescription)")
        }
        struct VersionOnly: Decodable { var schemaVersion: Int }
        let version = (try? Self.makeDecoder().decode(VersionOnly.self, from: data))?.schemaVersion
        if let version, version > Manifest.currentSchemaVersion {
            throw DnmError.newerManifest(found: version, supported: Manifest.currentSchemaVersion)
        }
        let manifest: Manifest
        do { manifest = try Self.makeDecoder().decode(Manifest.self, from: data) } catch {
            throw DnmError.failure("The stored data is damaged and was left alone: \(error.localizedDescription)")
        }
        // Every stamp file name must be one of ours. A name with a path in it (such as "../x") would let
        // cleanup delete, or the tool set as wallpaper, a file outside the store.
        guard manifest.stamps.allSatisfy({ Cleanup.isOurFileName($0.fileName) }) else {
            throw DnmError.failure("The stored data refers to a file outside the store and was left alone.")
        }
        return manifest
    }

    /// Runs `body` on the manifest under the lock and saves the result atomically.
    /// A store that cannot be written fails here, before the caller changes any wallpaper.
    @discardableResult
    public func transaction<T>(_ body: (inout Manifest) throws -> T) throws -> T {
        try exclusive {
            var manifest = hasManifest ? try loadManifest() : Manifest()
            let result = try body(&manifest)
            manifest.schemaVersion = Manifest.currentSchemaVersion
            do {
                try writePrivately(Self.makeEncoder().encode(manifest), to: manifestURL)
            } catch {
                throw DnmError.storeNotWritable(error.localizedDescription)
            }
            return result
        }
    }

    /// Holds the store lock for the whole of `body`, so an operation can read the manifest, decide, change
    /// the wallpaper and save as one step that no other run can interleave with. Re-entrant on the same
    /// thread, so `transaction` and `Cleanup` can be used inside it.
    public func exclusive<T>(_ body: () throws -> T) throws -> T {
        let held = Thread.current.threadDictionary
        let key = "dnm.store.lock.held." + directory.path
        if held[key] != nil { return try body() }
        try ensureDirectory()
        let lock = try StoreLock(at: lockURL)
        held[key] = true
        defer {
            held.removeObject(forKey: key)
            // The lock object must outlive the whole body.
            withExtendedLifetime(lock) {}
        }
        return try body()
    }

    /// Creates the store if needed and makes it owner-only: it holds label text, original paths and copies of the
    /// user's wallpaper. A folder that already exists (an older store, or a `DNM_STORE_DIR` the user made) is
    /// tightened too, and one owned by another account is refused.
    private func ensureDirectory() throws {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            throw DnmError.storeNotWritable(error.localizedDescription)
        }
        var info = stat()
        guard stat(directory.path, &info) == 0 else {
            throw DnmError.storeNotWritable(String(cString: strerror(errno)))
        }
        guard info.st_uid == getuid() else {
            throw DnmError.storeNotWritable("\(directory.lastPathComponent) belongs to another account")
        }
        if info.st_mode & 0o077 != 0 {
            guard chmod(directory.path, 0o700) == 0 else {
                throw DnmError.storeNotWritable(String(cString: strerror(errno)))
            }
        }
    }

    // MARK: - Stamp files

    public func writeStampFile(_ data: Data, named fileName: String) throws {
        guard Cleanup.isOurFileName(fileName) else {
            throw DnmError.failure("Refusing to write \"\(fileName)\": it is not a name this tool uses.")
        }
        try ensureDirectory()
        do { try writePrivately(data, to: fileURL(named: fileName)) } catch {
            throw DnmError.storeNotWritable(error.localizedDescription)
        }
    }

    /// Atomic and owner-only from the start: the data goes to a new temporary file created with 0600, which then
    /// replaces the target, so the file is never readable by others, not even briefly.
    private func writePrivately(_ data: Data, to url: URL) throws {
        let temporary = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            guard rename(temporary.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        } catch {
            unlink(temporary.path)
            throw error
        }
    }

    public func stampFileExists(named fileName: String) -> Bool {
        Cleanup.isOurFileName(fileName) && FileManager.default.fileExists(atPath: fileURL(named: fileName).path)
    }

    /// Deletes one of our stamp files. Anything that is not exactly `<uuid>.dnm.<ext>` is ignored, so a
    /// name carrying a path can never reach outside the store, and only a regular file is deleted (never a
    /// folder, which would go recursively, nor what a symlink points to).
    public func removeFile(named fileName: String) {
        guard Cleanup.isOurFileName(fileName) else { return }
        let url = fileURL(named: fileName)
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
