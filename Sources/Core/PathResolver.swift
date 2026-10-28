import Foundation

public enum PathResolver {
    /// Splits a clip into path lines (several files copied in Finder arrive one per line).
    public static func paths(in raw: String) -> [String] {
        raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Turns a pasted path-like string into a file URL if it exists on disk.
    /// For a multi-line clip the first path is used.
    public static func resolve(_ raw: String, fileManager: FileManager = .default) -> URL? {
        guard var text = paths(in: raw).first else { return nil }
        if text.hasPrefix("file://") {
            guard let url = URL(string: text) else { return nil }
            text = url.path(percentEncoded: false)
        }
        // Unescape shell-style "\ " produced by dragging into Terminal, and strip quotes.
        text = text.replacingOccurrences(of: "\\ ", with: " ")
        if text.count > 1, (text.hasPrefix("'") && text.hasSuffix("'")) || (text.hasPrefix("\"") && text.hasSuffix("\"")) {
            text = String(text.dropFirst().dropLast())
        }
        let expanded = (text as NSString).expandingTildeInPath
        guard fileManager.fileExists(atPath: expanded) else { return nil }
        return URL(fileURLWithPath: expanded)
    }

    /// All existing files in a (possibly multi-line) path clip.
    public static func resolveAll(_ raw: String, fileManager: FileManager = .default) -> [URL] {
        paths(in: raw).compactMap { resolve($0, fileManager: fileManager) }
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

    public static func isDirectory(_ url: URL, fileManager: FileManager = .default) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    public static func displayName(for raw: String) -> String {
        let text = paths(in: raw).first ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = text.hasPrefix("file://") ? (URL(string: text)?.path(percentEncoded: false) ?? text) : text
        let trimmed = stripped.hasSuffix("/") && stripped.count > 1 ? String(stripped.dropLast()) : stripped
        let name = (trimmed as NSString).lastPathComponent
        return name.isEmpty ? trimmed : name
    }
}
