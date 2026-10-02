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
        try ensureDirectory()
        let lock = try StoreLock(at: lockURL)
        // Hold the lock until the manifest has been saved: the object must outlive the whole body.
        defer { withExtendedLifetime(lock) {} }
        var manifest = hasManifest ? try loadManifest() : Manifest()
        let result = try body(&manifest)
        do {
            try writePrivately(Self.makeEncoder().encode(manifest), to: manifestURL)
        } catch {
            throw DnmError.storeNotWritable(error.localizedDescription)
        }
        return result
    }

    private func ensureDirectory() throws {
        do {
            // Owner-only: the store holds label text, original paths and copies of the user's wallpaper.
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
        } catch {
            throw DnmError.storeNotWritable(error.localizedDescription)
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

    /// Atomic write, then owner-only permissions.
    private func writePrivately(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func stampFileExists(named fileName: String) -> Bool {
        Cleanup.isOurFileName(fileName) && FileManager.default.fileExists(atPath: fileURL(named: fileName).path)
    }

    /// Deletes one of our stamp files. Anything that is not exactly `<uuid>.dnm.<ext>` is ignored, so a
    /// name carrying a path can never reach outside the store.
    public func removeFile(named fileName: String) {
        guard Cleanup.isOurFileName(fileName) else { return }
        try? FileManager.default.removeItem(at: fileURL(named: fileName))
    }
}
