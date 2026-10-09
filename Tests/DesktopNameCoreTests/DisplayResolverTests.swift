import Testing
@testable import DesktopNameCore

@Suite struct DisplayResolverTests {
    let builtIn = FakeWallpaperSystem.makeDisplay(name: "Built-in Display", uuid: "A", isMain: true)
    let lg = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "B", isMain: false)
    let dell = FakeWallpaperSystem.makeDisplay(name: "Dell U2723QE", uuid: "C", isMain: false)
    var displays: [Display] { [lg, builtIn, dell] }

    @Test func omittedValueIsTheMainDisplay() throws {
        #expect(try DisplayResolver.resolve(nil, in: displays) == builtIn)
        #expect(try DisplayResolver.resolve("  ", in: displays) == builtIn)
    }

    @Test func mainAlwaysWorks() throws {
        #expect(try DisplayResolver.resolve("main", in: displays) == builtIn)
        #expect(try DisplayResolver.resolve("MAIN", in: displays) == builtIn)
    }

    @Test func exactNameIsCaseInsensitive() throws {
        #expect(try DisplayResolver.resolve("Built-in Display", in: displays) == builtIn)
        #expect(try DisplayResolver.resolve("lg hdr 4k", in: displays) == lg)
    }

    @Test func uniquePartialNameMatches() throws {
        #expect(try DisplayResolver.resolve("Built", in: displays) == builtIn)
        #expect(try DisplayResolver.resolve("lg", in: displays) == lg)
        #expect(try DisplayResolver.resolve("u27", in: displays) == dell)
    }

    @Test func ambiguousPartialNameListsCandidates() {
        let second = FakeWallpaperSystem.makeDisplay(name: "LG UltraFine", uuid: "D", isMain: false)
        do {
            _ = try DisplayResolver.resolve("lg", in: displays + [second])
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            let text = error.errorDescription ?? ""
            #expect(text.contains("LG HDR 4K") && text.contains("LG UltraFine"))
        } catch { Issue.record("wrong error") }
    }

    @Test func identicalNamesAreAmbiguousEvenWhenExact() {
        let twin = FakeWallpaperSystem.makeDisplay(name: "LG HDR 4K", uuid: "E", isMain: false)
        #expect(throws: DnmError.self) { try DisplayResolver.resolve("LG HDR 4K", in: displays + [twin]) }
    }

    @Test func unknownNameListsTheDisplays() {
        do {
            _ = try DisplayResolver.resolve("zzz", in: displays)
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect((error.errorDescription ?? "").contains("Built-in Display"))
        } catch { Issue.record("wrong error") }
    }

    @Test(arguments: ["1", "2", "03"])
    func numbersAreRejected(_ value: String) {
        #expect(throws: DnmError.self) { try DisplayResolver.resolve(value, in: displays) }
    }

    @Test(arguments: ["here", "left", "right"])
    func positionKeywordsAreNotInterpreted(_ value: String) {
        #expect(throws: DnmError.self) { try DisplayResolver.resolve(value, in: displays) }
    }

    @Test func noDisplaysIsAFailure() {
        do { _ = try DisplayResolver.resolve(nil, in: []) } catch let error as DnmError { #expect(error.exitCode == 1) } catch { Issue.record("wrong error") }
    }

    // MARK: Aliases (spec 006)

    var dp1Alias: DisplayAlias { DisplayAlias(name: "dp1", displayUUID: "B", displayName: "LG HDR 4K") }

    @Test func anExactAliasChoosesItsDisplayIgnoringCase() throws {
        #expect(try DisplayResolver.resolve("DP1", in: displays, aliases: [dp1Alias]) == lg)
    }

    @Test func displayOnlyModeIgnoresAliases() {
        #expect(throws: DnmError.self) { try DisplayResolver.resolve("dp1", in: displays) }
        #expect(throws: DnmError.self) { try DisplayResolver.resolve("dp1", in: displays, aliases: nil) }
    }

    @Test func aliasesAreNeverMatchedPartially() {
        #expect(throws: DnmError.self) { try DisplayResolver.resolve("dp", in: displays, aliases: [dp1Alias]) }
    }

    @Test func anAliasWithoutItsDisplayConnectedIsInvalidInput() {
        let away = DisplayAlias(name: "old", displayUUID: "GONE", displayName: "Studio Display")
        do {
            _ = try DisplayResolver.resolve("old", in: displays, aliases: [away])
            Issue.record("expected an error")
        } catch let error as DnmError {
            #expect(error.exitCode == 2)
            #expect(error.errorDescription == "The display aliased as old is not connected.")
        } catch { Issue.record("wrong error") }
    }

    @Test func anExactAliasBeatsAPartialDisplayName() throws {
        // "lg" is part of LG HDR 4K and LG UltraFine, yet the alias wins without an ambiguity error.
        let second = FakeWallpaperSystem.makeDisplay(name: "LG UltraFine", uuid: "D", isMain: false)
        let alias = DisplayAlias(name: "LG", displayUUID: "D", displayName: "LG UltraFine")
        #expect(try DisplayResolver.resolve("LG", in: displays + [second], aliases: [alias]) == second)
        #expect(throws: DnmError.self) { try DisplayResolver.resolve("LG", in: displays + [second]) }
    }

    @Test func aConnectedDisplaysNameOverridesAnAliasOfTheSameName() throws {
        // Alias DP1 points at the LG; then a monitor named DP1 is connected. Both stay reachable.
        let dp1 = FakeWallpaperSystem.makeDisplay(name: "DP1", uuid: "E", isMain: false)
        let all = displays + [dp1]
        let resolution = try DisplayResolver.resolution("dp1", in: all, aliases: [dp1Alias])
        #expect(resolution.display == dp1)
        #expect(resolution.notice == "DP1 is a connected display, which overrides alias dp1 (LG HDR 4K).")
        #expect(try DisplayResolver.resolve("LG HDR", in: all, aliases: [dp1Alias]) == lg)
        #expect(DisplayResolver.activeAliases(of: lg, in: [dp1Alias], displays: all).isEmpty)
        #expect(DisplayResolver.activeAliases(of: lg, in: [dp1Alias], displays: displays) == ["dp1"])
    }

    @Test func noNoticeWhenTheAliasPointsAtTheSameDisplay() throws {
        let same = DisplayAlias(name: "lg hdr 4k", displayUUID: "B", displayName: "LG HDR 4K")
        let resolution = try DisplayResolver.resolution("LG HDR 4K", in: displays, aliases: [same])
        #expect(resolution.display == lg && resolution.notice == nil)
        #expect(DisplayResolver.overrider(of: same, in: displays) == nil)
    }

    @Test func numbersAndMainStillComeFirst() throws {
        let tricky = DisplayAlias(name: "Main2", displayUUID: "B", displayName: nil)
        #expect(try DisplayResolver.resolve("main", in: displays, aliases: [tricky]) == builtIn)
        #expect(throws: DnmError.self) { try DisplayResolver.resolve("2", in: displays, aliases: [tricky]) }
    }
}
