import Foundation
import Testing

/// FR-016, FR-017 and constitution principles I and IV: the core uses public APIs only and has no
/// way to reach the network. These checks fail if a forbidden API appears in the sources.
@Suite struct PrivacyScanTests {
    static let sourcesDirectory: URL? = HygieneScanTests.repositoryRoot?.appendingPathComponent("Sources")

    /// Tokens that must not appear in shipping code.
    static let forbidden: [(token: String, why: String)] = [
        ("URLSession", "networking"), ("URLRequest", "networking"), ("import Network", "networking"),
        ("NWConnection", "networking"), ("NWListener", "networking"), ("CFNetwork", "networking"),
        ("CFSocket", "networking"), ("CFStream", "networking"), ("getaddrinfo", "networking"),
        ("socket(", "networking"), ("WKWebView", "networking"), ("import WebKit", "networking"),
        ("dlopen", "private framework loading"), ("dlsym", "private framework loading"),
        ("SkyLight", "private framework"), ("PrivateFrameworks", "private framework"),
        ("CGSConnection", "private framework"), ("SLSCopy", "private framework"),
        ("CoreSymbolication", "private framework"), ("Telemetry", "telemetry"), ("Analytics", "telemetry"),
    ]

    static func swiftFiles() -> [URL] {
        guard let root = sourcesDirectory,
              let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    /// Forbidden tokens in code (not in comments or string literals).
    static func findings(in text: String, file: String) -> [String] {
        var found: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            // Blank string literals first, so a "//" inside a URL string does not hide the code after it.
            let withoutStrings = line.element.replacingOccurrences(of: #""(\\.|[^"\\])*""#, with: "\"\"", options: .regularExpression)
            let code = withoutStrings.components(separatedBy: "//").first ?? ""
            for (token, why) in forbidden where code.contains(token) {
                found.append("\(file):\(line.offset + 1) \(token) (\(why))")
            }
        }
        return found
    }

    @Test(.enabled(if: PrivacyScanTests.sourcesDirectory != nil))
    func sourcesContainNoNetworkOrPrivateApiUse() throws {
        let files = Self.swiftFiles()
        #expect(!files.isEmpty)
        var findings: [String] = []
        for file in files {
            findings += Self.findings(in: try String(contentsOf: file, encoding: .utf8), file: file.lastPathComponent)
        }
        #expect(findings.isEmpty, "Forbidden APIs: \(findings.joined(separator: "; "))")
    }

    @Test func aUrlStringDoesNotHideForbiddenCodeAfterIt() {
        let line = "let a = \"https://example.com\"; let b = URLSession.shared"
        #expect(!Self.findings(in: line, file: "x").isEmpty)
        #expect(Self.findings(in: "let c = 1 // mentions URLSession in a comment", file: "x").isEmpty)
        #expect(Self.findings(in: "let d = \"URLSession\"", file: "x").isEmpty)
    }

    @Test func theScanFindsWhatItShouldFind() {
        #expect(Self.forbidden.contains { "let s = URLSession.shared".contains($0.token) })
        #expect(Self.forbidden.contains { "dlopen(\"x\")".contains($0.token) })
    }
}
