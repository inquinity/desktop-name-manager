import DesktopNameCore
import Foundation

/// The real wallpaper system and store, wired together for one command run.
struct Context {
    let system: WallpaperSystem
    let labeler: DesktopLabeler

    init() {
        let system = SystemWallpaperSystem()
        self.system = system
        self.labeler = DesktopLabeler(system: system, store: Store(directory: Store.defaultDirectory()))
    }

    /// The display the command acts on, resolved from `--display` (or the main display).
    func resolveDisplay(_ option: DisplayOption) throws -> Display {
        try DisplayResolver.resolve(option.display, in: try system.displays())
    }

    /// Runs `body` on the Desktop chosen with `--desktop`, switching there and back, or on the current Desktop.
    /// The CLI runs synchronously on the main thread, so `body` never leaves it.
    func onDesktop<T: Sendable>(_ option: DesktopOption, of display: Display, _ body: () throws -> T) throws -> T {
        guard let target = option.desktop else { return try body() }
        nonisolated(unsafe) let body = body
        return try MainActor.assumeIsolated {
            let switcher = SystemDesktopSwitcher()
            defer { switcher.stop() }
            return try DesktopNavigator(switcher: switcher).visit(desktop: target, on: display, body)
        }
    }
}
