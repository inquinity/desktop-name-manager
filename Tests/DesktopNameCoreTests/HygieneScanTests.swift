import Foundation
import Testing

/// FR-021 and constitution principle VIII: the repository is public, so tracked files must not
/// contain personal paths, user names, display or Space identifiers, keychain profile names or
/// personal images. The patterns are assembled from pieces so this file does not match itself.
@Suite struct HygieneScanTests {
    static let repositoryRoot: URL? = {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) { return directory }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }()

    static func trackedFiles() throws -> [String] {
        guard let root = repositoryRoot else { return [] }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "ls-files", "-z"]
        process.currentDirectoryURL = root
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
    }

    struct Finding: CustomStringConvertible {
        var file: String
        var line: Int
        var rule: String
        var description: String { "\(file):\(line): \(rule)" }
    }

    /// Names that are clearly placeholders, not a person.
    static let placeholderUsers: Set<String> = ["Shared", "Guest", "example", "user", "username", "you", "name", "yourname", "me"]

    static func scan(_ text: String, file: String) -> [Finding] {
        var findings: [Finding] = []
        let homePrefix = "/Us" + "ers/"
        let uuidPattern = try! NSRegularExpression(pattern: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
        let keychainProfile = ["altman", "notary"].joined(separator: "-")

        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineText = String(line)
            if lineText.contains("hygiene-allow:") { continue }
            var searchRange = lineText.startIndex..<lineText.endIndex
            while let range = lineText.range(of: homePrefix, range: searchRange) {
                let rest = lineText[range.upperBound...]
                let name = String(rest.prefix { $0 != "/" && $0 != " " && $0 != "\"" && $0 != "`" && $0 != "'" })
                if !name.isEmpty, !placeholderUsers.contains(name), !name.hasPrefix("<"), !name.hasPrefix("$") {
                    findings.append(Finding(file: file, line: index + 1, rule: "personal home path"))
                }
                searchRange = range.upperBound..<lineText.endIndex
            }
            let whole = NSRange(lineText.startIndex..., in: lineText)
            if uuidPattern.firstMatch(in: lineText, range: whole) != nil {
                findings.append(Finding(file: file, line: index + 1, rule: "UUID-shaped identifier (display or Space id?)"))
            }
            if lineText.contains(keychainProfile) {
                findings.append(Finding(file: file, line: index + 1, rule: "keychain profile name"))
            }
        }
        return findings
    }

    @Test(.enabled(if: HygieneScanTests.repositoryRoot != nil))
    func trackedFilesContainNoPersonalData() throws {
        let root = try #require(Self.repositoryRoot)
        var findings: [Finding] = []
        for file in try Self.trackedFiles() {
            guard let data = try? Data(contentsOf: root.appendingPathComponent(file)),
                  let text = String(data: data, encoding: .utf8) else { continue }
            findings += Self.scan(text, file: file)
        }
        #expect(findings.isEmpty, "Found: \(findings.map(\.description).joined(separator: "; "))")
    }

    @Test(.enabled(if: HygieneScanTests.repositoryRoot != nil))
    func noImagesAreTrackedOutsideDocs() throws {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tif", "tiff", "gif"]
        let offenders = try Self.trackedFiles().filter {
            imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) && !$0.hasPrefix("docs/")
        }
        #expect(offenders.isEmpty, "Tracked images (personal wallpapers must stay in wallpaper-samples/): \(offenders)")
    }

    @Test func theScannerCatchesWhatItShould() {
        let homePath = "/Us" + "ers/" + "someone" + "/Pictures"
        #expect(!Self.scan(homePath, file: "x").isEmpty)
        #expect(Self.scan("/Us" + "ers/<name>/Pictures and /Us" + "ers/Shared", file: "x").isEmpty)
        #expect(!Self.scan("display 0A1B2C3D-0000-1111-2222-333344445555", file: "x").isEmpty)
        #expect(!Self.scan("profile " + ["altman", "notary"].joined(separator: "-"), file: "x").isEmpty)
        #expect(Self.scan("nothing sensitive here", file: "x").isEmpty)
    }
}
