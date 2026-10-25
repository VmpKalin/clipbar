import Foundation
import SwiftData

public enum AppGroup {
    public static let identifier = "group.com.aholoiad.clipbar"

    /// Shared container on iOS (App Group); Application Support on macOS, where the app is
    /// signed ad hoc and has no App Group entitlement.
    public static var containerURL: URL {
        #if os(iOS)
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appending(path: "ClipBar")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public static var imagesURL: URL { containerURL.appending(path: "Images") }
    public static var storeURL: URL { containerURL.appending(path: "ClipBar.store") }

    public static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([ClipItem.self])
        let config = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
