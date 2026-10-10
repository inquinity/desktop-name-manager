import Testing
@testable import DesktopNameCore

@Suite struct ShellQuotingTests {
    @Test(arguments: [("DP1", "DP1"), ("a/b-c.d_e", "a/b-c.d_e"), ("LG Ultra", "'LG Ultra'"), ("$HOME", "'$HOME'"),
                      ("it's", "'it'\\''s'"), ("a\"b", "'a\"b'"), ("", "''"), ("naïve", "'naïve'"), ("a;b", "'a;b'"), ("-x", "-x"), ("=cmd", "'=cmd'"), ("~/x", "'~/x'"), ("a=b", "a=b")])
    func quotesAsAPOSIXShellWould(_ word: String, _ expected: String) {
        #expect(ShellQuoting.quote(word) == expected)
    }
}
