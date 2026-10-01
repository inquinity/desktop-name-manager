import Foundation
import Testing

/// FR-016 and FR-017: the built binary links no networking or private framework (constitution I, IV).
@Suite struct LinkedLibrariesTests {
    static let binary: URL? = {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                let candidate = directory.appendingPathComponent(".build/debug/dnm")
                return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }()

    static let forbidden = ["Network.framework", "CFNetwork", "SkyLight", "WebKit", "SystemConfiguration",
                            "NetworkExtension", "MultipeerConnectivity", "libcurl"]

    @Test(.enabled(if: LinkedLibrariesTests.binary != nil))
    func dnmLinksNoNetworkingOrPrivateFramework() throws {
        let binary = try #require(Self.binary)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        process.arguments = ["-L", binary.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(output.contains("libSystem"))   // the listing worked
        let offenders = Self.forbidden.filter { output.contains($0) }
        #expect(offenders.isEmpty, "Linked: \(offenders)")
        #expect(!output.contains("PrivateFrameworks"))
    }
}
