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
}
