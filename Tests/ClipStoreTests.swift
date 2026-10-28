import SwiftData
import XCTest
@testable import ClipBarTests

@MainActor
final class ClipStoreTests: XCTestCase {
    var container: ModelContainer!
    var store: ClipStore!
    var imagesDir: URL!

    override func setUp() async throws {
        container = try Storage.makeModelContainer(inMemory: true)
        imagesDir = FileManager.default.temporaryDirectory.appending(path: "clipbar-tests-\(UUID().uuidString)")
        store = ClipStore(context: container.mainContext, images: ImageFileStore(directory: imagesDir))
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: imagesDir)
    }

    func testIngestCreatesItem() {
        let item = store.ingest(ClipPayload(text: "hello"))
        XCTAssertEqual(item?.kind, .text)
        XCTAssertEqual(store.allItems().count, 1)
    }

    func testIngestDedupsAndBumps() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 2000)
        let t2 = Date(timeIntervalSince1970: 3000)
        store.ingest(ClipPayload(text: "a"), now: t0)
        store.ingest(ClipPayload(text: "b"), now: t1)
        store.ingest(ClipPayload(text: "a"), now: t2)
        let items = store.allItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.text, "a")
        XCTAssertEqual(items.first?.createdAt, t2)
    }

    func testMarkUsed() {
        let item = store.ingest(ClipPayload(text: "x"))!
        let t = Date(timeIntervalSince1970: 5000)
        store.markUsed(item, now: t)
        store.markUsed(item, now: t)
        XCTAssertEqual(item.useCount, 2)
        XCTAssertEqual(item.lastUsedAt, t)
    }

    func testEnforceLimitKeepsNewestAndProtected() {
        for i in 0..<6 {
            store.ingest(ClipPayload(text: "item\(i)"), now: Date(timeIntervalSince1970: Double(i)))
        }
        let items = store.allItems() // newest first: item5..item0
        store.togglePin(items[4])   // item1 pinned
        store.toggleSaved(items[5]) // item0 saved
        store.enforceLimit(2)
        let remaining = Set(store.allItems().compactMap(\.text))
        XCTAssertEqual(remaining, ["item5", "item4", "item1", "item0"])
    }

    func testEnforceLimitZeroIsUnlimited() {
        for i in 0..<5 { store.ingest(ClipPayload(text: "i\(i)")) }
        store.enforceLimit(0)
        XCTAssertEqual(store.allItems().count, 5)
    }

    func testClearHistoryKeepsPinnedAndSaved() {
        let a = store.ingest(ClipPayload(text: "a"))!
        let b = store.ingest(ClipPayload(text: "b"))!
        store.ingest(ClipPayload(text: "c"))
        store.togglePin(a)
        store.toggleSaved(b)
        store.clearHistory()
        XCTAssertEqual(Set(store.allItems().compactMap(\.text)), ["a", "b"])
    }

    func testImageIngestWritesFileAndDeleteRemovesIt() throws {
        let png = try makePNG()
        let item = try XCTUnwrap(store.ingest(ClipPayload(imageData: png)))
        XCTAssertEqual(item.kind, .image)
        XCTAssertEqual(item.imageWidth, 8)
        XCTAssertEqual(item.imageHeight, 4)
        XCTAssertNotNil(item.thumbnailData)
        let file = store.images.url(for: try XCTUnwrap(item.imageFileName))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        store.delete(item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(store.allItems().count, 0)
    }

    func testOnChangeFires() {
        var fired = 0
        store.onChange = { fired += 1 }
        store.ingest(ClipPayload(text: "z"))
        XCTAssertEqual(fired, 1)
    }

    func testSourceAppRecorded() {
        let item = store.ingest(ClipPayload(text: "x", sourceAppBundleID: "com.apple.Safari", sourceAppName: "Safari"))
        XCTAssertEqual(item?.sourceAppName, "Safari")
        XCTAssertEqual(ClipSection.all.apply(to: store.allItems(), search: "safari").count, 1)
    }

    func testUpdateTextReclassifiesAndMerges() {
        let a = store.ingest(ClipPayload(text: "hello"))!
        let b = store.ingest(ClipPayload(text: "https://example.com"))!
        store.markUsed(b)
        store.updateText(a, to: "https://example.com")
        XCTAssertEqual(store.allItems().count, 1)
        XCTAssertEqual(a.kind, .link)
        XCTAssertEqual(a.useCount, 1)
    }

    func testSmartSections() {
        store.ingest(ClipPayload(text: "#ff0000"))
        store.ingest(ClipPayload(text: "me@example.com"))
        store.ingest(ClipPayload(text: "git push"))
        let all = store.allItems()
        XCTAssertEqual(ClipSection.colors.apply(to: all).map(\.text), ["#ff0000"])
        XCTAssertEqual(ClipSection.contactInfo.apply(to: all).map(\.text), ["me@example.com"])
        XCTAssertEqual(ClipSection.code.apply(to: all).map(\.text), ["git push"])
    }

    // MARK: Sections

    func testSectionsFilterAndSort() {
        let t = { (i: Double) in Date(timeIntervalSince1970: i) }
        let text = store.ingest(ClipPayload(text: "plain"), now: t(1))!
        let link = store.ingest(ClipPayload(text: "https://example.com/a"), now: t(2))!
        let path = store.ingest(ClipPayload(text: "/tmp"), now: t(3))!
        store.togglePin(text)
        store.markUsed(link); store.markUsed(link); store.markUsed(path)
        let all = store.allItems()

        XCTAssertEqual(ClipSection.all.apply(to: all).map(\.text), ["plain", "/tmp", "https://example.com/a"])
        XCTAssertEqual(ClipSection.pinned.apply(to: all).map(\.text), ["plain"])
        XCTAssertEqual(ClipSection.links.apply(to: all).map(\.text), ["https://example.com/a"])
        XCTAssertEqual(ClipSection.paths.apply(to: all).map(\.text), ["/tmp"])
        XCTAssertEqual(ClipSection.frequent.apply(to: all).map(\.text), ["https://example.com/a", "/tmp"])
        XCTAssertEqual(ClipSection.all.apply(to: all, search: "EXAMPLE").map(\.text), ["https://example.com/a"])
        XCTAssertTrue(ClipSection.images.apply(to: all).isEmpty)
    }

    private func makePNG() throws -> Data {
        let w = 8, h = 4
        var pixels = [UInt8](repeating: 200, count: w * h * 4)
        for i in stride(from: 3, to: pixels.count, by: 4) { pixels[i] = 255 }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = try XCTUnwrap(pixels.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        })
        let image = try XCTUnwrap(ctx.makeImage())
        return try XCTUnwrap(ImageFileStore.encode(image, as: .png, quality: 1))
    }
}
