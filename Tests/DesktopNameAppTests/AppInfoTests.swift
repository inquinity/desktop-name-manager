import DesktopNameApp
import Testing

@Suite struct AppInfoTests {
    @Test func theNameAndTheMenuBarText() {
        #expect(AppInfo.displayName == "Desktop Name Manager")
        #expect(AppInfo.menuBarText == "dnm")
    }
}
