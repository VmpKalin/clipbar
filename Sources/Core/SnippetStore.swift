import Foundation
import OSLog
import SwiftData

/// Reads and writes the Library (groups and snippets).
@MainActor
public final class SnippetStore {
    public let context: ModelContext
    private let logger = Logger(subsystem: "com.aholoiad.clipbar", category: "SnippetStore")

    /// Called after any mutation.
    public var onChange: (@MainActor () -> Void)?

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: Queries

    public func groups() -> [SnippetGroup] {
        let d = FetchDescriptor<SnippetGroup>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)])
        return (try? context.fetch(d)) ?? []
    }

    public func allSnippets() -> [Snippet] {
        let d = FetchDescriptor<Snippet>(sortBy: [SortDescriptor(\.order), SortDescriptor(\.createdAt)])
        return (try? context.fetch(d)) ?? []
    }

    public func group(named name: String) -> SnippetGroup? {
        groups().first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: Seeding

    /// Creates the starter groups on first launch. Returns true when it seeded.
    @discardableResult
    public func seedDefaultsIfNeeded() -> Bool {
        guard groups().isEmpty, allSnippets().isEmpty else { return false }
        let personal = addGroup(name: "Personal", symbol: "person.crop.circle")
        _ = personal
        _ = addGroup(name: "Work", symbol: "briefcase")
        let templates = addGroup(name: "Templates", symbol: "text.bubble")
        addSnippet(title: "Thanks", value: "Thank you! I'll get back to you shortly.", keyword: "thx", to: templates)
        addSnippet(title: "Signature", value: "Best regards,\n{fullname}", keyword: "sig", to: templates)
        let dynamic = addGroup(name: "Dynamic", symbol: "wand.and.stars")
        addSnippet(title: "Today", value: "{date}", keyword: "today", to: dynamic)
        addSnippet(title: "Today (dd.MM.yyyy)", value: "{date:dd.MM.yyyy}", keyword: "dmy", to: dynamic)
        addSnippet(title: "Now", value: "{time}", keyword: "now", to: dynamic)
        addSnippet(title: "ISO timestamp", value: "{iso}", keyword: "iso", to: dynamic)
        addSnippet(title: "Unix timestamp", value: "{timestamp}", keyword: "ts", to: dynamic)
        addSnippet(title: "New UUID", value: "{uuid}", keyword: "uuid", to: dynamic)
        addSnippet(title: "Home folder", value: "{home}", keyword: "home", to: dynamic)
        save()
        return true
    }

    // MARK: Groups

    @discardableResult
    public func addGroup(name: String, symbol: String = "folder") -> SnippetGroup {
        let order = (groups().map(\.order).max() ?? -1) + 1
        let group = SnippetGroup(name: name, symbol: symbol, order: order)
        context.insert(group)
        save()
        return group
    }

    public func rename(_ group: SnippetGroup, to name: String, symbol: String? = nil) {
        group.name = name
        if let symbol { group.symbol = symbol }
        save()
    }

    public func delete(_ group: SnippetGroup) {
        context.delete(group)
        save()
    }

    // MARK: Snippets

    @discardableResult
    public func addSnippet(title: String, value: String, keyword: String = "", to group: SnippetGroup) -> Snippet {
        let order = (group.snippets.map(\.order).max() ?? -1) + 1
        let snippet = Snippet(title: title, value: value, keyword: keyword, order: order)
        context.insert(snippet)
        snippet.group = group
        save()
        return snippet
    }

    public func update(_ snippet: Snippet, title: String, value: String, keyword: String, group: SnippetGroup?) {
        snippet.title = title
        snippet.value = value
        snippet.keyword = keyword
        if let group, group.id != snippet.group?.id {
            snippet.group = group
            snippet.order = (group.snippets.map(\.order).max() ?? -1) + 1
        }
        save()
    }

    public func delete(_ snippet: Snippet) {
        context.delete(snippet)
        save()
    }

    public func markUsed(_ snippet: Snippet, now: Date = .now) {
        snippet.useCount += 1
        snippet.lastUsedAt = now
        save()
    }

    /// Moves a snippet one step up or down inside its group.
    public func move(_ snippet: Snippet, by offset: Int) {
        guard let group = snippet.group else { return }
        var list = group.sortedSnippets
        guard let index = list.firstIndex(where: { $0.id == snippet.id }) else { return }
        let target = max(0, min(list.count - 1, index + offset))
        guard target != index else { return }
        list.remove(at: index)
        list.insert(snippet, at: target)
        for (i, s) in list.enumerated() { s.order = i }
        save()
    }

    // MARK: Import / export

    public struct Archive: Codable, Equatable, Sendable {
        public struct Group: Codable, Equatable, Sendable {
            public var name: String
            public var symbol: String
            public var snippets: [Item]
        }
        public struct Item: Codable, Equatable, Sendable {
            public var title: String
            public var value: String
            public var keyword: String
        }
        public var version: Int = 1
        public var groups: [Group]
    }

    public func exportArchive() throws -> Data {
        let archive = Archive(groups: groups().map { g in
            Archive.Group(name: g.name, symbol: g.symbol, snippets: g.sortedSnippets.map {
                Archive.Item(title: $0.title, value: $0.value, keyword: $0.keyword)
            })
        })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(archive)
    }

    /// Merges an archive: groups are matched by name, identical snippets (same title and value) are skipped.
    /// Returns the number of snippets added.
    @discardableResult
    public func importArchive(_ data: Data) throws -> Int {
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        var added = 0
        for g in archive.groups {
            let group = self.group(named: g.name) ?? addGroup(name: g.name, symbol: g.symbol)
            for item in g.snippets where !group.snippets.contains(where: { $0.title == item.title && $0.value == item.value }) {
                addSnippet(title: item.title, value: item.value, keyword: item.keyword, to: group)
                added += 1
            }
        }
        return added
    }

    private func save() {
        do { try context.save() } catch { logger.error("Save failed: \(error.localizedDescription)") }
        onChange?()
    }
}
