import CryptoKit
import Foundation

/// A platform-neutral description of what was found on the pasteboard.
public struct ClipPayload: Sendable, Equatable {
    public let kind: ClipKind
    public let text: String?
    public let imageData: Data?
    public let contentHash: String

    public init(text: String) {
        self.kind = ClipClassifier.kind(forText: text)
        self.text = text
        self.imageData = nil
        self.contentHash = ClipClassifier.hash(Data(text.utf8))
    }

    public init(imageData: Data) {
        self.kind = .image
        self.text = nil
        self.imageData = imageData
        self.contentHash = ClipClassifier.hash(imageData)
    }
}

public enum ClipClassifier {
    public static func kind(forText raw: String) -> ClipKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .text }
        let singleLine = !text.contains("\n") && !text.contains("\r")
        guard singleLine else { return .text }

        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme), url.host() != nil {
            return .link
        }
        if text.hasPrefix("file://") { return .filePath }
        if text.hasPrefix("/") || text.hasPrefix("~/") || text == "~" {
            // Avoid treating things like "/ comment" or "/regex/" as paths: require no spaces unless escaped.
            return .filePath
        }
        return .text
    }

    public static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
