import Foundation

/// Results go to standard output; messages, warnings and errors go to standard error (contracts/cli.md).
enum Output {
    static func out(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    static func err(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}
