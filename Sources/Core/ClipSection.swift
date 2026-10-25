import Foundation

public enum ClipSection: String, CaseIterable, Identifiable, Sendable {
    case all, pinned, saved, frequent, images, links, paths

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .saved: "Saved"
        case .frequent: "Frequent"
        case .images: "Images"
        case .links: "Links"
        case .paths: "Paths"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: "clock.arrow.circlepath"
        case .pinned: "pin.fill"
        case .saved: "bookmark.fill"
        case .frequent: "flame.fill"
        case .images: "photo.on.rectangle"
        case .links: "link"
        case .paths: "folder"
        }
    }

    public func includes(_ item: ClipItem) -> Bool {
        switch self {
        case .all: true
        case .pinned: item.isPinned
        case .saved: item.isSaved
        case .frequent: item.useCount > 0
        case .images: item.kind == .image
        case .links: item.kind == .link
        case .paths: item.kind == .filePath
        }
    }

    /// Filters and orders `items` (any order) for display in this section.
    public func apply(to items: [ClipItem], search: String = "") -> [ClipItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        var result = items.filter { includes($0) && Self.matches($0, query: query) }
        switch self {
        case .frequent:
            result.sort { a, b in
                if a.useCount != b.useCount { return a.useCount > b.useCount }
                return a.lastUsedAt > b.lastUsedAt
            }
        case .all:
            result.sort { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.createdAt > b.createdAt
            }
        default:
            result.sort { $0.createdAt > $1.createdAt }
        }
        return result
    }

    static func matches(_ item: ClipItem, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        if let text = item.text, text.localizedCaseInsensitiveContains(query) { return true }
        return item.title.localizedCaseInsensitiveContains(query)
    }
}
