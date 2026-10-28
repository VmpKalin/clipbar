import XCTest
@testable import ClipBarTests

final class ContentInspectorTests: XCTestCase {
    func testEmail() {
        XCTAssertTrue(ContentInspector.tags(for: "artur@example.com").contains(.email))
        XCTAssertFalse(ContentInspector.tags(for: "write to artur@example.com please").contains(.email))
    }

    func testPhone() {
        XCTAssertTrue(ContentInspector.isPhone("+380 67 123 45 67"))
        XCTAssertTrue(ContentInspector.isPhone("(555) 123-4567"))
        XCTAssertFalse(ContentInspector.isPhone("1234567"))   // bare number, no formatting
        XCTAssertFalse(ContentInspector.isPhone("2026-10-28"))
    }

    func testColors() {
        let c = ContentInspector.color(in: "#FF8000")
        XCTAssertEqual(c?.r ?? -1, 1, accuracy: 0.001)
        XCTAssertEqual(c?.g ?? -1, 128.0 / 255, accuracy: 0.001)
        XCTAssertEqual(c?.b ?? -1, 0, accuracy: 0.001)
        XCTAssertNotNil(ContentInspector.color(in: "#abc"))
        XCTAssertNotNil(ContentInspector.color(in: "rgba(10, 20, 30, 0.5)"))
        XCTAssertNil(ContentInspector.color(in: "123456"))
        XCTAssertNil(ContentInspector.color(in: "rgb(300,0,0)"))
    }

    func testJSONAndCode() {
        let tags = ContentInspector.tags(for: #"{"a": 1, "b": [true]}"#)
        XCTAssertTrue(tags.contains(.json))
        XCTAssertTrue(tags.contains(.code))
        XCTAssertTrue(ContentInspector.tags(for: "git status").contains(.code))
        XCTAssertFalse(ContentInspector.tags(for: "Hello there").contains(.code))
    }

    func testNumber() {
        XCTAssertTrue(ContentInspector.tags(for: "1 234,5").contains(.number) || ContentInspector.tags(for: "1234.5").contains(.number))
        XCTAssertTrue(ContentInspector.tags(for: "42").contains(.number))
    }

    func testStats() {
        let s = ContentInspector.stats(for: "one two\nthree")
        XCTAssertEqual(s.characters, 13)
        XCTAssertEqual(s.words, 3)
        XCTAssertEqual(s.lines, 2)
    }
}
