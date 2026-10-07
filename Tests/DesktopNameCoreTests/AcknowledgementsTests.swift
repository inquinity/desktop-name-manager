import Foundation
import Testing
@testable import DesktopNameCore

/// Constitution 2.1.0: every third-party component is acknowledged at the version that ships, with its
/// license in Licenses/. `scripts/make-acknowledgements.sh --check` does the checking; this runs it, so a
/// stale Acknowledgements.md (or an upgrade that left a link or `dnm about` behind) fails the tests.
@Suite struct AcknowledgementsTests {
    @Test(.enabled(if: HygieneScanTests.repositoryRoot != nil))
    func acknowledgementsAreUpToDate() throws {
        let root = try #require(HygieneScanTests.repositoryRoot)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [root.appendingPathComponent("scripts/make-acknowledgements.sh").path, "--check"]
        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()
        try process.run()
        let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        #expect(process.terminationStatus == 0, "\(message)")
    }

    @Test func dnmAboutListsEachBinaryComponent() {
        let info = About.info(dataDirectory: URL(fileURLWithPath: "/tmp/x"))
        #expect(info.acknowledgements.map(\.name) == ["swift-argument-parser"])
        #expect(info.acknowledgements.allSatisfy { $0.url.hasPrefix("https://") && $0.url.contains($0.version) })
    }
}
