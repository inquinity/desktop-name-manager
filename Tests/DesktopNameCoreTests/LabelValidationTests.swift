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
