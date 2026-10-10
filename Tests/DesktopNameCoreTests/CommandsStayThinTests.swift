import Foundation
import Testing

/// Spec 008 SC-003: the commands match no display names and count no words of their own. They hand the parser's
/// output to `DisplayArguments` (through `Context`), which is the one place that does.
@Suite struct CommandsStayThinTests {
    @Test(.enabled(if: HygieneScanTests.repositoryRoot != nil))
    func noCommandFileCallsTheResolverOrComparesDisplayNames() throws {
        let root = try #require(HygieneScanTests.repositoryRoot)
        let folder = root.appendingPathComponent("Sources/dnm/Commands")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".swift") }
        #expect(files.count >= 9)
        for file in files {
            let text = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
            #expect(!text.contains("DisplayResolver"), "\(file) calls the resolver")
            #expect(!text.contains("name.lowercased()"), "\(file) compares display names")
            #expect(!text.contains("isReference"), "\(file) decides what a display reference is")
        }
    }
}
