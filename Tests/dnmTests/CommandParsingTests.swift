import Testing
@testable import dnm

/// Parses commands in-process, without running them (spec 008): which word lands where, with options anywhere.
@Suite struct CommandParsingTests {
    struct Shape: Equatable {
        var first: String?
        var second: String?
        var extra: [String]
        var display: [String]
        var label: [String]
    }

    func set(_ arguments: String...) throws -> (shape: Shape, command: SetCommand) {
        let command = try SetCommand.parse(arguments)
        return (Shape(first: command.first, second: command.second, extra: command.extra, display: command.target.display, label: command.labelFlag), command)
    }

    @Test func twoWordsAreADisplayAndALabel() throws {
        #expect(try set("DP1", "labelX").shape == Shape(first: "DP1", second: "labelX", extra: [], display: [], label: []))
        #expect(try set("LG Ultra", "Label X").shape == Shape(first: "LG Ultra", second: "Label X", extra: [], display: [], label: []))
    }

    @Test func aLoneWordKeepsTheFlagsApart() throws {
        #expect(try set("Label X", "--display", "LG Ultra").shape == Shape(first: "Label X", second: nil, extra: [], display: ["LG Ultra"], label: []))
        #expect(try set("LG Ultra", "--label", "Label X").shape == Shape(first: "LG Ultra", second: nil, extra: [], display: [], label: ["Label X"]))
        #expect(try set("--label", "Label X", "--display", "LG Ultra").shape == Shape(first: nil, second: nil, extra: [], display: ["LG Ultra"], label: ["Label X"]))
    }

    @Test func optionsMayComeBeforeBetweenOrAfterTheWords() throws {
        for arguments in [["--style", "halo", "DP1", "--desktop", "2", "x"], ["DP1", "--style", "halo", "x", "--desktop", "2"], ["DP1", "x", "--desktop", "2", "--style", "halo"]] {
            let command = try SetCommand.parse(arguments)
            #expect(command.first == "DP1" && command.second == "x" && command.style == "halo" && command.place.desktop == 2, "\(arguments)")
        }
    }

    @Test func repeatsAreSeenNotSwallowed() throws {
        #expect(try set("x", "--display", "DP1", "--display", "main").shape.display == ["DP1", "main"])
        #expect(try set("--label", "a", "--label", "b").shape.label == ["a", "b"])
    }

    @Test func extraWordsAreKeptForOurOwnMessage() throws {
        #expect(try set("a", "b", "c", "d").shape == Shape(first: "a", second: "b", extra: ["c", "d"], display: [], label: []))
    }

    @Test func aDashLabelNeedsTheTerminatorOrAnEquals() throws {
        #expect(try set("DP1", "--", "-x").shape == Shape(first: "DP1", second: "-x", extra: [], display: [], label: []))
        #expect(try set("--label=-x", "DP1").shape.label == ["-x"])
        #expect(throws: (any Error).self) { try SetCommand.parse(["--label", "-x", "DP1"]) }
    }

    @Test func theOtherCommandsTakeOneOptionalDisplayWord() throws {
        #expect(try ShowCommand.parse([]).words.words == [])
        #expect(try ShowCommand.parse(["DP1", "--json"]).words.words == ["DP1"])
        #expect(try RemoveCommand.parse(["--desktop", "2", "DP1"]).words.words == ["DP1"])
        #expect(try UndoCommand.parse(["DP1", "DP2"]).words.words == ["DP1", "DP2"])
        #expect(try ShowCommand.parse(["--display", "A", "--display", "B"]).target.display == ["A", "B"])
    }

    @Test func aliasRemovalStillParses() throws {
        let alias = try AliasCommand.parse(["--remove", "desk"])
        #expect(alias.remove && alias.name == "desk")
        #expect(throws: (any Error).self) { try AliasCommand.parse(["-d", "desk"]) }
    }
}
