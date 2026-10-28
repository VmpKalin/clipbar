import XCTest
@testable import ClipBarTests

final class TextTransformTests: XCTestCase {
    func testCase() {
        XCTAssertEqual(TextTransform.uppercase.apply("abc"), "ABC")
        XCTAssertEqual(TextTransform.lowercase.apply("AbC"), "abc")
        XCTAssertEqual(TextTransform.titleCase.apply("hello world"), "Hello World")
        XCTAssertNil(TextTransform.uppercase.apply("ABC"), "no-op returns nil")
    }

    func testWhitespace() {
        XCTAssertEqual(TextTransform.trimWhitespace.apply("  a  \n  b \n"), "a\nb")
        XCTAssertEqual(TextTransform.singleLine.apply("a\n\n  b\nc"), "a b c")
        XCTAssertEqual(TextTransform.removeEmptyLines.apply("a\n\n \nb"), "a\nb")
    }

    func testJSON() {
        let minified = TextTransform.jsonMinify.apply("{ \"b\": 1,\n \"a\": [1, 2] }")
        XCTAssertNotNil(minified)
        XCTAssertFalse(minified!.contains(" ") || minified!.contains("\n"))
        XCTAssertTrue(minified!.contains(#""a":[1,2]"#))
        let pretty = TextTransform.jsonPretty.apply(#"{"b":1,"a":2}"#)
        XCTAssertNotNil(pretty)
        XCTAssertTrue(pretty!.contains("\n"))
        XCTAssertTrue(pretty!.range(of: "\"a\"")!.lowerBound < pretty!.range(of: "\"b\"")!.lowerBound, "sorted keys")
        XCTAssertNil(TextTransform.jsonPretty.apply("not json"))
    }

    func testURLAndBase64() {
        XCTAssertEqual(TextTransform.urlEncode.apply("a b&c"), "a%20b%26c")
        XCTAssertEqual(TextTransform.urlDecode.apply("a%20b%26c"), "a b&c")
        XCTAssertEqual(TextTransform.base64Encode.apply("hello"), "aGVsbG8=")
        XCTAssertEqual(TextTransform.base64Decode.apply("aGVsbG8"), "hello")
        XCTAssertNil(TextTransform.base64Decode.apply("@@@"))
    }

    func testIdentifiers() {
        XCTAssertEqual(TextTransform.snakeCase.apply("userFirstName"), "user_first_name")
        XCTAssertEqual(TextTransform.snakeCase.apply("User first name"), "user_first_name")
        XCTAssertEqual(TextTransform.camelCase.apply("user_first_name"), "userFirstName")
    }

    func testStripMarkdown() {
        XCTAssertEqual(TextTransform.stripMarkdown.apply("# Title\n**bold** and [link](http://x.y)\n- item"),
                       "Title\nbold and link\n• item")
    }
}

final class TextTransformExtraTests: XCTestCase {
    func testLines() {
        XCTAssertEqual(TextTransform.sortLines.apply("b\na\nc"), "a\nb\nc")
        XCTAssertEqual(TextTransform.uniqueLines.apply("a\nb\na"), "a\nb")
        XCTAssertNil(TextTransform.sortLines.apply("single"))
    }

    func testTracking() {
        XCTAssertEqual(TextTransform.removeTracking.apply("https://x.com/a?utm_source=tw&id=5&fbclid=abc"), "https://x.com/a?id=5")
        XCTAssertEqual(TextTransform.removeTracking.apply("https://x.com/a?utm_source=tw"), "https://x.com/a")
        XCTAssertNil(TextTransform.removeTracking.apply("https://x.com/a?id=5"))
    }

    func testColors() {
        XCTAssertEqual(TextTransform.colorToRGB.apply("#FF8000"), "rgb(255, 128, 0)")
        XCTAssertEqual(TextTransform.colorToHex.apply("rgb(255, 128, 0)"), "#FF8000")
    }

    func testTimestamp() {
        XCTAssertNotNil(TextTransform.timestampToDate.apply("1761609600"))
        XCTAssertNotNil(TextTransform.timestampToDate.apply("1761609600000"))
        XCTAssertNil(TextTransform.timestampToDate.apply("42"))
    }

    func testCalculator() {
        XCTAssertEqual(TextTransform.calculate.apply("2 + 3 * 4"), "14")
        XCTAssertEqual(TextTransform.calculate.apply("(2+3)*4"), "20")
        XCTAssertEqual(TextTransform.calculate.apply("10 / 4"), "2.5")
        XCTAssertEqual(TextTransform.calculate.apply("2^10"), "1024")
        XCTAssertEqual(TextTransform.calculate.apply("-3 + 1"), "-2")
        XCTAssertNil(TextTransform.calculate.apply("1/0"))
        XCTAssertNil(TextTransform.calculate.apply("42"))
        XCTAssertNil(TextTransform.calculate.apply("2026-10-28"), "dates are not subtractions")
        XCTAssertEqual(TextTransform.calculate.apply("10-3"), "7")
        XCTAssertNil(TextTransform.calculate.apply("hello + 1"))
    }

    func testJSONEscape() {
        XCTAssertEqual(TextTransform.jsonEscape.apply("a \"b\"\nc"), #""a \"b\"\nc""#)
    }
}
