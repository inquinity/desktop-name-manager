import Foundation
import MachO

/// Version of the tool, shown by `dnm --version` and `dnm about`.
public enum DesktopNameCoreInfo {
    /// The version (`MARKETING_VERSION` in Version.xcconfig), as stamped into this binary; "unknown" without a stamp.
    public static var version: String { BuildStamp.read()?.version ?? "unknown" }

    /// What `dnm --version` prints, in the sibling project's form: `0.1.0 (1)` for a release (version and build
    /// number), `0.1.0 (1) 9398ae4` for any other build (with the commit it was built from, and `+` if the tree
    /// had uncommitted changes), so a tester can see exactly what they run. A build without a stamp says so.
    public static var displayVersion: String { displayVersion(stamp: BuildStamp.read()) }

    static func displayVersion(stamp: BuildStamp?) -> String {
        guard let stamp else { return "unknown version (built without a build stamp)" }
        let release = "\(stamp.version) (\(stamp.build))"
        if stamp.isRelease { return release }
        return "\(release) \(stamp.commit)\(stamp.dirty ? "+" : "")"
    }
}

/// Information written into the binary at link time by `scripts/build-stamp.sh` (a Mach-O section, so
/// the repository stays clean and nothing is generated into the source tree).
struct BuildStamp: Equatable {
    /// `MARKETING_VERSION`, for example `0.1.0`.
    var version: String
    /// `CURRENT_PROJECT_VERSION`, the build number.
    var build: String
    var commit: String
    var dirty: Bool
    /// True only for a release build made by the release procedure.
    var isRelease: Bool

    /// Parses the stamp text: lines of `key=value` with keys `version` (x.y.z), `build` (digits), `commit`
    /// (hex), `dirty` (0 or 1) and `kind` (`interim` or `release`).
    static func parse(_ text: String) -> BuildStamp? {
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { values[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces) }
        }
        guard let version = values["version"], version.wholeMatch(of: /[0-9]+\.[0-9]+\.[0-9]+/) != nil,
              let build = values["build"], !build.isEmpty, build.allSatisfy(\.isNumber),
              let commit = values["commit"], !commit.isEmpty, commit.allSatisfy({ $0.isHexDigit }) else { return nil }
        return BuildStamp(version: version, build: build, commit: commit, dirty: values["dirty"] == "1",
                          isRelease: values["kind"] == "release")
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
