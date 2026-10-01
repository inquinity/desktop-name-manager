import Testing
@testable import DesktopNameCore

@Test func versionIsSet() {
    #expect(!DesktopNameCoreInfo.version.isEmpty)
}
