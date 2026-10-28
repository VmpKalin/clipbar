import CryptoKit
import Foundation

/// A platform-neutral description of what was found on the pasteboard.
public struct ClipPayload: Sendable, Equatable {
    public let kind: ClipKind
    public let text: String?
    public let imageData: Data?
    public let contentHash: String
    public var sourceAppBundleID: String?
    public var sourceAppName: String?

    public init(text: String, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        self.kind = ClipClassifier.kind(forText: text)
        self.text = text
        self.imageData = nil
        self.contentHash = ClipClassifier.hash(Data(text.utf8))
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }

    public init(imageData: Data, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        self.kind = .image
        self.text = nil
        self.imageData = imageData
        self.contentHash = ClipClassifier.hash(imageData)
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }
}

public enum ClipClassifier {
    public static func kind(forText raw: String) -> ClipKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .text }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)

        if lines.count > 1 {
            // Several files copied in Finder arrive as one path per line.
            return lines.allSatisfy(isPathLike) ? .filePath : .text
        }
        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host() != nil, !text.contains(" ") {
            return .link
        }
        if isPathLike(text) { return .filePath }
        return .text
    }

    static func isPathLike(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("file://") { return true }
        if t == "~" || t.hasPrefix("~/") { return true }
        // "/" followed by a non-space character: "/Users/x" yes, "/ comment" no.
        if t.hasPrefix("/"), t.count > 1, t.dropFirst().first != " " { return true }
        return false
    }

    public static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
