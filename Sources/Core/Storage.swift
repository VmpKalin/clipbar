import Foundation
import SwiftData

/// Where ClipBar keeps its data: ~/Library/Application Support/ClipBar.
public enum Storage {
    public static var containerURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "ClipBar")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var imagesURL: URL { containerURL.appending(path: "Images") }
    public static var storeURL: URL { containerURL.appending(path: "ClipBar.store") }

    public static let schema = Schema([ClipItem.self, SnippetGroup.self, Snippet.self])

    public static func makeModelContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let config = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: url ?? storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
