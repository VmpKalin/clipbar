import AppKit
import Foundation

@MainActor
enum PathActions {
    static func resolvedURLs(for item: ClipItem) -> [URL] {
        guard item.kind == .filePath, let text = item.text else { return [] }
        return PathResolver.resolveAll(text)
    }

    static func openInFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if urls.count == 1, PathResolver.isDirectory(urls[0]) {
            NSWorkspace.shared.open(urls[0])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    static func openInTerminal(_ url: URL) {
        let dir = PathResolver.terminalDirectory(for: url)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", dir.path]
        try? process.run()
    }

    static func openWithDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

/// Caches app icons by bundle identifier.
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        cache[bundleID] = icon
        return icon
    }

    static func icon(forFile url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }
}
