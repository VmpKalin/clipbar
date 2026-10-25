import XCTest
@testable import ClipBarTests

final class ClipClassifierTests: XCTestCase {
    func testPlainText() { XCTAssertEqual(ClipClassifier.kind(forText: "hello world"), .text) }
    func testLink() { XCTAssertEqual(ClipClassifier.kind(forText: "https://apple.com/x?y=1"), .link) }
    func testHttpLink() { XCTAssertEqual(ClipClassifier.kind(forText: "http://localhost:5173/"), .link) }
    func testAbsolutePath() { XCTAssertEqual(ClipClassifier.kind(forText: "/Users/a/b.txt"), .filePath) }
    func testTildePath() { XCTAssertEqual(ClipClassifier.kind(forText: "~/Desktop"), .filePath) }
    func testFileURL() { XCTAssertEqual(ClipClassifier.kind(forText: "file:///tmp/x"), .filePath) }
    func testMultilineIsText() { XCTAssertEqual(ClipClassifier.kind(forText: "/a\n/b"), .text) }
    func testEmptyIsText() { XCTAssertEqual(ClipClassifier.kind(forText: "   "), .text) }
    func testShellCommandIsText() { XCTAssertEqual(ClipClassifier.kind(forText: "sudo xcodebuild -license accept"), .text) }

    func testImagePayload() {
        let p = ClipPayload(imageData: Data([1, 2, 3]))
        XCTAssertEqual(p.kind, .image)
        XCTAssertNil(p.text)
    }

    func testHashStableAndDistinct() {
        XCTAssertEqual(ClipPayload(text: "abc").contentHash, ClipPayload(text: "abc").contentHash)
        XCTAssertNotEqual(ClipPayload(text: "abc").contentHash, ClipPayload(text: "abd").contentHash)
        XCTAssertEqual(ClipPayload(text: "abc").contentHash.count, 64)
    }
}
