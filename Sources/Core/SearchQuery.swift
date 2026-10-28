import Foundation

/// A search string with optional filters:
///
/// - `app:safari` — clips copied in an app whose name contains "safari"
/// - `is:image` / `is:link` / `is:file` / `is:text` / `is:pinned` / `is:code` / `is:color` / `is:email` / `is:phone`
/// - `is:today` / `is:yesterday` limit by capture date
///
/// Everything else is free text matched with `SearchMatcher`.
public struct SearchQuery: Equatable, Sendable {
    public enum Filter: Equatable, Sendable {
        case app(String)
        case kind(ClipKind)
        case tag(ContentTag)
        case pinned
        case day(offset: Int)
    }

    public var text: String
    public var filters: [Filter]

    public init(_ raw: String) {
        var words: [String] = []
        var filters: [Filter] = []
        for token in raw.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
            let lower = token.lowercased()
            if lower.hasPrefix("app:"), lower.count > 4 {
                filters.append(.app(String(lower.dropFirst(4))))
            } else if lower.hasPrefix("is:"), let f = Self.filter(forIs: String(lower.dropFirst(3))) {
                filters.append(f)
            } else {
                words.append(token)
            }
        }
        self.text = words.joined(separator: " ")
        self.filters = filters
    }

    public var isEmpty: Bool { text.isEmpty && filters.isEmpty }

    static func filter(forIs value: String) -> Filter? {
        switch value {
        case "image", "images", "img": .kind(.image)
        case "link", "links", "url": .kind(.link)
        case "file", "files", "path", "paths": .kind(.filePath)
        case "text": .kind(.text)
        case "pinned", "pin": .pinned
        case "code": .tag(.code)
        case "color", "colors": .tag(.color)
        case "email", "mail": .tag(.email)
        case "phone", "tel": .tag(.phone)
        case "json": .tag(.json)
        case "number", "num": .tag(.number)
        case "secret", "key": .tag(.secret)
        case "today": .day(offset: 0)
        case "yesterday": .day(offset: -1)
        default: nil
        }
    }

    public func matchesFilters(_ item: ClipItem, calendar: Calendar = .current, now: Date = .now) -> Bool {
        filters.allSatisfy { filter in
            switch filter {
            case .app(let name):
                return (item.sourceAppName ?? "").lowercased().contains(name)
                    || (item.sourceAppBundleID ?? "").lowercased().contains(name)
            case .kind(let kind): return item.kind == kind
            case .tag(let tag): return item.tags.contains(tag)
            case .pinned: return item.isPinned
            case .day(let offset):
                guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { return false }
                return calendar.isDate(item.createdAt, inSameDayAs: day)
            }
        }
    }
}
