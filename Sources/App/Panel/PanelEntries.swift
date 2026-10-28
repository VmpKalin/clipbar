import Foundation

/// One row in the panel list.
enum PanelEntry: Identifiable {
    case header(id: String, title: String, systemImage: String)
    case clip(ClipItem, shortcut: Int?)
    case snippet(Snippet, shortcut: Int?)
    case contactHeader(ContactCard)
    case contactField(ContactCard, ContactCard.Field, shortcut: Int?)

    var id: String {
        switch self {
        case .header(let id, _, _): "h-\(id)"
        case .clip(let c, _): "c-\(c.id)"
        case .snippet(let s, _): "s-\(s.id)"
        case .contactHeader(let card): "ch-\(card.id)"
        case .contactField(_, let f, _): "cf-\(f.id)"
        }
    }

    var selection: PanelState.Selection? {
        switch self {
        case .header, .contactHeader: nil
        case .clip(let c, _): .clip(c.id)
        case .snippet(let s, _): .snippet(s.id)
        case .contactField(_, let f, _): .contactField(f.id)
        }
    }
}

/// Builds the list for the current tab, filters and search.
@MainActor
struct EntryBuilder {
    let state: PanelState
    let clips: [ClipItem]
    let groups: [SnippetGroup]
    let snippets: [Snippet]
    let contacts: ContactsProvider

    static let historyLimit = 400

    func build() -> [PanelEntry] {
        var raw: [PanelEntry]
        switch state.tab {
        case .clipboard: raw = clipboardEntries()
        case .library: raw = libraryEntries()
        case .contacts: raw = contactEntries()
        }
        return numbered(raw)
    }

    // MARK: Tabs

    private func clipboardEntries() -> [PanelEntry] {
        let query = state.search.trimmingCharacters(in: .whitespaces)
        let history = state.clipSection.apply(to: clips, search: query).prefix(Self.historyLimit)
        guard !query.isEmpty, state.clipSection == .all else {
            return history.map { .clip($0, shortcut: nil) }
        }

        // Quick search across everything: Library and Contacts first, then history.
        var entries: [PanelEntry] = []
        let lib = matchingSnippets(query).prefix(4)
        if !lib.isEmpty {
            entries.append(.header(id: "lib", title: "Library", systemImage: "books.vertical"))
            entries += lib.map { .snippet($0, shortcut: nil) }
        }
        if contacts.access == .granted {
            let people = contacts.search(query, limit: 3)
            if !people.isEmpty {
                entries.append(.header(id: "contacts", title: "Contacts", systemImage: "person.crop.circle"))
                for card in people {
                    entries.append(.contactHeader(card))
                    entries += card.fields.prefix(4).map { .contactField(card, $0, shortcut: nil) }
                }
            }
        }
        if !entries.isEmpty, !history.isEmpty {
            entries.append(.header(id: "history", title: "History", systemImage: "clock.arrow.circlepath"))
        }
        entries += history.map { .clip($0, shortcut: nil) }
        return entries
    }

    private func libraryEntries() -> [PanelEntry] {
        let query = state.search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let found = matchingSnippets(query).filter { s in
                state.libraryGroupID == nil || s.group?.id == state.libraryGroupID
            }
            return found.map { .snippet($0, shortcut: nil) }
        }
        let shown = state.libraryGroupID.map { id in groups.filter { $0.id == id } } ?? groups
        var entries: [PanelEntry] = []
        for group in shown {
            let items = group.sortedSnippets
            if state.libraryGroupID == nil {
                guard !items.isEmpty else { continue }
                entries.append(.header(id: group.id.uuidString, title: group.name, systemImage: group.symbol))
            }
            entries += items.map { .snippet($0, shortcut: nil) }
        }
        return entries
    }

    private func contactEntries() -> [PanelEntry] {
        guard contacts.access == .granted else { return [] }
        var entries: [PanelEntry] = []
        for card in contacts.search(state.search, limit: 150) where !card.fields.isEmpty {
            entries.append(.contactHeader(card))
            entries += card.fields.map { .contactField(card, $0, shortcut: nil) }
        }
        return entries
    }

    // MARK: Helpers

    private func matchingSnippets(_ query: String) -> [Snippet] {
        snippets.compactMap { s -> (Snippet, Int)? in
            let keywordHit = !s.keyword.isEmpty && s.keyword.localizedCaseInsensitiveCompare(query) == .orderedSame
            if keywordHit { return (s, 2000) }
            return SearchMatcher.score(query, fields: [s.title, s.value, s.keyword, s.group?.name]).map { (s, $0) }
        }
        .sorted { a, b in a.1 != b.1 ? a.1 > b.1 : a.0.useCount > b.0.useCount }
        .map(\.0)
    }

    /// Adds ⌘1…⌘9 shortcuts to the first nine selectable rows.
    private func numbered(_ entries: [PanelEntry]) -> [PanelEntry] {
        var n = 0
        return entries.map { entry in
            guard entry.selection != nil, n < 9 else { return entry }
            n += 1
            switch entry {
            case .clip(let c, _): return .clip(c, shortcut: n)
            case .snippet(let s, _): return .snippet(s, shortcut: n)
            case .contactField(let card, let f, _): return .contactField(card, f, shortcut: n)
            default: return entry
            }
        }
    }
}
