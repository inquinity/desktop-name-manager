import Foundation

/// When the welcome window shows (spec 014, FR-017a): on the first launch for this user, never at a login start, and
/// never again once dismissed. OK and closing the window both count as dismissing it.
@MainActor
public struct WelcomeState {
    private let settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    /// True when this launch shows the welcome window. `loginStart` is true when macOS opened the app at login.
    public func shouldShow(loginStart: Bool) -> Bool {
        !settings.welcomeShown && !loginStart
    }

    /// OK, Return or closing the window.
    public func dismissed() {
        settings.welcomeShown = true
    }
}
