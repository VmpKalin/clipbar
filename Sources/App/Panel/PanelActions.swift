import AppKit
import SwiftUI

/// Everything a row can do, shared by keyboard shortcuts, context menus and the preview pane.
@MainActor
struct PanelActions {
    let model: AppModel
    let state: PanelState

    // MARK: Delivery

    func primary(_ entry: PanelEntry) { deliver(entry, as: model.primaryDelivery) }
    func secondary(_ entry: PanelEntry) { deliver(entry, as: model.secondaryDelivery) }

    func deliver(_ entry: PanelEntry, as delivery: AppModel.Delivery, transform: TextTransform? = nil) {
        switch entry {
        case .clip(let item, _): model.deliver(item, as: delivery, transform: transform)
        case .snippet(let s, _): model.deliver(s, as: delivery, transform: transform)
        case .contactField(_, let f, _): model.deliver(text: f.value, title: f.value, as: delivery, transform: transform)
        case .header, .contactHeader: break
        }
    }

    /// Text the entry would produce (for transforms and previews).
    func text(of entry: PanelEntry) -> String? {
        switch entry {
        case .clip(let item, _): item.kind == .image ? nil : item.text
        case .snippet(let s, _): model.expanded(s)
        case .contactField(_, let f, _): f.value
        default: nil
        }
    }

    // MARK: Capabilities

    func canPin(_ e: PanelEntry) -> Bool { if case .clip = e { true } else { false } }
    func canDelete(_ e: PanelEntry) -> Bool {
        switch e { case .clip, .snippet: true; default: false }
    }
    func canEdit(_ e: PanelEntry) -> Bool {
        switch e {
        case .clip(let item, _): item.kind != .image
        case .snippet: true
        default: false
        }
    }
    func canAddToLibrary(_ e: PanelEntry) -> Bool {
        switch e {
        case .clip(let item, _): item.kind != .image
        case .contactField: true
        default: false
        }
    }
    func canOpen(_ e: PanelEntry) -> Bool {
        guard case .clip(let item, _) = e else {
            if case .contactField(_, let f, _) = e { return f.kind == .url || f.kind == .email || f.kind == .phone }
            return false
        }
        switch item.kind {
        case .link, .image: return true
        case .filePath: return !PathActions.resolvedURLs(for: item).isEmpty
        case .text: return false
        }
    }
    func isExistingPath(_ e: PanelEntry) -> Bool {
        guard case .clip(let item, _) = e else { return false }
        return !PathActions.resolvedURLs(for: item).isEmpty
    }
    func isImage(_ e: PanelEntry) -> Bool {
        guard case .clip(let item, _) = e else { return false }
        return item.kind == .image
    }
    func transforms(for e: PanelEntry) -> [TextTransform] {
        guard let text = text(of: e), text.utf8.count < 20_000 else { return [] }
        return TextTransform.allCases.filter { $0.apply(text) != nil }
    }

    // MARK: Actions

    func togglePin(_ e: PanelEntry) {
        if case .clip(let item, _) = e { model.togglePin(item) }
    }

    func delete(_ e: PanelEntry, order: [PanelState.Selection]) {
        // Select the neighbour first so the list doesn't jump to the top.
        if let sel = e.selection, let i = order.firstIndex(of: sel) {
            let next = order.indices.contains(i + 1) ? order[i + 1] : (i > 0 ? order[i - 1] : nil)
            state.select(next)
        }
        switch e {
        case .clip(let item, _): model.delete(item)
        case .snippet(let s, _): model.library.delete(s)
        default: break
        }
    }

    func edit(_ e: PanelEntry) {
        switch e {
        case .clip(let item, _):
            state.editor = .clip(id: item.id, text: item.text ?? "")
        case .snippet(let s, _):
            state.editor = .snippet(.init(existingID: s.id, title: s.title, value: s.value, keyword: s.keyword,
                                          groupID: s.group?.id))
        default: break
        }
    }

    func addToLibrary(_ e: PanelEntry) {
        let value: String
        var title = ""
        switch e {
        case .clip(let item, _):
            value = item.text ?? ""
            title = suggestedTitle(for: item)
        case .contactField(let card, let f, _):
            value = f.value
            title = "\(card.name) – \(f.label.isEmpty ? f.kind.rawValue : f.label)"
        default: return
        }
        let group = state.libraryGroupID ?? model.library.groups().first?.id
        state.editor = .snippet(.init(title: title, value: value, groupID: group))
    }

    func newSnippet() {
        let group = state.libraryGroupID ?? model.library.groups().first?.id
        state.editor = .snippet(.init(groupID: group))
    }

    func open(_ e: PanelEntry) {
        switch e {
        case .clip(let item, _): model.open(item)
        case .contactField(_, let f, _):
            let url: URL? = switch f.kind {
            case .email: URL(string: "mailto:\(f.value)")
            case .phone: URL(string: "tel:\(f.value.filter { $0.isNumber || $0 == "+" })")
            case .url: URL(string: f.value.contains("://") ? f.value : "https://\(f.value)")
            default: nil
            }
            if let url { NSWorkspace.shared.open(url); model.panel?.close() }
        default: break
        }
    }

    func reveal(_ e: PanelEntry) { if case .clip(let item, _) = e { model.revealInFinder(item) } }
    func terminal(_ e: PanelEntry) { if case .clip(let item, _) = e { model.openInTerminal(item) } }
    func recognizeText(_ e: PanelEntry) { if case .clip(let item, _) = e { model.copyTextFromImage(item) } }
    func saveImage(_ e: PanelEntry) { if case .clip(let item, _) = e { model.saveImageToDownloads(item) } }
    func removeBackground(_ e: PanelEntry) { if case .clip(let item, _) = e { model.removeBackground(item) } }
    func scanCodes(_ e: PanelEntry) { if case .clip(let item, _) = e { model.scanCodes(item) } }
    func copyAsDataURL(_ e: PanelEntry) { if case .clip(let item, _) = e { model.copyAsDataURL(item) } }

    func canMakeQRCode(_ e: PanelEntry) -> Bool {
        guard let text = text(of: e) else { return false }
        return !text.isEmpty && text.utf8.count <= 2000
    }

    func makeQRCode(_ e: PanelEntry) {
        guard let text = text(of: e) else { return }
        if case .clip(let item, _) = e { model.makeQRCode(text: text, from: item) } else { model.makeQRCode(text: text, from: nil) }
    }

    private func suggestedTitle(for item: ClipItem) -> String {
        let tags = item.tags
        if tags.contains(.email) { return "Email" }
        if tags.contains(.phone) { return "Phone" }
        if tags.contains(.color) { return "Color \(item.text ?? "")" }
        switch item.kind {
        case .link: return item.title
        case .filePath: return PathResolver.displayName(for: item.text ?? "")
        default:
            let words = (item.text ?? "").split(whereSeparator: { $0.isWhitespace }).prefix(4).joined(separator: " ")
            return String(words.prefix(40))
        }
    }
}

/// Context menu for a row.
struct EntryMenu: View {
    let entry: PanelEntry
    let actions: PanelActions
    let order: [PanelState.Selection]

    var body: some View {
        Button("Copy", systemImage: "doc.on.doc") { actions.deliver(entry, as: .copy) }
        Button("Paste", systemImage: "arrow.down.doc") { actions.deliver(entry, as: .paste) }
        TransformMenu(entry: entry, actions: actions)
        Divider()
        if actions.canPin(entry), case .clip(let item, _) = entry {
            Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin") {
                actions.togglePin(entry)
            }
        }
        if actions.canAddToLibrary(entry) {
            Button("Add to Library…", systemImage: "books.vertical") { actions.addToLibrary(entry) }
        }
        if actions.canEdit(entry) {
            Button("Edit…", systemImage: "pencil") { actions.edit(entry) }
        }
        if actions.isImage(entry) {
            Button("Copy Text from Image", systemImage: "text.viewfinder") { actions.recognizeText(entry) }
            Button("Scan QR Code / Barcode", systemImage: "qrcode.viewfinder") { actions.scanCodes(entry) }
            Button("Remove Background", systemImage: "person.and.background.dotted") { actions.removeBackground(entry) }
            Button("Copy as Data URL", systemImage: "chevron.left.forwardslash.chevron.right") { actions.copyAsDataURL(entry) }
            Button("Save to Downloads", systemImage: "square.and.arrow.down") { actions.saveImage(entry) }
        }
        if actions.canMakeQRCode(entry) {
            Button("Make QR Code", systemImage: "qrcode") { actions.makeQRCode(entry) }
        }
        if actions.canOpen(entry) {
            Button("Open", systemImage: "arrow.up.forward.app") { actions.open(entry) }
        }
        if actions.isExistingPath(entry) {
            Button("Show in Finder", systemImage: "folder") { actions.reveal(entry) }
            Button("Open in Terminal", systemImage: "terminal") { actions.terminal(entry) }
        }
        if actions.canDelete(entry) {
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { actions.delete(entry, order: order) }
        }
    }
}

struct TransformMenu: View {
    let entry: PanelEntry
    let actions: PanelActions

    var body: some View {
        let available = actions.transforms(for: entry)
        if !available.isEmpty {
            Menu {
                ForEach(available) { t in
                    Button(t.title) { actions.deliver(entry, as: actions.model.primaryDelivery, transform: t) }
                }
            } label: {
                Label("Transform & \(actions.model.primaryDelivery == .copy ? "Copy" : "Paste")",
                      systemImage: "wand.and.rays")
            }
        }
    }
}
