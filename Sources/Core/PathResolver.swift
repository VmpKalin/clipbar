import Foundation

public enum PathResolver {
    /// Turns a pasted path-like string into a file URL if it exists on disk.
    public static func resolve(_ raw: String, fileManager: FileManager = .default) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("file://") {
            guard let url = URL(string: text) else { return nil }
            text = url.path(percentEncoded: false)
        }
        // Unescape shell-style "\ " produced by dragging into Terminal.
        text = text.replacingOccurrences(of: "\\ ", with: " ")
        let expanded = (text as NSString).expandingTildeInPath
        guard fileManager.fileExists(atPath: expanded) else { return nil }
        return URL(fileURLWithPath: expanded)
    }

    /// The directory a terminal should open in for the given URL: the URL itself when it is a
    /// directory, otherwise its parent.
    public static func terminalDirectory(for url: URL, fileManager: FileManager = .default) -> URL {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }

    public static func displayName(for raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = text.hasPrefix("file://") ? (URL(string: text)?.path(percentEncoded: false) ?? text) : text
        let trimmed = stripped.hasSuffix("/") && stripped.count > 1 ? String(stripped.dropLast()) : stripped
        let name = (trimmed as NSString).lastPathComponent
        return name.isEmpty ? trimmed : name
    }
}
