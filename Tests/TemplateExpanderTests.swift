import XCTest
@testable import ClipBarTests

final class TemplateExpanderTests: XCTestCase {
    let context = TemplateExpander.Context(
        now: Date(timeIntervalSince1970: 1_761_609_600), // 2025-10-28 00:00:00 UTC
        clipboard: "CLIP", userName: "artur", fullName: "Artur H", hostName: "mac", homePath: "/Users/artur",
        locale: Locale(identifier: "en_US_POSIX"), timeZone: TimeZone(identifier: "UTC")!)

    func testTokens() {
        let e = TemplateExpander()
        XCTAssertEqual(e.expand("{date:yyyy-MM-dd}", context: context), "2025-10-28")
        XCTAssertEqual(e.expand("{timestamp}", context: context), "1761609600")
        XCTAssertEqual(e.expand("{iso}", context: context), "2025-10-28T00:00:00Z")
        XCTAssertEqual(e.expand("Hi {fullname} ({user}@{hostname})", context: context), "Hi Artur H (artur@mac)")
        XCTAssertEqual(e.expand("[{clipboard}]", context: context), "[CLIP]")
        XCTAssertEqual(e.expand("{home}/x", context: context), "/Users/artur/x")
        XCTAssertEqual(e.expand("{year} {weekday}", context: context), "2025 Tuesday")
        XCTAssertEqual(e.expand("{uuid}", context: context).count, 36)
    }

    func testUnknownTokensAndBracesKept() {
        let e = TemplateExpander()
        XCTAssertEqual(e.expand("{nope} {} {Date}", context: context), "{nope} {} {Date}")
        XCTAssertEqual(e.expand("func() { return 1 }", context: context), "func() { return 1 }")
    }

    func testContainsTokens() {
        XCTAssertTrue(TemplateExpander.containsTokens("Today is {date}"))
        XCTAssertFalse(TemplateExpander.containsTokens("plain text"))
    }
}
