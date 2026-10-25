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
        isSaved: Bool = false
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
    }

    public var kind: ClipKind {
        get { ClipKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    /// Short single-line title used in rows and widgets.
    public var title: String {
        switch kind {
        case .image:
            return imageWidth > 0 ? "Image \(imageWidth)×\(imageHeight)" : "Image"
        case .link:
            if let t = text, let url = URL(string: t), let host = url.host() { return host }
            return text ?? ""
        case .filePath:
            return PathResolver.displayName(for: text ?? "")
        case .text:
            return (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
