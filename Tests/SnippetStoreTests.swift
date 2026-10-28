import SwiftData
import XCTest
@testable import ClipBarTests

@MainActor
final class SnippetStoreTests: XCTestCase {
    var container: ModelContainer!
    var store: SnippetStore!

    override func setUp() async throws {
        container = try Storage.makeModelContainer(inMemory: true)
        store = SnippetStore(context: container.mainContext)
    }

    func testSeedOnlyOnce() {
        XCTAssertTrue(store.seedDefaultsIfNeeded())
        XCTAssertFalse(store.seedDefaultsIfNeeded())
        XCTAssertEqual(store.groups().map(\.name), ["Personal", "Work", "Templates", "Dynamic"])
        XCTAssertTrue(store.group(named: "dynamic")!.snippets.allSatisfy(\.isDynamic))
    }

    func testAddUpdateMoveDelete() {
        let g = store.addGroup(name: "Me", symbol: "person")
        let a = store.addSnippet(title: "Email", value: "a@b.co", keyword: "@m", to: g)
        let b = store.addSnippet(title: "Phone", value: "+1 555 0100", to: g)
        XCTAssertEqual(g.sortedSnippets.map(\.title), ["Email", "Phone"])
        store.move(b, by: -1)
        XCTAssertEqual(g.sortedSnippets.map(\.title), ["Phone", "Email"])

        let other = store.addGroup(name: "Work")
        store.update(a, title: "Work email", value: "a@work.co", keyword: "", group: other)
        XCTAssertEqual(other.snippets.map(\.title), ["Work email"])
        XCTAssertEqual(g.snippets.map(\.title), ["Phone"])

        store.markUsed(b)
        XCTAssertEqual(b.useCount, 1)

        store.delete(g)
        XCTAssertEqual(store.allSnippets().map(\.title), ["Work email"], "deleting a group deletes its snippets")
    }

    func testExportImportRoundTrip() throws {
        let g = store.addGroup(name: "Me", symbol: "person")
        store.addSnippet(title: "Email", value: "a@b.co", keyword: "@m", to: g)
        let data = try store.exportArchive()

        let container2 = try Storage.makeModelContainer(inMemory: true)
        let store2 = SnippetStore(context: container2.mainContext)
        XCTAssertEqual(try store2.importArchive(data), 1)
        XCTAssertEqual(try store2.importArchive(data), 0, "re-import skips duplicates")
        XCTAssertEqual(store2.group(named: "Me")?.snippets.first?.keyword, "@m")
        XCTAssertEqual(try store2.exportArchive(), data)
    }
}
