import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct BuildStampTests {
    @Test func aStampParsesFromItsText() throws {
        let stamp = try #require(BuildStamp.parse("version=0.1.0\nbuild=1\ncommit=9398ae4\ndirty=1\nkind=interim\n"))
        #expect(stamp == BuildStamp(version: "0.1.0", build: "1", commit: "9398ae4", dirty: true, isRelease: false))
        #expect(BuildStamp.parse("version=1.2.3\nbuild=17\ncommit=abc123\ndirty=0\nkind=release")?.isRelease == true)
    }

    @Test(arguments: ["", "commit=\n", "version=0.1.0\nbuild=1\ncommit=not-hex!\n", "build=1\ncommit=abc\n",
                      "version=0.1\nbuild=1\ncommit=abc\n", "version=0.1.0\nbuild=x\ncommit=abc\n", "garbage"])
    func aMalformedStampIsIgnored(_ text: String) {
        #expect(BuildStamp.parse(text) == nil)
    }

    @Test func aReleaseBuildShowsVersionAndBuildNumber() {
        let release = BuildStamp(version: "0.1.0", build: "1", commit: "9398ae4", dirty: false, isRelease: true)
        #expect(DesktopNameCoreInfo.displayVersion(stamp: release) == "0.1.0 (1)")
    }

    @Test func otherBuildsAlsoShowTheCommit() {
        let clean = BuildStamp(version: "0.1.0", build: "1", commit: "9398ae4", dirty: false, isRelease: false)
        let dirty = BuildStamp(version: "0.1.0", build: "1", commit: "9398ae4", dirty: true, isRelease: false)
        #expect(DesktopNameCoreInfo.displayVersion(stamp: clean) == "0.1.0 (1) 9398ae4")
        #expect(DesktopNameCoreInfo.displayVersion(stamp: dirty) == "0.1.0 (1) 9398ae4+")
    }

    @Test func aBuildWithoutAStampSaysSoInsteadOfLookingLikeARelease() {
        #expect(DesktopNameCoreInfo.displayVersion(stamp: nil) == "unknown version (built without a build stamp)")
    }

    @Test func aTestRunnerHasNoStamp() {
        #expect(BuildStamp.read() == nil)
        #expect(DesktopNameCoreInfo.version == "unknown")
    }
}
