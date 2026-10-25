import Foundation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@MainActor
enum PathActions {
    static func resolvedURL(for item: ClipItem) -> URL? {
        guard item.kind == .filePath, let text = item.text else { return nil }
        return PathResolver.resolve(text)
    }

    #if os(macOS)
    static func openInFinder(_ url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    static func openInTerminal(_ url: URL) {
        let dir = PathResolver.terminalDirectory(for: url)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", dir.path]
        try? process.run()
    }
    #else
    /// Files app deep link; nil when the Files app cannot show this location.
    static func filesAppURL(for url: URL) -> URL? {
        guard let encoded = url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        let target = URL(string: "shareddocuments://" + encoded)
        guard let target, UIApplication.shared.canOpenURL(target) else { return nil }
        return target
    }

    static func openInFiles(_ url: URL) {
        guard let target = filesAppURL(for: url) else { return }
        UIApplication.shared.open(target)
    }
    #endif
}
