import Foundation
import Observation
#if os(iOS)
import WidgetKit
#endif

/// Reads the pasteboard and feeds new content into the store.
@MainActor
@Observable
final class CaptureCoordinator {
    private let reader: PasteboardReader
    private let store: ClipStore
    private var pollingTask: Task<Void, Never>?

    /// Incremented every time a new item is captured, for UI feedback.
    private(set) var captureCount = 0

    init(reader: PasteboardReader, store: ClipStore) {
        self.reader = reader
        self.store = store
    }

    var historyLimit: Int {
        let v = UserDefaults.standard.object(forKey: "historyLimit") as? Int
        return v ?? 500
    }

    /// Reads the pasteboard once. Returns the ingested item, if any.
    @discardableResult
    func captureNow() -> ClipItem? {
        guard let payload = reader.readIfChanged() else { return nil }
        guard let item = store.ingest(payload) else { return nil }
        store.enforceLimit(historyLimit)
        captureCount += 1
        return item
    }

    /// Marks the current pasteboard as already seen (after the app wrote to it).
    func ignoreCurrentPasteboard() { reader.markCurrentAsSeen() }

    /// macOS: observe the pasteboard continuously, like Maccy.
    func startPolling(interval: Duration = .milliseconds(500)) {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.captureNow()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
