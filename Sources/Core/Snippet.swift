import Foundation
import SwiftData

/// A named group in the Library ("Personal", "Work", "Templates"…).
@Model
public final class SnippetGroup {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var symbol: String
    public var order: Int
    public var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Snippet.group)
    public var snippets: [Snippet] = []

    public init(id: UUID = UUID(), name: String, symbol: String = "folder", order: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.order = order
        self.createdAt = createdAt
    }

    public var sortedSnippets: [Snippet] {
        snippets.sorted { a, b in
            if a.order != b.order { return a.order < b.order }
            return a.createdAt < b.createdAt
        }
    }
}

/// A reusable piece of information: an email, an address, a reply template, a dynamic date…
@Model
public final class Snippet {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var value: String
    /// Optional short trigger for search, e.g. "@mail".
    public var keyword: String
    public var order: Int
    public var createdAt: Date
    public var lastUsedAt: Date
    public var useCount: Int
    public var group: SnippetGroup?

    public init(id: UUID = UUID(), title: String, value: String, keyword: String = "", order: Int = 0,
                createdAt: Date = .now, lastUsedAt: Date = .now, useCount: Int = 0, group: SnippetGroup? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.keyword = keyword
        self.order = order
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
        self.group = group
    }

    public var isDynamic: Bool { TemplateExpander.containsTokens(value) }
}
