import SwiftData
import XCTest
@testable import ClipBarTests

@MainActor
final class SearchQueryTests: XCTestCase {
    func testParsing() {
        let q = SearchQuery("deploy app:Terminal is:code")
        XCTAssertEqual(q.text, "deploy")
        XCTAssertEqual(q.filters, [.app("terminal"), .tag(.code)])
        XCTAssertEqual(SearchQuery("is:nonsense").text, "is:nonsense")
        XCTAssertEqual(SearchQuery("is:image").filters, [.kind(.image)])
    }

    func testFiltering() throws {
        let container = try Storage.makeModelContainer(inMemory: true)
        let store = ClipStore(context: container.mainContext,
                              images: ImageFileStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        store.ingest(ClipPayload(text: "git push", sourceAppBundleID: "com.apple.Terminal", sourceAppName: "Terminal"))
        store.ingest(ClipPayload(text: "git is great", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari"))
        store.ingest(ClipPayload(text: "https://git-scm.com", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari"),
                     now: Date().addingTimeInterval(-86_400 * 3))
        let all = store.allItems()
        XCTAssertEqual(ClipSection.all.apply(to: all, search: "git app:terminal").map(\.text), ["git push"])
        XCTAssertEqual(ClipSection.all.apply(to: all, search: "app:safari is:link").map(\.text), ["https://git-scm.com"])
        XCTAssertEqual(ClipSection.all.apply(to: all, search: "is:today").count, 2)
    }

    func testSecretsAreMaskedAndExpire() throws {
        let container = try Storage.makeModelContainer(inMemory: true)
        let store = ClipStore(context: container.mainContext,
                              images: ImageFileStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        let key = "sk-ant-api03-" + String(repeating: "x", count: 40)
        let item = try XCTUnwrap(store.ingest(ClipPayload(text: key), now: Date().addingTimeInterval(-3600)))
        XCTAssertTrue(item.isSecret)
        XCTAssertFalse(item.title.contains("xxxxxxxxxx"))
        XCTAssertTrue(ClipSection.all.apply(to: store.allItems(), search: "xxxxxxxx").isEmpty, "content not searchable")
        store.ingest(ClipPayload(text: "normal"))
        XCTAssertEqual(store.removeSecrets(olderThan: Date().addingTimeInterval(-600)), 1)
        XCTAssertEqual(store.allItems().map(\.text), ["normal"])
    }

    func testSecretDetection() {
        XCTAssertTrue(ContentInspector.isSecret("ghp_" + String(repeating: "a", count: 36)))
        XCTAssertTrue(ContentInspector.isSecret("AKIAIOSFODNN7EXAMPLE"))
        XCTAssertTrue(ContentInspector.isSecret("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"))
        XCTAssertFalse(ContentInspector.isSecret("this is a normal sentence that is long"))
        XCTAssertFalse(ContentInspector.isSecret("https://github.com/p0deje/Maccy"))
    }

    func testRemoveOld() throws {
        let container = try Storage.makeModelContainer(inMemory: true)
        let store = ClipStore(context: container.mainContext,
                              images: ImageFileStore(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)))
        let old = store.ingest(ClipPayload(text: "old"), now: Date().addingTimeInterval(-86_400 * 40))!
        store.ingest(ClipPayload(text: "old pinned"), now: Date().addingTimeInterval(-86_400 * 40)).map(store.togglePin)
        store.ingest(ClipPayload(text: "new"))
        _ = old
        XCTAssertEqual(store.removeUnpinned(olderThan: Date().addingTimeInterval(-86_400 * 30)), 1)
        XCTAssertEqual(Set(store.allItems().compactMap(\.text)), ["old pinned", "new"])
    }
}
