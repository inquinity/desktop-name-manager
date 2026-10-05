import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct BuildStampTests {
    @Test func aStampParsesFromItsText() throws {
        let stamp = try #require(BuildStamp.parse("commit=9398ae4\ndirty=1\nkind=interim\n"))
        #expect(stamp == BuildStamp(commit: "9398ae4", dirty: true, isRelease: false))
        #expect(BuildStamp.parse("commit=abc123\ndirty=0\nkind=release")?.isRelease == true)
    }

    @Test(arguments: ["", "commit=\n", "commit=not-hex!\n", "dirty=1\nkind=interim\n", "garbage"])
    func aMalformedStampIsIgnored(_ text: String) {
        #expect(BuildStamp.parse(text) == nil)
    }

    @Test func interimBuildsShowTheCommit() {
        let clean = BuildStamp(commit: "9398ae4", dirty: false, isRelease: false)
        let dirty = BuildStamp(commit: "9398ae4", dirty: true, isRelease: false)
        #expect(DesktopNameCoreInfo.displayVersion(stamp: clean) == "\(DesktopNameCoreInfo.version)-dev+9398ae4")
        #expect(DesktopNameCoreInfo.displayVersion(stamp: dirty) == "\(DesktopNameCoreInfo.version)-dev+9398ae4.dirty")
    }

    @Test func aReleaseBuildShowsThePlainVersion() {
        let release = BuildStamp(commit: "9398ae4", dirty: false, isRelease: true)
        #expect(DesktopNameCoreInfo.displayVersion(stamp: release) == DesktopNameCoreInfo.version)
    }

    @Test func aBuildWithoutAStampSaysSoInsteadOfLookingLikeARelease() {
        #expect(DesktopNameCoreInfo.displayVersion(stamp: nil) == "\(DesktopNameCoreInfo.version)-dev+unknown")
    }

    @Test func aTestRunnerHasNoStamp() {
        #expect(BuildStamp.read() == nil)
    }
}
