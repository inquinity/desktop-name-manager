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

    /// The display `remove`, `undo` and `show` act on, from the display word or `--display` (or the main display).
    /// An alias of the same name that the display overrode is reported on standard error.
    func target(command: String, words: DisplayWords, option: DisplayOption) throws -> Display {
        let target = try DisplayArguments.target(command: command, words: words.words, displayFlags: option.display,
                                                 in: try system.displays(), aliases: try labeler.aliases())
        warn(target)
        return target.display
    }

    /// What `set` was asked: the display and the label, from the words and the flags.
    func setRequest(words: [String], option: DisplayOption, labelFlags: [String]) throws -> DisplayArguments.SetRequest {
        let request = try DisplayArguments.setRequest(words: words, displayFlags: option.display, labelFlags: labelFlags,
                                                      in: try system.displays(), aliases: try labeler.aliases())
        warn(request.target)
        return request
    }

    private func warn(_ target: DisplayArguments.Target) {
        if let notice = target.notice { Output.err("dnm: warning: \(notice)") }
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
