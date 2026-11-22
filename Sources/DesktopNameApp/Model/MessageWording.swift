import DesktopNameCore
import Foundation

/// The app's wording for the core's sentences (spec 014 FR-009, FR-019a, contracts/app-ui.md §Editor messages).
///
/// The app shows the core's own sentences, so it and `dnm` say the same thing, except that no window may name the
/// command-line tool, its commands or its options, and a wallpaper the app will not label gets one short sentence
/// naming its kind.
public enum MessageWording {
    /// Replacements for wording that only makes sense in a terminal. Applied in order.
    static let substitutions: [(String, String)] = [
        ("Update the tool.", "Update the app."),
        ("newer than this tool understands", "newer than this app understands"),
        ("was made by this tool", "was made by this app"),
        ("the tool's storage", "the app's storage"),
        ("this tool", "this app"),
        ("then run again", "then try again"),
        (", because --display does not accept numbers", ""),
    ]

    /// Said instead of any sentence that would still name the command-line tool, a command, an option or Terminal
    /// after the substitutions (FR-019a): such sentences come from paths only `dnm` uses, so this is a safety net.
    static let plainFailure = "This could not be done. Nothing was changed."

    /// The sentence the app shows for an error from the core.
    public static func sentence(for error: Error) -> String {
        if let error = error as? DnmError {
            switch error {
            case .unsupportedWallpaper(let reason): return unsupportedSentence(reason: reason)
            case .noWallpaperFile: return "This Desktop has no wallpaper picture to label."
            case .unreadableWallpaper(let name): return "Cannot read wallpaper \u{2018}\(name)\u{2019}."
            default: return appWording(error.errorDescription ?? String(describing: error))
            }
        }
        return appWording((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
    }

    /// The core's sentence with the app's wording.
    public static func appWording(_ sentence: String) -> String {
        let worded = substitutions.reduce(sentence) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
        return namesTheTool(worded) ? plainFailure : worded
    }

    static func namesTheTool(_ sentence: String) -> Bool {
        sentence.range(of: #"\bdnm\b|--[a-z]|\bTerminal\b|\bterminal\b"#, options: .regularExpression) != nil
    }

    /// One sentence naming the kind of wallpaper, with no "yet" and no reason clause (prototype review round 4).
    static func unsupportedSentence(reason: String) -> String {
        let kinds: [(String, String)] = [
            ("dynamic", "Dynamic wallpapers are not supported."),
            ("shuffling", "Shuffling wallpapers are not supported."),
            ("aerial", "Aerial wallpapers are not supported."),
            ("catalog", "Apple catalog wallpapers are not supported."),
        ]
        return kinds.first { reason.contains($0.0) }?.1 ?? "This wallpaper is not supported."
    }
}
