import SwiftData
import SwiftUI

struct HistoryListView: View {
    let section: ClipSection
    /// Shown on iPhone to open the drawer.
    var menuButton: (() -> Void)?

    @Environment(AppModel.self) private var model
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var items: [ClipItem]
    @State private var search = ""

    private var visible: [ClipItem] { section.apply(to: items, search: search) }

    var body: some View {
        Group {
            if visible.isEmpty {
                emptyState
            } else if section == .images {
                ImageGridView(items: visible)
            } else {
                list
            }
        }
        .navigationTitle(section.title)
        .searchable(text: $search, prompt: "Search")
        .toolbar {
            if let menuButton {
                ToolbarItem(placement: .navigation) {
                    Button(action: menuButton) { Image(systemName: "line.3.horizontal") }
                        .accessibilityLabel("Menu")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { model.capture.captureNow() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Capture clipboard")
            }
        }
        .background { shortcutButtons }
    }

    private var list: some View {
        List {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                ClipRowView(item: item, shortcutIndex: index < 9 ? index + 1 : nil)
                    .contentShape(.rect)
                    .onTapGesture { model.copy(item) }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button { model.togglePin(item) } label: {
                            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { model.delete(item) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu { ClipContextMenu(item: item) }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(section == .all ? "Nothing copied yet" : "No \(section.title.lowercased()) items",
                  systemImage: section.systemImage)
        } description: {
            #if os(iOS)
            Text("Copy something in any app, then open ClipBar — it is saved automatically.")
            #else
            Text("Copy something anywhere — ClipBar watches the clipboard.")
            #endif
        }
    }

    /// ⌘1…⌘9 copy the first nine visible items (macOS and iPad keyboards).
    private var shortcutButtons: some View {
        ForEach(Array(visible.prefix(9).enumerated()), id: \.element.id) { index, item in
            Button("") { model.copy(item) }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .hidden()
        }
    }
}

/// Context menu shared by rows and grid cells.
struct ClipContextMenu: View {
    let item: ClipItem
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.copy(item) } label: { Label("Copy", systemImage: "doc.on.doc") }
        Button { model.togglePin(item) } label: {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }
        Button { model.toggleSaved(item) } label: {
            Label(item.isSaved ? "Unsave" : "Save", systemImage: item.isSaved ? "bookmark.slash" : "bookmark")
        }
        if let url = PathActions.resolvedURL(for: item) {
            Divider()
            #if os(macOS)
            Button { PathActions.openInFinder(url) } label: { Label("Open in Finder", systemImage: "folder") }
            Button { PathActions.openInTerminal(url) } label: { Label("Open in Terminal", systemImage: "terminal") }
            #else
            if PathActions.filesAppURL(for: url) != nil {
                Button { PathActions.openInFiles(url) } label: { Label("Open in Files", systemImage: "folder") }
            }
            #endif
        }
        if item.kind == .link, let t = item.text, let url = URL(string: t) {
            Link(destination: url) { Label("Open Link", systemImage: "safari") }
        }
        shareLink
        Divider()
        Button(role: .destructive) { model.delete(item) } label: { Label("Delete", systemImage: "trash") }
    }

    @ViewBuilder
    private var shareLink: some View {
        if item.kind == .image, let data = model.imageData(for: item), let image = Image.fromData(data) {
            ShareLink(item: image, preview: SharePreview(item.title, image: image))
        } else if let text = item.text {
            ShareLink(item: text)
        }
    }
}
