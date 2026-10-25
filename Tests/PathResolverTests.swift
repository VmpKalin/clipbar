import XCTest
@testable import ClipBarTests

final class PathResolverTests: XCTestCase {
    func testTildeExpands() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(PathResolver.resolve("~/")?.path, home)
        XCTAssertEqual(PathResolver.resolve("~")?.path, home)
    }

    func testFileURLStripped() {
        XCTAssertEqual(PathResolver.resolve("file:///tmp")?.path, "/tmp")
    }

    func testMissingPathIsNil() {
        XCTAssertNil(PathResolver.resolve("/definitely/missing/\(UUID().uuidString)"))
    }

    func testEscapedSpaces() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "clip test \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let escaped = dir.path.replacingOccurrences(of: " ", with: "\\ ")
        XCTAssertEqual(PathResolver.resolve(escaped)?.path, dir.path)
    }

    func testTerminalDirectoryForFileIsParent() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "f-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(PathResolver.terminalDirectory(for: file).path, file.deletingLastPathComponent().path)
    }

    func testTerminalDirectoryForDirIsItself() {
        let tmp = FileManager.default.temporaryDirectory
        XCTAssertEqual(PathResolver.terminalDirectory(for: tmp).path, tmp.path)
    }

    func testDisplayName() {
        XCTAssertEqual(PathResolver.displayName(for: "/Users/a/b.txt"), "b.txt")
        XCTAssertEqual(PathResolver.displayName(for: "/Users/a/dir/"), "dir")
        XCTAssertEqual(PathResolver.displayName(for: "file:///tmp/x.mp4"), "x.mp4")
        XCTAssertEqual(PathResolver.displayName(for: "/"), "/")
    }
}
