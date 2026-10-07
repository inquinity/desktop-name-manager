import Foundation
import Testing
@testable import DesktopNameCore

@Suite struct LabelValidationTests {
    @Test func acceptsOrdinaryText() throws {
        #expect(try LabelText("Email").value == "Email")
    }

    @Test func trimsSurroundingWhitespace() throws {
        #expect(try LabelText("  Email \n").value == "Email")
    }

    @Test(arguments: ["", "   ", "\n\t "])
    func rejectsEmptyOrWhitespaceOnly(_ text: String) {
        #expect(throws: DnmError.self) { try LabelText(text) }
    }

    @Test func acceptsExactlyThirtyCharacters() throws {
        let text = String(repeating: "a", count: 30)
        #expect(try LabelText(text).value == text)
    }

    @Test func rejectsThirtyOneCharacters() {
        #expect(throws: DnmError.self) { try LabelText(String(repeating: "a", count: 31)) }
    }

    @Test(arguments: ["Mail\nBox", "Mail\r\nBox", "Mail\u{2028}Box"])
    func rejectsLineBreaks(_ text: String) {
        #expect(throws: DnmError.self) { try LabelText(text) }
    }

    @Test(arguments: ["Mail\u{1B}]0;pwned\u{7}", "Tab\tbed", "A\u{1B}[31mred", "Del\u{7F}", "C1\u{9B}x",
                      "Mail\u{202E}xoB", "Iso\u{2066}late", "Mark\u{200F}"])
    func rejectsControlAndDirectionCharacters(_ text: String) {
        #expect(throws: DnmError.self) { try LabelText(text) }
    }

    @Test(arguments: ["👨‍👩‍👧", "❤️", "🏴󠁧󠁢󠁳󠁣󠁴󠁿", "Café", "عربي", "日本語"])
    func acceptsEmojiSequencesAndOtherScripts(_ text: String) throws {
        #expect(try LabelText(text).value == text)
    }

    @Test func displayNamesHaveControlCharactersReplaced() {
        #expect(TerminalText.sanitized("LG\u{1B}]0;x\u{7} HD\u{202E}") == "LG\u{FFFD}]0;x\u{FFFD} HD\u{FFFD}")
        #expect(TerminalText.sanitized("Built-in Retina Display") == "Built-in Retina Display")
    }

    @Test func countsEachEmojiAsOneCharacter() throws {
        let thirty = String(repeating: "✉️", count: 30)
        #expect(try LabelText(thirty).value == thirty)
        #expect(throws: DnmError.self) { try LabelText(String(repeating: "👨‍👩‍👧", count: 31)) }
    }

    @Test func invalidInputMapsToExitCodeTwo() {
        do { _ = try LabelText("") } catch let error as DnmError { #expect(error.exitCode == 2) } catch { Issue.record("wrong error") }
    }

    @Test func roundTripsThroughJSON() throws {
        let original = try LabelText("Email")
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(LabelText.self, from: data) == original)
        #expect(throws: DnmError.self) { try JSONDecoder().decode(LabelText.self, from: Data("\"\"".utf8)) }
    }
}
