import SwiftData
import SwiftUI

/// The whole menu bar panel.
struct PanelRootView: View {
    @Environment(AppModel.self) private var model
    @Environment(PanelState.self) private var state
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var clips: [ClipItem]
    @Query(sort: [SortDescriptor(\SnippetGroup.order), SortDescriptor(\SnippetGroup.createdAt)]) private var groups: [SnippetGroup]
    @Query(sort: [SortDescriptor(\Snippet.order), SortDescriptor(\Snippet.createdAt)]) private var snippets: [Snippet]
    @FocusState private var searchFocused: Bool
    @Environment(\.openSettings) private var openSettings

    @State private var cache = EntryCache()

    private var actions: PanelActions { PanelActions(model: model, state: state) }

    var body: some View {
        let key = EntryCache.Key(tab: state.tab, search: state.search, section: state.clipSection,
                                 group: state.libraryGroupID, data: model.dataVersion, clips: clips.count,
                                 snippets: snippets.count, groups: groups.count,
                                 contacts: model.contacts.cards.count, access: model.contacts.access == .granted)
        let (entries, order) = cache.value(for: key) {
            EntryBuilder(state: state, clips: clips, groups: groups, snippets: snippets, contacts: model.contacts).build()
        }
        let current = state.effectiveSelection(in: order)
        let selected = current.flatMap { c in entries.first { $0.selection == c } }

        ZStack {
            VStack(spacing: 0) {
                header(entries: entries, order: order, selected: selected)
                FilterBar(clips: clips, groups: groups)
                    .padding(.bottom, 6)
                Divider().opacity(0.5)
                list(entries: entries, order: order, current: current)
                if state.showPreview, let selected {
                    Divider().opacity(0.5)
                    PreviewPane(entry: selected, actions: actions, order: order)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Divider().opacity(0.5)
                PanelFooter(totalClips: clips.count)
            }
            .background { shortcutButtons(entries: entries, order: order, selected: selected) }
            .disabled(state.editor != nil)
            // Keys work wherever focus is inside the panel (e.g. after clicking preview text).
            .onKeyPress(keys: PanelRootView.navigationKeys, phases: .down) { press in
                handleKey(press, order: order, selected: selected)
            }

            if let editor = state.editor {
                EditorOverlay(editor: editor)
                    .id(editorID(editor))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.2), value: model.toast)
        .animation(.snappy(duration: 0.18), value: state.editor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .onChange(of: state.openCount) { _, _ in if state.editor == nil { searchFocused = true } }
        .onChange(of: state.editor) { _, editor in if editor == nil { searchFocused = true } }
        .onChange(of: state.tab) { _, tab in
            if tab == .contacts {
                model.contacts.refreshAccess()
                if model.contacts.access == .granted { model.contacts.reload() }
            }
        }
        .onAppear {
            searchFocused = true
            SettingsOpener.action = { openSettings() }
        }
    }

    // MARK: Header

    private func header(entries: [PanelEntry], order: [PanelState.Selection], selected: PanelEntry?) -> some View {
        @Bindable var state = state
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField(searchPrompt, text: $state.search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($searchFocused)
                    .onKeyPress(keys: PanelRootView.navigationKeys, phases: .down) { press in
                        handleKey(press, order: order, selected: selected)
                    }
                    .onChange(of: state.search) { _, _ in state.select(nil) }
                if !state.search.isEmpty {
                    Button { state.search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 12, style: .continuous))

            HStack {
                TabSwitcher()
                Spacer()
                if model.capture.isPaused {
                    Label("Paused", systemImage: "pause.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    static let navigationKeys: Set<KeyEquivalent> = [.upArrow, .downArrow, .pageUp, .pageDown, .return, .tab, .escape]

    private func handleKey(_ press: KeyPress, order: [PanelState.Selection], selected: PanelEntry?) -> KeyPress.Result {
        guard state.editor == nil else { return .ignored }
        switch press.key {
        case .upArrow: state.move(by: -1, in: order)
        case .downArrow: state.move(by: 1, in: order)
        case .pageUp: state.move(by: -8, in: order)
        case .pageDown: state.move(by: 8, in: order)
        case .return:
            guard let selected else { return .ignored }
            if press.modifiers.contains(.option) { actions.secondary(selected) } else { actions.primary(selected) }
        case .tab:
            withAnimation(.snappy(duration: 0.2)) { state.nextTab(press.modifiers.contains(.shift) ? -1 : 1) }
        case .escape:
            if !state.search.isEmpty {
                state.search = ""
                searchFocused = true
            } else {
                model.panel?.close()
            }
        default: return .ignored
        }
        return .handled
    }

    private var searchPrompt: String {
        switch state.tab {
        case .clipboard: "Search clipboard, library, contacts…"
        case .library: "Search library…"
        case .contacts: "Search contacts…"
        }
    }

    // MARK: List

    @ViewBuilder
    private func list(entries: [PanelEntry], order: [PanelState.Selection], current: PanelState.Selection?) -> some View {
        if entries.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(entries) { entry in
                            row(entry, order: order, isSelected: entry.selection != nil && entry.selection == current)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.automatic)
                .onChange(of: state.scrollTarget) { _, target in
                    guard let target, let entry = entries.first(where: { $0.selection == target }) else { return }
                    proxy.scrollTo(entry.id)
                }
                .onChange(of: state.openCount) { _, _ in
                    if let first = entries.first { proxy.scrollTo(first.id, anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: PanelEntry, order: [PanelState.Selection], isSelected: Bool) -> some View {
        Group {
            switch entry {
            case .header(_, let title, let symbol):
                SectionHeaderRow(title: title, systemImage: symbol)
            case .clip(let item, let shortcut):
                ClipRow(item: item, shortcut: shortcut, selected: isSelected)
            case .snippet(let s, let shortcut):
                SnippetRow(snippet: s, preview: model.expanded(s), shortcut: shortcut, selected: isSelected)
            case .contactHeader(let card):
                ContactHeaderRow(card: card)
            case .contactField(_, let field, let shortcut):
                ContactFieldRow(field: field, shortcut: shortcut, selected: isSelected)
            }
        }
        .onContinuousHover { phase in
            if case .active = phase, let sel = entry.selection { state.hoverSelect(sel) }
        }
        .onTapGesture {
            guard entry.selection != nil else { return }
            if NSEvent.modifierFlags.contains(.option) { actions.secondary(entry) } else { actions.primary(entry) }
        }
        .contextMenu {
            if entry.selection != nil {
                EntryMenu(entry: entry, actions: actions, order: order)
            }
        }
        .draggable(dragText(entry))
    }

    private func dragText(_ entry: PanelEntry) -> String {
        actions.text(of: entry) ?? ""
    }

    @ViewBuilder
    private var emptyState: some View {
        switch state.tab {
        case .clipboard:
            if !state.search.isEmpty {
                EmptyStateView(systemImage: "magnifyingglass", title: "No matches",
                               message: "Nothing in your history, Library or Contacts matches “\(state.search)”.\nTip: narrow down with app:safari, is:image, is:link, is:code, is:today.")
            } else if clips.isEmpty {
                EmptyStateView(systemImage: "doc.on.clipboard", title: "Nothing copied yet",
                               message: "Copy anything — text, links, files, images. ClipBar keeps it here. Open this panel any time with \(HotKey.Preset.current.title).")
            } else {
                EmptyStateView(systemImage: state.clipSection.systemImage, title: "No \(state.clipSection.title.lowercased())",
                               message: "Nothing in this section yet.")
            }
        case .library:
            if !state.search.isEmpty {
                EmptyStateView(systemImage: "magnifyingglass", title: "No matches", message: "No Library items match “\(state.search)”.")
            } else if let id = state.libraryGroupID, let group = groups.first(where: { $0.id == id }), group.name == "Personal" {
                EmptyStateView(systemImage: "person.crop.circle", title: "Your personal info",
                               message: "Keep your email, phone, address, IBAN or passport number here and paste them in one keystroke.",
                               actionTitle: "Import My Card from Contacts") {
                    Task { await model.importMyCard() }
                }
            } else {
                EmptyStateView(systemImage: "books.vertical", title: "Nothing here yet",
                               message: "Save anything you reuse: addresses, replies, IDs, templates. Press ⌘L on a clip or ⌘N for a new item.",
                               actionTitle: "New Item") { actions.newSnippet() }
            }
        case .contacts:
            switch model.contacts.access {
            case .granted:
                if model.contacts.isLoading {
                    ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyStateView(systemImage: "person.crop.circle.badge.questionmark", title: "No contacts found",
                                   message: state.search.isEmpty ? "Your Contacts app is empty." : "No contact matches “\(state.search)”.")
                }
            case .unknown:
                EmptyStateView(systemImage: "person.crop.circle", title: "Your contacts, one keystroke away",
                               message: "Search people and copy a phone, email or address instantly. ClipBar reads Contacts locally and never uploads anything.",
                               actionTitle: "Allow Access to Contacts") {
                    Task { await model.contacts.requestAccess() }
                }
            case .denied:
                EmptyStateView(systemImage: "person.crop.circle.badge.xmark", title: "No access to Contacts",
                               message: "Turn on ClipBar in System Settings → Privacy & Security → Contacts.",
                               actionTitle: "Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    // MARK: Keyboard shortcuts

    private func shortcutButtons(entries: [PanelEntry], order: [PanelState.Selection], selected: PanelEntry?) -> some View {
        Group {
            ForEach(1...9, id: \.self) { n in
                Button("") {
                    if let e = entries.first(where: { shortcutNumber($0) == n }) { actions.primary(e) }
                }
                .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
            }
            Button("") { if let selected, actions.canPin(selected) { actions.togglePin(selected) } }
                .keyboardShortcut("p", modifiers: .command)
            Button("") { if let selected, actions.canAddToLibrary(selected) { actions.addToLibrary(selected) } }
                .keyboardShortcut("l", modifiers: .command)
            Button("") { if let selected, actions.canEdit(selected) { actions.edit(selected) } }
                .keyboardShortcut("e", modifiers: .command)
            Button("") { if let selected, actions.canDelete(selected) { actions.delete(selected, order: order) } }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!state.search.isEmpty)
            Button("") { if let selected, actions.canOpen(selected) { actions.open(selected) } }
                .keyboardShortcut("o", modifiers: .command)
            Button("") { if let selected, actions.isExistingPath(selected) { actions.reveal(selected) } }
                .keyboardShortcut("r", modifiers: .command)
            Button("") { if let selected, actions.isExistingPath(selected) { actions.terminal(selected) } }
                .keyboardShortcut("t", modifiers: .command)
            Button("") { withAnimation(.snappy(duration: 0.2)) { state.showPreview.toggle() } }
                .keyboardShortcut("i", modifiers: .command)
            Button("") { actions.newSnippet() }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
            Button("") { SettingsOpener.open(); model.panel?.close() }
                .keyboardShortcut(",", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .disabled(state.editor != nil)
        .allowsHitTesting(false)
    }

    private func shortcutNumber(_ entry: PanelEntry) -> Int? {
        switch entry {
        case .clip(_, let n), .snippet(_, let n), .contactField(_, _, let n): n
        default: nil
        }
    }

    private func editorID(_ editor: PanelState.Editor) -> String {
        switch editor {
        case .snippet(let d): "s-\(d.existingID?.uuidString ?? "new")-\(d.value.hashValue)"
        case .clip(let id, _): "c-\(id)"
        case .group(let d): "g-\(d.existingID?.uuidString ?? "new")"
        }
    }
}

/// Remembers the last built rows so hovering and moving the selection don't rebuild the list.
@MainActor
final class EntryCache {
    struct Key: Equatable {
        let tab: PanelState.Tab
        let search: String
        let section: ClipSection
        let group: UUID?
        let data: Int
        let clips: Int
        let snippets: Int
        let groups: Int
        let contacts: Int
        let access: Bool
    }

    private var key: Key?
    private var entries: [PanelEntry] = []
    private var order: [PanelState.Selection] = []

    func value(for key: Key, build: () -> [PanelEntry]) -> ([PanelEntry], [PanelState.Selection]) {
        if key != self.key {
            entries = build()
            order = entries.compactMap(\.selection)
            self.key = key
        }
        return (entries, order)
    }
}
