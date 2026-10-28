import Foundation
import SwiftData

public enum ClipKind: String, Codable, CaseIterable, Sendable {
    case text
    case link
    case image
    case filePath
}

@Model
public final class ClipItem {
    @Attribute(.unique) public var id: UUID
    public var kindRaw: String
    public var text: String?
    public var imageFileName: String?
    public var thumbnailData: Data?
    public var imageWidth: Int
    public var imageHeight: Int
    public var contentHash: String
    public var createdAt: Date
    public var lastUsedAt: Date
    public var useCount: Int
    public var isPinned: Bool
    public var isSaved: Bool
    /// Bundle identifier of the app that was frontmost when the clip was captured.
    public var sourceAppBundleID: String? = nil
    public var sourceAppName: String? = nil

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        text: String? = nil,
        imageFileName: String? = nil,
        thumbnailData: Data? = nil,
        imageWidth: Int = 0,
        imageHeight: Int = 0,
        contentHash: String,
        createdAt: Date = .now,
        lastUsedAt: Date = .now,
        useCount: Int = 0,
        isPinned: Bool = false,
        isSaved: Bool = false,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.text = text
        self.imageFileName = imageFileName
        self.thumbnailData = thumbnailData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.isPinned = isPinned
        self.isSaved = isSaved
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }

    public var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    /// Content tags derived from the text (email, color, JSON…). Not stored.
    public var tags: Set<ContentTag> {
        guard kind == .text, let text else { return [] }
        return ContentInspector.cachedTags(for: text, key: contentHash)
    }

    /// Short single-line title used in rows.
    public var title: String {
        switch kind {
        case .image:
            return imageWidth > 0 ? "Image \(imageWidth)×\(imageHeight)" : "Image"
        case .link:
            if let t = text, let url = URL(string: t), let host = url.host() { return host }
            return text ?? ""
        case .filePath:
            let paths = PathResolver.paths(in: text ?? "")
            if paths.count > 1 {
                return "\(PathResolver.displayName(for: paths[0])) + \(paths.count - 1) more"
            }
            return PathResolver.displayName(for: text ?? "")
        case .text:
            return (text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ⏎ ")
        }
    }
}
