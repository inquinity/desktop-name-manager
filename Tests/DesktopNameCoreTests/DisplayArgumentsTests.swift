import Testing
@testable import DesktopNameCore

/// Every invocation in specs 008 and 010, against the one function that reads a command line (spec 008 SC-001, spec 010
/// SC-001). A result names the displays in order, joined with ", ".
@Suite struct DisplayArgumentsTests {
    let builtIn = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "A", isMain: true)
    let lg = FakeWallpaperSystem.makeDisplay(name: "LG Ultra HD", uuid: "B", isMain: false)
    let dp = FakeWallpaperSystem.makeDisplay(name: "DP", uuid: "C", isMain: false)
    var displays: [Display] { [builtIn, lg, dp] }
    var aliases: [DisplayAlias] {
        [DisplayAlias(name: "lg", displayUUID: "B", displayName: "LG Ultra HD"), DisplayAlias(name: "old", displayUUID: "GONE", displayName: "Studio")]
    }

    enum Outcome: Equatable { case ok(display: String, label: String), error(contains: [String]) }

    func read(_ words: [String], display: [String] = [], label: [String] = [], using displays: [Display]? = nil) -> Outcome {
        do {
            let request = try DisplayArguments.setRequest(words: words, displayFlags: display, labelFlags: label, in: displays ?? self.displays, aliases: aliases)
            return .ok(display: request.targets.displays.map(\.name).joined(separator: ", "), label: request.label)
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            return .error(contains: [error.errorDescription ?? ""])
        } catch { return .error(contains: ["wrong error type"]) }
    }

    func expect(_ outcome: Outcome, _ expected: Outcome, _ comment: String = "", sourceLocation: SourceLocation = #_sourceLocation) {
        switch (outcome, expected) {
        case (.ok, .ok): #expect(outcome == expected, Comment(rawValue: comment), sourceLocation: sourceLocation)
        case (.error(let actual), .error(let needles)):
            for needle in needles { #expect(actual.joined().contains(needle), Comment(rawValue: "\(comment): \(actual) lacks \(needle)"), sourceLocation: sourceLocation) }
        default: Issue.record("\(comment): got \(outcome), expected \(expected)", sourceLocation: sourceLocation)
        }
    }

    // MARK: set, the legitimate forms

    @Test func twoWordsAreADisplayAndALabel() {
        expect(read(["DP", "labelX"]), .ok(display: "DP", label: "labelX"))
        expect(read(["LG Ultra", "labelX"]), .ok(display: "LG Ultra HD", label: "labelX"), "a unique part of the name")
        expect(read(["LG Ultra", "Label X"]), .ok(display: "LG Ultra HD", label: "Label X"))
        expect(read(["lg", "Label X"]), .ok(display: "LG Ultra HD", label: "Label X"), "an alias")
        expect(read(["main", "x"]), .ok(display: "Built-in Display", label: "x"))
    }

    @Test func oneWordIsTheLabelForTheMainDisplayOrForTheFlagsDisplay() {
        expect(read(["Mail"]), .ok(display: "Built-in Display", label: "Mail"))
        expect(read(["Label X"], display: ["LG Ultra HD"]), .ok(display: "LG Ultra HD", label: "Label X"))
        expect(read(["2"]), .ok(display: "Built-in Display", label: "2"), "a number is a label, not a display")
        expect(read(["LG Ultra"]), .ok(display: "Built-in Display", label: "LG Ultra"), "a partial name is not a display reference")
    }

    @Test func aNamedLabelTakesAnOptionalDisplay() {
        expect(read(["LG Ultra"], label: ["Label X"]), .ok(display: "LG Ultra HD", label: "Label X"))
        expect(read([], display: ["DP"], label: ["Label X"]), .ok(display: "DP", label: "Label X"))
        expect(read([], label: ["Label X"]), .ok(display: "Built-in Display", label: "Label X"))
        expect(read([], label: ["DP"]), .ok(display: "Built-in Display", label: "DP"), "--label names a label that equals a display")
    }

    @Test func theFlagFormAndTheWordFormAreEquivalent() {
        for (display, label) in [("DP", "x"), ("LG Ultra", "Label X"), ("lg", "y"), ("main", "z")] {
            expect(read([display, label]), read([label], display: [display]), "\(display)")
            expect(read([display, label]), read([], display: [display], label: [label]), "\(display)")
        }
    }

    @Test func aLoneWordWithAFlagIsALabelEvenIfItNamesADisplay() {
        expect(read(["DP"], display: ["main"]), .ok(display: "Built-in Display", label: "DP"))
    }

    // MARK: set, the refusals

    @Test func aLoneWordThatIsADisplayReferenceIsRefusedWithBothForms() {
        for word in ["main", "MAIN", "DP", "dp", "LG Ultra HD", "lg", "old"] {
            expect(read([word]), .error(contains: ["\"\(word)\" is a display", "To label it: dnm set", "dnm set --label"]), word)
        }
        expect(read(["LG Ultra HD"]), .error(contains: ["dnm set 'LG Ultra HD' \"<label>\"", "dnm set --label 'LG Ultra HD'"]), "quoted for the shell")
    }

    @Test func tooManyWords() {
        expect(read(["a", "b", "c"]), .error(contains: ["set takes a label, or a display and a label (got 3 words)", "Quote anything with spaces", "dnm alias lg \"LG Ultra\""]))
        expect(read(["a", "b", "c", "d"]), .error(contains: ["got 4 words"]))
        expect(read(["a", "b"], label: ["y"]), .error(contains: ["with --label, set takes at most one display (got 2 words)"]))
    }

    @Test func aFirstWordThatIsNoDisplayGetsTheQuotingHint() {
        expect(read(["Mail", "Inbox"]), .error(contains: ["No display matches \"Mail\"", "quote the whole label: dnm set 'Mail Inbox'"]))
        expect(read(["x"], label: ["y"]), .error(contains: ["No display matches \"x\"", "With --label, a plain word is read as the display"]))
        expect(read(["2", "x"]), .error(contains: ["Numbered displays are not supported"]))
    }

    @Test func severalDisplaysAreTheWordThenEachFlagInOrder() {
        expect(read(["main", "Mail"], display: ["DP"]), .ok(display: "Built-in Display, DP", label: "Mail"))
        expect(read(["Mail"], display: ["DP", "main"]), .ok(display: "DP, Built-in Display", label: "Mail"))
        expect(read(["DP", "x"], display: ["main"]), .ok(display: "DP, Built-in Display", label: "x"), "a command typed and then added to")
        expect(read(["DP"], display: ["main"], label: ["x"]), .ok(display: "DP, Built-in Display", label: "x"))
        expect(read([], display: ["main", "DP", "lg"], label: ["x"]), .ok(display: "Built-in Display, DP, LG Ultra HD", label: "x"))
    }

    @Test func aDisplayNamedAgainByAnotherNameKeepsItsFirstPlace() {
        expect(read(["DP", "Mail"], display: ["DP"]), .ok(display: "DP", label: "Mail"))
        expect(read(["main", "x"], display: ["DP", "Built-in Display"]), .ok(display: "Built-in Display, DP", label: "x"), "main and its name")
        expect(read(["x"], display: ["lg", "DP", "LG Ultra HD"]), .ok(display: "LG Ultra HD, DP", label: "x"), "an alias and its display")
        expect(read(["x"], display: ["DP", "lg", "dp"]), .ok(display: "DP, LG Ultra HD", label: "x"), "ignoring case")
    }

    @Test func everyDisplayIsResolvedBeforeAnythingIsReturned() {
        expect(read(["main", "x"], display: ["DP", "NoSuchDisplay"]), .error(contains: ["No display matches \"NoSuchDisplay\""]))
        expect(read(["main", "x"], display: ["DP", ""]), .error(contains: ["The display is empty"]))
        expect(read(["main", "x"], display: ["old"]), .error(contains: ["The display aliased as old is not connected"]))
        expect(read(["main", "DP", "Mail"]), .error(contains: ["got 3 words"]), "set still takes one display word")
    }

    @Test func theSameDisplayNamedMoreThanOnceIsOneDisplay() {
        expect(read(["DP", "x"], display: ["DP"]), .ok(display: "DP", label: "x"))
        expect(read(["DP", "x"], display: ["dp"]), .ok(display: "DP", label: "x"), "ignoring case")
        expect(read(["x"], display: ["main", "Built-in Display"]), .ok(display: "Built-in Display", label: "x"), "main is the built-in display")
        expect(read([], display: ["DP", "DP"], label: ["x"]), .ok(display: "DP", label: "x"))
        expect(read(["DP"], display: ["DP"], label: ["x"]), .ok(display: "DP", label: "x"))
        expect(read(["LG Ultra", "x"], display: ["lg"]), .ok(display: "LG Ultra HD", label: "x"), "a part of the name and an alias")
    }

    @Test func aLabelGivenTwiceIsAnError() {
        expect(read([], label: ["a", "b"]), .error(contains: ["Give the label once"]))
    }

    @Test func theQuotingHintIsOnlyForAFirstWordThatIsNoDisplay() {
        // "old" is an alias of a display that is away: it is a display, so the hint (which would suggest labeling the
        // main display "old x") must not be added.
        let missing = read(["old", "x"])
        expect(missing, .error(contains: ["The display aliased as old is not connected"]))
        if case .error(let text) = missing { #expect(!text.joined().contains("quote the whole label")) }
        let withLabel = read(["old"], label: ["x"])
        if case .error(let text) = withLabel { #expect(!text.joined().contains("read as the display")) }
    }

    @Test func anEmptyDisplayIsAnErrorNotTheMainDisplay() {
        expect(read(["", "x"]), .error(contains: ["The display is empty"]))
        expect(read(["x"], display: [""]), .error(contains: ["The display is empty"]))
        expect(read(["  ", "x"]), .error(contains: ["The display is empty"]))
        expect(target([""]), .error(contains: ["The display is empty"]))
        expect(target([], display: [" "]), .error(contains: ["The display is empty"]))
    }

    @Test func aDisplayNamedWithALeadingDashIsSuggestedInAFormTheParserReads() {
        let odd = FakeWallpaperSystem.makeDisplay(name: "-odd", uuid: "Z", isMain: false)
        expect(read(["-odd"], using: displays + [odd]),
               .error(contains: ["dnm set --display=-odd \"<label>\"", "dnm set --label=-odd"]))
    }

    @Test func noLabelIsAnError() {
        expect(read([]), .error(contains: ["set needs a label"]))
        expect(read([], display: ["DP"]), .error(contains: ["set needs a label"]))
    }

    @Test func anOverriddenAliasKeepsItsWarning() throws {
        let rival = FakeWallpaperSystem.makeDisplay(name: "lg", uuid: "D", isMain: false)
        let request = try DisplayArguments.setRequest(words: ["lg", "x"], displayFlags: [], labelFlags: [], in: displays + [rival], aliases: aliases)
        #expect(request.targets.displays.map(\.name) == ["lg"])
        #expect(request.targets.notice == "lg is a connected display, which overrides alias lg (LG Ultra HD).")
    }

    // MARK: remove, undo, show

    func target(_ words: [String], display: [String] = []) -> Outcome {
        do {
            let target = try DisplayArguments.target(command: "show", words: words, displayFlags: display, in: displays, aliases: aliases)
            return .ok(display: target.display.name, label: "")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            return .error(contains: [error.errorDescription ?? ""])
        } catch { return .error(contains: ["wrong error type"]) }
    }

    @Test func theOtherCommandsTakeAtMostOneDisplay() {
        expect(target([]), .ok(display: "Built-in Display", label: ""))
        expect(target(["DP"]), .ok(display: "DP", label: ""))
        expect(target(["LG Ultra"]), .ok(display: "LG Ultra HD", label: ""))
        expect(target(["lg"]), .ok(display: "LG Ultra HD", label: ""))
        expect(target([], display: ["DP"]), .ok(display: "DP", label: ""))
        expect(target(["DP"], display: ["main"]), .error(contains: ["Multiple displays for a single command are not currently supported."]))
        expect(target([], display: ["main", "DP"]), .error(contains: ["Multiple displays for a single command are not currently supported."]))
        expect(target(["main"], display: ["NoSuch", "DP"]), .error(contains: ["No display matches \"NoSuch\""]), "a typo is reported, not the count")
        expect(target(["DP"], display: ["DP"]), .ok(display: "DP", label: ""), "the same display twice is one display")
        expect(target([], display: ["DP", "dp"]), .ok(display: "DP", label: ""))
        expect(target(["DP", "lg"]), .error(contains: ["show takes at most one display (got 2 words)", "use an alias"]))
        expect(target(["nope"]), .error(contains: ["No display matches \"nope\""]))
    }

    func targets(_ words: [String], display: [String] = []) -> Outcome {
        do {
            let targets = try DisplayArguments.targets(words: words, displayFlags: display, in: displays, aliases: aliases)
            return .ok(display: targets.displays.map(\.name).joined(separator: ", "), label: targets.references.joined(separator: "|"))
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            return .error(contains: [error.errorDescription ?? ""])
        } catch { return .error(contains: ["wrong error type"]) }
    }

    @Test func removeAndUndoTakeAnyNumberOfDisplaysInOrder() {
        expect(targets([]), .ok(display: "Built-in Display", label: "main"))
        expect(targets(["main", "DP"]), .ok(display: "Built-in Display, DP", label: "main|DP"))
        expect(targets(["DP"], display: ["main", "DP"]), .ok(display: "DP, Built-in Display", label: "DP|main"))
        expect(targets(["lg", "LG Ultra", "dp"]), .ok(display: "LG Ultra HD, DP", label: "lg|dp"), "the word that named it first")
        expect(targets(["main", "NoSuch"]), .error(contains: ["No display matches \"NoSuch\""]))
        expect(targets(["main", " "]), .error(contains: ["The display is empty"]))
    }

    @Test func anOverrideNoticeIsGivenOnceForSeveralDisplays() throws {
        let rival = FakeWallpaperSystem.makeDisplay(name: "lg", uuid: "D", isMain: false)
        let targets = try DisplayArguments.targets(words: ["lg", "DP"], displayFlags: ["lg"], in: displays + [rival], aliases: aliases)
        #expect(targets.displays.map(\.name) == ["lg", "DP"])
        #expect(targets.notice == "lg is a connected display, which overrides alias lg (LG Ultra HD).")
    }
}
