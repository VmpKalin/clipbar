#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

/// The compact Maccy-style panel shown under the menu bar icon.
struct MenuBarPanelView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var items: [ClipItem]
    @State private var section: ClipSection = .all
    @State private var search = ""
    @State private var hovered: UUID?
    @FocusState private var searchFocused: Bool

    private var visible: [ClipItem] { Array(section.apply(to: items, search: search).prefix(300)) }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            chips
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 400, height: 540)
        .background { shortcutButtons }
        .onAppear {
            model.capture.captureNow()
            search = ""
            searchFocused = true
        }
    }

    // MARK: Pieces

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clips", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { if let first = visible.first { copyAndClose(first) } }
                .onExitCommand { closePanel() }
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ClipSection.allCases) { s in
                    let count = items.count(where: { s.includes($0) })
                    Button {
                        section = s
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: s.systemImage)
                            Text(s.title)
                            if count > 0 {
                                Text("\(count)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(section == s ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
                                    in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .help(s.title)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var list: some View {
        if visible.isEmpty {
            ContentUnavailableView {
                Label(items.isEmpty ? "Nothing copied yet" : "No matches", systemImage: section.systemImage)
            } description: {
                Text(items.isEmpty ? "Copy something — ClipBar watches the clipboard." : "Try another search or section.")
            }
            .frame(maxHeight: .infinity)
        } else if section == .images {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(visible) { item in
                        ImageCell(item: item) { copyAndClose(item) }
                            .contextMenu { ClipContextMenu(item: item) }
                    }
                }
                .padding(10)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        PanelRow(item: item, shortcut: index < 9 ? index + 1 : nil, hovered: hovered == item.id)
                            .onHover { hovered = $0 ? item.id : (hovered == item.id ? nil : hovered) }
                            .onTapGesture { copyAndClose(item) }
                            .contextMenu { ClipContextMenu(item: item) }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                model.clearHistory()
            } label: { Label("Clear", systemImage: "trash") }
            .help("Clear history (keeps pinned and saved)")
            Spacer()
            Text("⌘1–9 copy · ↩ first · esc close")
                .font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            SettingsLink { Image(systemName: "gearshape") }
                .help("Settings")
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .help("Quit ClipBar")
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var shortcutButtons: some View {
        ForEach(Array(visible.prefix(9).enumerated()), id: \.element.id) { index, item in
            Button("") { copyAndClose(item) }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .hidden()
        }
    }

    // MARK: Actions

    private func copyAndClose(_ item: ClipItem) {
        model.copy(item)
        closePanel()
    }

    private func closePanel() {
        NSApp.keyWindow?.close()
    }
}

private struct PanelRow: View {
    let item: ClipItem
    let shortcut: Int?
    let hovered: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(item.kind == .text && item.title.looksLikeCode ? .system(.callout, design: .monospaced) : .callout)
                    .lineLimit(item.kind == .text ? 2 : 1)
                if item.kind == .link || item.kind == .filePath {
                    Text(item.text ?? "")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            HStack(spacing: 5) {
                if item.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
                if item.isSaved { Image(systemName: "bookmark.fill").foregroundStyle(.blue) }
                if let n = shortcut {
                    Text("⌘\(n)").monospacedDigit().foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(hovered ? Color.primary.opacity(0.07) : .clear, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
    }

    @ViewBuilder
    private var leading: some View {
        if item.kind == .image, let image = Image.fromData(item.thumbnailData) {
            image.resizable().scaledToFit()
                .frame(maxWidth: 96, maxHeight: 56)
                .clipShape(.rect(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        } else {
            Image(systemName: iconName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 22)
        }
    }

    private var iconName: String {
        switch item.kind {
        case .image: "photo"
        case .link: "link"
        case .filePath: "folder"
        case .text: item.title.looksLikeCode ? "terminal" : "text.alignleft"
        }
    }
}

private struct ImageCell: View {
    let item: ClipItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.primary.opacity(0.05)
                if let image = Image.fromData(item.thumbnailData) {
                    image.resizable().scaledToFit().padding(4)
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(alignment: .bottomLeading) {
                Text(item.title).font(.caption2)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.thinMaterial, in: .capsule)
                    .padding(5)
            }
        }
        .buttonStyle(.plain)
    }
}
#endif
