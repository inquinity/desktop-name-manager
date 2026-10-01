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
}
