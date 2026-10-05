import Foundation
import MachO

/// Version of the core library, shown by `dnm --version`.
public enum DesktopNameCoreInfo {
    /// The version number: the single source for the tool's reported version.
    public static let version = "0.1.0"

    /// What `dnm --version` prints. Release builds print the plain version. Every other build prints
    /// `<version>-dev+<commit>` (with `.dirty` if the tree had uncommitted changes), so a tester can see
    /// exactly which commit they are running. A build with no stamp prints `<version>-dev+unknown`.
    public static var displayVersion: String { displayVersion(stamp: BuildStamp.read()) }

    static func displayVersion(stamp: BuildStamp?) -> String {
        guard let stamp else { return "\(version)-dev+unknown" }
        if stamp.isRelease { return version }
        return "\(version)-dev+\(stamp.commit)\(stamp.dirty ? ".dirty" : "")"
    }
}

/// Information written into the binary at link time by `scripts/build-stamp.sh` (a Mach-O section, so
/// the repository stays clean and nothing is generated into the source tree).
struct BuildStamp: Equatable {
    var commit: String
    var dirty: Bool
    /// True only for a release build made by the release procedure.
    var isRelease: Bool

    /// Parses the stamp text: lines of `key=value` with keys `commit`, `dirty` (0 or 1) and `kind` (`interim` or `release`).
    static func parse(_ text: String) -> BuildStamp? {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { values[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces) }
        }
        guard let commit = values["commit"], !commit.isEmpty,
              commit.allSatisfy({ $0.isHexDigit }) else { return nil }
        return BuildStamp(commit: commit, dirty: values["dirty"] == "1", isRelease: values["kind"] == "release")
    }

    /// The stamp of the running program, if it was built with one.
    static func read() -> BuildStamp? {
        // Image 0 is the main executable.
        guard let header = _dyld_get_image_header(0) else { return nil }
        return header.withMemoryRebound(to: mach_header_64.self, capacity: 1) { header64 in
            var size: UInt = 0
            guard let bytes = getsectiondata(header64, "__DNM", "build", &size), size > 0 else { return nil }
            let text = String(decoding: UnsafeBufferPointer(start: bytes, count: Int(size)), as: UTF8.self)
            return parse(text)
        }
    }
}
