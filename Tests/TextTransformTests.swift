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
