import XCTest
@testable import ClipBarTests

final class SearchMatcherTests: XCTestCase {
    func testRanking() {
        let exact = SearchMatcher.score("mail", in: "mail")!
        let prefix = SearchMatcher.score("mail", in: "mailbox settings")!
        let word = SearchMatcher.score("mail", in: "my mail box")!
        let inner = SearchMatcher.score("mail", in: "gmail.com")!
        let fuzzy = SearchMatcher.score("gml", in: "gmail")!
        XCTAssertGreaterThan(exact, prefix)
        XCTAssertGreaterThan(prefix, word)
        XCTAssertGreaterThan(word, inner)
        XCTAssertGreaterThan(inner, fuzzy)
    }

    func testCaseAndDiacritics() {
        XCTAssertNotNil(SearchMatcher.score("cafe", in: "Café Noir"))
        XCTAssertNotNil(SearchMatcher.score("ПРИВІТ", in: "привіт світ"))
    }

    func testMultiWord() {
        XCTAssertNotNil(SearchMatcher.score("xcode license", in: "sudo xcodebuild -license accept"))
    }

    func testNoMatch() {
        XCTAssertNil(SearchMatcher.score("zzz", in: "hello"))
        XCTAssertNil(SearchMatcher.score("ab", in: String(repeating: "a", count: 10) + String(repeating: "x", count: 80) + "b"))
    }

    func testFuzzyIsNotTooLoose() {
        XCTAssertNil(SearchMatcher.score("mail", in: "I'm away until 28.10 and will reply when I'm back."))
        XCTAssertNotNil(SearchMatcher.score("xcb", in: "xcodebuild"))
    }

    func testFields() {
        XCTAssertNotNil(SearchMatcher.score("safari", fields: [nil, "text", "Safari"]))
    }
}
