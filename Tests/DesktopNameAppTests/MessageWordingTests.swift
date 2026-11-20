import DesktopNameApp
import DesktopNameCore
import Testing

/// The app's wording for core sentences (spec 014 FR-009, FR-019a).
@Suite struct MessageWordingTests {
    @Test func unsupportedWallpapersGetOneSentenceNamingTheirKind() {
        #expect(MessageWording.sentence(for: DnmError.unsupportedWallpaper("it holds several images (a dynamic wallpaper)"))
            == "Dynamic wallpapers are not supported.")
        #expect(MessageWording.sentence(for: DnmError.unsupportedWallpaper("it carries dynamic wallpaper metadata"))
            == "Dynamic wallpapers are not supported.")
        #expect(MessageWording.sentence(for: DnmError.unsupportedWallpaper("it is a folder of pictures (a shuffling wallpaper)"))
            == "Shuffling wallpapers are not supported.")
        #expect(MessageWording.sentence(for: DnmError.unsupportedWallpaper("it is a video (an aerial wallpaper)"))
            == "Aerial wallpapers are not supported.")
        #expect(MessageWording.sentence(for: DnmError.unsupportedWallpaper("it is an Apple catalog wallpaper"))
            == "Apple catalog wallpapers are not supported.")
    }

    @Test func noSentencePromisesFutureSupport() {
        for reason in ["dynamic", "shuffling", "aerial", "catalog", "something new"] {
            #expect(!MessageWording.sentence(for: DnmError.unsupportedWallpaper(reason)).contains("yet"))
        }
    }

    @Test func noFileAndAnUnreadablePicture() {
        #expect(MessageWording.sentence(for: DnmError.noWallpaperFile) == "This Desktop has no wallpaper picture to label.")
        #expect(MessageWording.sentence(for: DnmError.unreadableWallpaper("Lake.heic")) == "Cannot read wallpaper \u{2018}Lake.heic\u{2019}.")
    }

    @Test func terminalWordingBecomesTheAppsWording() {
        let newer = MessageWording.sentence(for: DnmError.newerManifest(found: 4, supported: 3))
        #expect(newer == "The stored data is format 4, newer than this app understands (3). Update the app. Nothing was changed.")
        let other = MessageWording.appWording("The wallpaper Lake.heic was made by this tool but is not in this store (another build or a lost manifest). Choose a wallpaper in System Settings > Wallpaper, then run again. Nothing was changed.")
        #expect(other.contains("made by this app") && other.contains("then try again"))
        #expect(MessageWording.sentence(for: DnmError.storeNotWritable("disk full")).contains("the app's storage"))
        #expect(MessageWording.sentence(for: DnmError.invalidInput("An alias cannot be only digits, because --display does not accept numbers."))
            == "An alias cannot be only digits.")
    }

    @Test func aSentenceThatStillNamesTheToolIsReplaced() {
        #expect(MessageWording.appWording("The wallpaper of Studio Display kept changing while dnm read it.")
            == "This could not be done. Nothing was changed.")
        #expect(MessageWording.appWording("Nothing was scanned: add --yes to scan without asking.")
            == "This could not be done. Nothing was changed.")
        #expect(MessageWording.appWording("Refusing to write x: it is not a name this tool uses.")
            == "Refusing to write x: it is not a name this app uses.")
    }

    @Test func otherSentencesAreUnchanged() {
        let sentence = "A label can have at most 30 characters; this one has 36."
        #expect(MessageWording.sentence(for: DnmError.invalidInput(sentence)) == sentence)
    }

    /// No sentence the app shows names the command-line tool, a command or an option (FR-019a).
    @Test func noSentenceNamesTheTool() {
        let errors: [DnmError] = [
            .newerManifest(found: 4, supported: 3), .storeNotWritable("x"), .noWallpaperFile, .unreadableWallpaper("a.png"),
            .unsupportedWallpaper("it holds several images (a dynamic wallpaper)"), .originalMissing("a.png"),
            .accessDenied("x"), .cannotUndo("nothing to undo"),
            .invalidInput("An alias cannot be only digits, because --display does not accept numbers."),
        ]
        for error in errors {
            let sentence = MessageWording.sentence(for: error)
            #expect(!sentence.contains("dnm") && !sentence.contains("--") && !sentence.contains("tool") && !sentence.contains("Terminal"),
                    "\(sentence)")
        }
    }
}
