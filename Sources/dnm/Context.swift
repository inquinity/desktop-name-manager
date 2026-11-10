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

    /// The display `show` acts on, from the display word or `--display` (or the main display).
    /// An alias of the same name that the display overrode is reported on standard error.
    func target(command: String, words: ShowWords, option: DisplayOption) throws -> Display {
        let target = try DisplayArguments.target(command: command, words: words.words, displayFlags: option.display,
                                                 in: try system.displays(), aliases: try labeler.aliases())
        warn(target.notice)
        return target.display
    }

    /// The displays `remove` and `undo` act on, in order, from the display words and `--display` (spec 010).
    func targets(words: DisplayWords, option: DisplayOption) throws -> DisplayArguments.Targets {
        let targets = try DisplayArguments.targets(words: words.words, displayFlags: option.display,
                                                   in: try system.displays(), aliases: try labeler.aliases())
        warn(targets.notice)
        return targets
    }

    /// What `set` was asked: the displays and the label, from the words and the flags.
    func setRequest(words: [String], option: DisplayOption, labelFlags: [String]) throws -> DisplayArguments.SetRequest {
        try DisplayArguments.setRequest(words: words, displayFlags: option.display, labelFlags: labelFlags,
                                        in: try system.displays(), aliases: try labeler.aliases())
    }

    /// An alias of the same name that the display overrode is reported on standard error, once, before the first
    /// change. `set` calls it after it has validated the label and options, so a warning never comes before an input
    /// error. Held back in quiet mode (spec 011).
    func warn(_ notice: String?) {
        if let notice { Output.warning(notice) }
    }

    /// The options a suggested `dnm undo` needs to reach the same Desktop.
    func undoArguments(_ option: DesktopOption) -> [String] {
        option.desktop.map { ["--desktop", String($0)] } ?? []
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
