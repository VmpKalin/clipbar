import Foundation

/// Filters for the Clipboard tab.
public enum ClipSection: String, CaseIterable, Identifiable, Sendable {
    case all, pinned, frequent, text, images, links, paths, code, colors, contactInfo

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "All"
        case .pinned: "Pinned"
        case .frequent: "Frequent"
        case .text: "Text"
        case .images: "Images"
        case .links: "Links"
        case .paths: "Files"
        case .code: "Code"
        case .colors: "Colors"
        case .contactInfo: "Emails & Phones"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: "clock.arrow.circlepath"
        case .pinned: "pin.fill"
        case .frequent: "flame.fill"
        case .text: "text.alignleft"
        case .images: "photo.on.rectangle"
        case .links: "link"
        case .paths: "folder"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .colors: "paintpalette"
        case .contactInfo: "at"
        }
    }

    public func includes(_ item: ClipItem) -> Bool {
        switch self {
        case .all: true
        case .pinned: item.isPinned
        case .frequent: item.useCount > 0
        case .text: item.kind == .text
        case .images: item.kind == .image
        case .links: item.kind == .link
        case .paths: item.kind == .filePath
        case .code: item.tags.contains(.code)
        case .colors: item.tags.contains(.color)
        case .contactInfo: !item.tags.isDisjoint(with: [.email, .phone])
        }
    }

    /// Filters and orders `items` (any order) for display in this section.
    /// With a search query, results are ordered by match quality (pinned first in All).
    public func apply(to items: [ClipItem], search: String = "") -> [ClipItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let filtered = items.filter { includes($0) }

        if !query.isEmpty {
            let scored: [(ClipItem, Int)] = filtered.compactMap { item in
                guard let s = SearchMatcher.score(query, fields: [item.text, item.title, item.sourceAppName]) else {
                    return nil
                }
                return (item, s)
            }
            return scored.sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.createdAt > b.0.createdAt
            }.map(\.0)
        }

        switch self {
        case .frequent:
            return filtered.sorted { a, b in
                if a.useCount != b.useCount { return a.useCount > b.useCount }
                return a.lastUsedAt > b.lastUsedAt
            }
        case .all:
            return filtered.sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.createdAt > b.createdAt
            }
        default:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        }
    }
}
