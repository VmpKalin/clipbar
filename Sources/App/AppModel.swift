import Foundation
import Observation
import SwiftData
#if os(iOS)
import UIKit
import WidgetKit
#endif

/// Owns the model container, the store and the capture pipeline for the whole app.
@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let store: ClipStore
    let capture: CaptureCoordinator
    /// Set when the persistent store could not be opened and an in-memory one is used instead.
    let storageWarning: String?

    /// Bumped on every copy for haptics / toast.
    private(set) var copyCount = 0
    private(set) var lastCopiedTitle = ""

    init() {
        var warning: String?
        let container: ModelContainer
        do {
            container = try AppGroup.makeModelContainer()
        } catch {
            warning = "History won't be saved: \(error.localizedDescription)"
            container = try! AppGroup.makeModelContainer(inMemory: true)
        }
        self.container = container
        self.storageWarning = warning
        let store = ClipStore(context: container.mainContext, images: ImageFileStore(directory: AppGroup.imagesURL))
        self.store = store
        self.capture = CaptureCoordinator(reader: SystemPasteboardReader(), store: store)
        store.onChange = {
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
        #if os(macOS)
        capture.captureNow()
        capture.startPolling()
        #endif
    }

    // MARK: Actions

    func copy(_ item: ClipItem) {
        PasteboardWriter.write(item, images: store.images)
        capture.ignoreCurrentPasteboard()
        store.markUsed(item)
        lastCopiedTitle = item.title
        copyCount += 1
    }

    func togglePin(_ item: ClipItem) { store.togglePin(item) }
    func toggleSaved(_ item: ClipItem) { store.toggleSaved(item) }
    func delete(_ item: ClipItem) { store.delete(item) }
    func clearHistory() { store.clearHistory() }

    func imageData(for item: ClipItem) -> Data? {
        guard let name = item.imageFileName else { return nil }
        return try? Data(contentsOf: store.images.url(for: name))
    }
}
