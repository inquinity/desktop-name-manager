import Foundation

/// Runs the built `dnm` binary. Tests use a private store directory, and only commands that cannot
/// change the real wallpaper: validation failures and read-only reports.
enum CLI {
    struct Result {
        var output: String
        var errors: String
        var status: Int32
    }

    static let binary: URL? = {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                let candidate = directory.appendingPathComponent("build.noindex/debug/dnm")
                return FileManager.default.isExecutableFile(atPath: candidate.path) ? candidate : nil
            }
            directory = directory.deletingLastPathComponent()
        }
        return nil
    }()

    /// A temporary store directory, so tests never touch real labels.
    static func scratchStore() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("dnm-cli-test-\(UUID().uuidString)", isDirectory: true).path
    }

    static func run(_ arguments: [String], executable: URL? = nil, store: String = scratchStore()) throws -> Result {
        let process = Process()
        process.executableURL = executable ?? binary
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["DNM_STORE_DIR"] = store
        process.environment = environment
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let output = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errors = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return Result(output: output, errors: errors, status: process.terminationStatus)
    }

    /// The connected displays, from `dnm displays --json`; empty on a headless machine.
    static func connectedDisplayCount() -> Int {
        guard let result = try? run(["displays", "--json"]), result.status == 0,
              let root = try? JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any],
              let displays = root["displays"] as? [[String: Any]] else { return 0 }
        return displays.count
    }
}
