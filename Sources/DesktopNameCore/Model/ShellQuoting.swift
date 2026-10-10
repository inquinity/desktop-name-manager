import Foundation

/// Quotes a word the way a POSIX shell needs it, for the commands that messages suggest (spec 008 research R4b).
public enum ShellQuoting {
    private static let bare = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-./:=@%+,")

    /// A word of only safe characters stays bare; anything else (spaces, `$`, quotes, an empty word, non-ASCII) goes in
    /// single quotes, with an embedded single quote written `'\''`.
    public static func quote(_ word: String) -> String {
        if !word.isEmpty, word.allSatisfy({ bare.contains($0) }) { return word }
        return "'" + word.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
