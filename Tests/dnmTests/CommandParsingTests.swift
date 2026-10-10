import Testing
@testable import dnm

/// Parses commands in-process, without running them (spec 008). The positional-syntax cases join this suite.
@Suite struct CommandParsingTests {
    @Test func aCommandParsesWithoutRunning() throws {
        let set = try SetCommand.parse(["Mail", "--style", "halo", "--desktop", "2"])
        #expect(set.label == "Mail" && set.style == "halo" && set.place.desktop == 2)
        let alias = try AliasCommand.parse(["--remove", "desk"])
        #expect(alias.remove && alias.name == "desk")
    }
}
