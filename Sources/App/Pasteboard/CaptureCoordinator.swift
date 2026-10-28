import AppKit
import Foundation
import Observation

/// Watches the pasteboard and feeds new content into the store.
@MainActor
@Observable
final class CaptureCoordinator {
    static let defaultIgnoredApps = [
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop",
        "com.apple.keychainaccess", "com.apple.Passwords", "com.lastpass.LastPass", "com.dashlane.dashlanephonefinal",
    ]

    private let reader: PasteboardReader
    private let store: ClipStore
    private var pollingTask: Task<Void, Never>?

    /// Incremented every time a new item is captured.
    private(set) var captureCount = 0

    var isPaused: Bool {
        didSet { UserDefaults.standard.set(isPaused, forKey: "capturePaused") }
    }

    var ignoredBundleIDs: [String] {
        didSet { UserDefaults.standard.set(ignoredBundleIDs, forKey: "ignoredApps") }
    }

    init(reader: PasteboardReader, store: ClipStore) {
        self.reader = reader
        self.store = store
        self.isPaused = UserDefaults.standard.bool(forKey: "capturePaused")
        self.ignoredBundleIDs = UserDefaults.standard.stringArray(forKey: "ignoredApps") ?? Self.defaultIgnoredApps
    }

    var historyLimit: Int {
        UserDefaults.standard.object(forKey: "historyLimit") as? Int ?? 1000
    }

    /// Reads the pasteboard once. Returns the ingested item, if any.
    @discardableResult
    func captureNow() -> ClipItem? {
        guard var payload = reader.readIfChanged() else { return nil }
        guard !isPaused else { return nil }
        let front = NSWorkspace.shared.frontmostApplication
        if let id = front?.bundleIdentifier {
            if ignoredBundleIDs.contains(id) { return nil }
            if id != Bundle.main.bundleIdentifier {
                payload.sourceAppBundleID = id
                payload.sourceAppName = front?.localizedName
            }
        }
        guard let item = store.ingest(payload) else { return nil }
        store.enforceLimit(historyLimit)
        captureCount += 1
        return item
    }

    /// Marks the current pasteboard as already seen (after the app wrote to it).
    func ignoreCurrentPasteboard() { reader.markCurrentAsSeen() }

    func currentClipboardString() -> String { reader.currentString() }

    func startPolling(interval: Duration = .milliseconds(400)) {
        guard pollingTask == nil else { return }
        runMaintenance()
        pollingTask = Task { [weak self] in
            var ticks = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.captureNow()
                ticks += 1
                if ticks % 150 == 0 { self?.runMaintenance() } // about once a minute
            }
        }
    }

    /// Minutes after which secrets (API keys, tokens) are removed. 0 keeps them.
    var secretLifetimeMinutes: Int {
        UserDefaults.standard.object(forKey: "secretLifetimeMinutes") as? Int ?? 10
    }

    /// Days after which unpinned clips are removed. 0 keeps them.
    var historyMaxAgeDays: Int {
        UserDefaults.standard.object(forKey: "historyMaxAgeDays") as? Int ?? 0
    }

    func runMaintenance(now: Date = .now) {
        if secretLifetimeMinutes > 0 {
            store.removeSecrets(olderThan: now.addingTimeInterval(-Double(secretLifetimeMinutes) * 60))
        }
        if historyMaxAgeDays > 0 {
            store.removeUnpinned(olderThan: now.addingTimeInterval(-Double(historyMaxAgeDays) * 86_400))
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
