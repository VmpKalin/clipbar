import SwiftData
import SwiftUI

/// Inline editor shown over the panel (a sheet would make the panel lose key focus and close).
struct EditorOverlay: View {
    let editor: PanelState.Editor
    @Environment(AppModel.self) private var model
    @Environment(PanelState.self) private var state
    @Query(sort: [SortDescriptor(\SnippetGroup.order), SortDescriptor(\SnippetGroup.createdAt)]) private var groups: [SnippetGroup]

    @State private var snippet = PanelState.SnippetDraft()
    @State private var group = PanelState.GroupDraft()
    @State private var clipText = ""
    @FocusState private var focus: Field?

    enum Field { case title, value, keyword, name, clip }

    static let symbols = ["folder", "person.crop.circle", "briefcase", "house", "creditcard", "building.columns",
                          "text.bubble", "envelope", "phone", "key", "link", "terminal", "wand.and.stars",
                          "star", "heart", "cart", "airplane", "graduationcap", "stethoscope", "car"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .onTapGesture { cancel() }
            VStack(alignment: .leading, spacing: 12) {
                Text(heading).font(.system(size: 15, weight: .semibold))
                form
                HStack {
                    if case .snippet(let d) = editor, d.existingID == nil {
                        Text("Tokens: {date} {time} {uuid} {clipboard} {date:dd.MM.yyyy}")
                            .font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    Spacer()
                    Button("Cancel") { cancel() }
                        .keyboardShortcut(.cancelAction)
                    Button("Save") { save() }
                        .keyboardShortcut("s", modifiers: .command)
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 6)
            .padding(16)
        }
        .onAppear(perform: load)
        .onKeyPress(.escape) { cancel(); return .handled }
    }

    private var heading: String {
        switch editor {
        case .snippet(let d): d.existingID == nil ? "Add to Library" : "Edit Library Item"
        case .clip: "Edit Clip"
        case .group(let d): d.existingID == nil ? "New Group" : "Edit Group"
        }
    }

    @ViewBuilder
    private var form: some View {
        switch editor {
        case .snippet:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Title", text: $snippet.title)
                        .focused($focus, equals: .title)
                    TextField("Keyword", text: $snippet.keyword)
                        .focused($focus, equals: .keyword)
                        .frame(width: 110)
                        .help("Optional short word to find this item instantly, e.g. “@mail”")
                }
                .textFieldStyle(.roundedBorder)
                TextEditor(text: $snippet.value)
                    .font(.system(size: 12.5))
                    .focused($focus, equals: .value)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
                    .frame(minHeight: 90, maxHeight: 200)
                Picker("Group", selection: $snippet.groupID) {
                    ForEach(groups) { g in
                        Label(g.name, systemImage: g.symbol).tag(Optional(g.id))
                    }
                }
                .pickerStyle(.menu)
            }
        case .clip:
            TextEditor(text: $clipText)
                .font(.system(size: 12.5, design: .monospaced))
                .focused($focus, equals: .clip)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
                .frame(minHeight: 140, maxHeight: 280)
        case .group:
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: $group.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($focus, equals: .name)
                    .onSubmit(save)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 10), spacing: 6) {
                    ForEach(Self.symbols, id: \.self) { symbol in
                        Button { group.symbol = symbol } label: {
                            Image(systemName: symbol)
                                .frame(width: 28, height: 28)
                                .background(group.symbol == symbol ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05),
                                            in: .rect(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        switch editor {
        case .snippet: !snippet.value.isEmpty && snippet.groupID != nil
        case .clip: !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .group: !group.name.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func load() {
        switch editor {
        case .snippet(let d):
            snippet = d
            if snippet.groupID == nil { snippet.groupID = groups.first?.id }
            focus = d.title.isEmpty ? .title : .value
        case .clip(_, let text):
            clipText = text
            focus = .clip
        case .group(let d):
            group = d
            focus = .name
        }
    }

    private func cancel() { state.editor = nil }

    private func save() {
        guard canSave else { return }
        switch editor {
        case .snippet:
            let title = snippet.title.trimmingCharacters(in: .whitespaces).isEmpty
                ? String(snippet.value.prefix(30)) : snippet.title
            let target = groups.first { $0.id == snippet.groupID }
            if let id = snippet.existingID, let existing = model.library.allSnippets().first(where: { $0.id == id }) {
                model.library.update(existing, title: title, value: snippet.value, keyword: snippet.keyword, group: target)
                state.select(.snippet(existing.id))
            } else if let target {
                let new = model.addToLibrary(title: title, value: snippet.value, keyword: snippet.keyword, group: target)
                if state.tab == .library { state.select(.snippet(new.id)) }
            }
        case .clip(let id, _):
            if let item = model.store.allItems().first(where: { $0.id == id }) {
                model.updateText(item, to: clipText)
            }
        case .group:
            let name = group.name.trimmingCharacters(in: .whitespaces)
            if let id = group.existingID, let existing = model.library.groups().first(where: { $0.id == id }) {
                model.library.rename(existing, to: name, symbol: group.symbol)
            } else {
                let new = model.library.addGroup(name: name, symbol: group.symbol)
                state.libraryGroupID = new.id
            }
        }
        state.editor = nil
    }
}
