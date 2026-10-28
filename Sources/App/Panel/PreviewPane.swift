import AppKit
import SwiftUI

/// Details of the selected row plus its most useful actions.
struct PreviewPane: View {
    let entry: PanelEntry
    let actions: PanelActions
    let order: [PanelState.Selection]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            actionBar
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(height: height)
        .background(Color.primary.opacity(0.035))
    }

    /// Short text gets a shorter pane so the list keeps more room.
    private var height: CGFloat {
        switch entry {
        case .clip(let item, _):
            switch item.kind {
            case .image, .filePath: return 178
            default:
                if let t = item.text, ContentInspector.color(in: t) != nil { return 150 }
                return lineCount(item.text) > 2 ? 178 : 118
            }
        case .snippet(let s, _): return lineCount(s.value) > 2 ? 160 : 118
        case .contactField: return 118
        default: return 118
        }
    }

    private func lineCount(_ text: String?) -> Int {
        guard let text else { return 0 }
        let explicit = text.split(separator: "\n", omittingEmptySubsequences: false).count
        return max(explicit, text.count / 60 + 1)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .clip(let item, _): ClipPreview(item: item, imageURL: actions.model.imageURL(for: item))
        case .snippet(let s, _):
            VStack(alignment: .leading, spacing: 6) {
                ScrollView {
                    Text(actions.model.expanded(s))
                        .font(.system(size: 12.5))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 6) {
                    if let g = s.group { Label(g.name, systemImage: g.symbol) }
                    if s.isDynamic { Label("Template: \(s.value)", systemImage: "wand.and.stars").lineLimit(1) }
                    if s.useCount > 0 { Text("· used \(s.useCount)×") }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            }
        case .contactField(let card, let field, _):
            HStack(alignment: .top, spacing: 12) {
                ContactAvatar(card: card, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name).font(.system(size: 14, weight: .semibold))
                    Label(field.label.isEmpty ? field.kind.rawValue : field.label, systemImage: field.systemImage)
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(field.value).font(.system(size: 13)).textSelection(.enabled)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: Actions

    private var actionBar: some View {
        HStack(spacing: 2) {
            ActionButton(title: "Copy", systemImage: "doc.on.doc", shortcut: actions.model.primaryDelivery == .copy ? "↩" : "⌥↩") {
                actions.deliver(entry, as: .copy)
            }
            ActionButton(title: "Paste", systemImage: "arrow.down.doc", shortcut: actions.model.primaryDelivery == .paste ? "↩" : "⌥↩") {
                actions.deliver(entry, as: .paste)
            }
            let transforms = actions.transforms(for: entry)
            if !transforms.isEmpty {
                Menu {
                    ForEach(transforms) { t in
                        Button(t.title, systemImage: t.systemImage) {
                            actions.deliver(entry, as: actions.model.primaryDelivery, transform: t)
                        }
                    }
                } label: {
                    Image(systemName: "wand.and.rays")
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .menuIndicator(.hidden)
                .frame(width: 30, height: 26)
                .help("Transform text before \(actions.model.primaryDelivery == .copy ? "copying" : "pasting")")
            }
            Divider().frame(height: 16).padding(.horizontal, 4)
            if actions.canPin(entry), case .clip(let item, _) = entry {
                ActionButton(title: item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin", shortcut: "⌘P") {
                    actions.togglePin(entry)
                }
            }
            if actions.canAddToLibrary(entry) {
                ActionButton(title: "Add to Library", systemImage: "books.vertical", shortcut: "⌘L") { actions.addToLibrary(entry) }
            }
            if actions.canEdit(entry) {
                ActionButton(title: "Edit", systemImage: "pencil", shortcut: "⌘E") { actions.edit(entry) }
            }
            if actions.isImage(entry) {
                ActionButton(title: "Copy Text from Image", systemImage: "text.viewfinder", shortcut: nil) { actions.recognizeText(entry) }
                ActionButton(title: "Save to Downloads", systemImage: "square.and.arrow.down", shortcut: nil) { actions.saveImage(entry) }
            }
            if actions.canOpen(entry) {
                ActionButton(title: "Open", systemImage: "arrow.up.forward.app", shortcut: "⌘O") { actions.open(entry) }
            }
            if actions.isExistingPath(entry) {
                ActionButton(title: "Show in Finder", systemImage: "folder", shortcut: "⌘R") { actions.reveal(entry) }
                ActionButton(title: "Open in Terminal", systemImage: "terminal", shortcut: "⌘T") { actions.terminal(entry) }
            }
            Spacer()
            if actions.canDelete(entry) {
                ActionButton(title: "Delete", systemImage: "trash", shortcut: "⌘⌫", tint: .red) {
                    actions.delete(entry, order: order)
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    let shortcut: String?
    var tint: Color = .primary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(tint.opacity(hovering ? 1 : 0.75))
                .frame(width: 30, height: 26)
                .background(hovering ? Color.primary.opacity(0.09) : .clear, in: .rect(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(shortcut.map { "\(title)  \($0)" } ?? title)
        .accessibilityLabel(title)
    }
}

/// The content part of the preview for a history clip.
struct ClipPreview: View {
    let item: ClipItem
    let imageURL: URL?
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            main
            meta
        }
    }

    @ViewBuilder
    private var main: some View {
        switch item.kind {
        case .image:
            HStack {
                Spacer()
                if let url = imageURL, let ns = PreviewImageCache.image(at: url) {
                    Image(nsImage: ns).resizable().scaledToFit()
                        .clipShape(.rect(cornerRadius: 8, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                } else if let thumb = Image.fromData(item.thumbnailData) {
                    thumb.resizable().scaledToFit()
                }
                Spacer()
            }
            .frame(maxHeight: .infinity)
        case .filePath:
            let paths = PathResolver.paths(in: item.text ?? "")
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(paths.prefix(30).enumerated()), id: \.offset) { _, path in
                        let url = PathResolver.resolve(path)
                        HStack(spacing: 6) {
                            if let url {
                                Image(nsImage: AppIcons.icon(forFile: url)).resizable().frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).frame(width: 16)
                            }
                            Text(path).font(.system(size: 11.5, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            if item.isSecret, let text = item.text {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Looks like a secret key or token", systemImage: "key.fill")
                        .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.red)
                    Text(revealed ? text : ContentInspector.masked(text))
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(4)
                    HStack {
                        Button(revealed ? "Hide" : "Reveal") { revealed.toggle() }
                            .buttonStyle(.glass).controlSize(.small)
                        Text(secretFootnote).font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                }
            } else if let text = item.text, let color = Color(clipText: text) {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color)
                        .frame(width: 88, height: 88)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text).font(.system(size: 15, weight: .semibold, design: .monospaced)).textSelection(.enabled)
                        if let c = ContentInspector.color(in: text) {
                            Text("rgb(\(Int(c.r * 255)), \(Int(c.g * 255)), \(Int(c.b * 255)))")
                                .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                ScrollView {
                    Text(String((item.text ?? "").prefix(8000)))
                        .font(item.tags.contains(.code) ? .system(size: 11.5, design: .monospaced) : .system(size: 12.5))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var secretFootnote: String {
        let minutes = UserDefaults.standard.object(forKey: "secretLifetimeMinutes") as? Int ?? 10
        if item.isPinned || minutes == 0 { return "Kept until you delete it." }
        let left = max(0, Int(item.createdAt.addingTimeInterval(Double(minutes) * 60).timeIntervalSinceNow / 60))
        return "Removed automatically in \(left) min. Pin to keep."
    }

    private var meta: some View {
        HStack(spacing: 6) {
            if let icon = AppIcons.icon(for: item.sourceAppBundleID) {
                Image(nsImage: icon).resizable().frame(width: 13, height: 13)
            }
            Text(metaText).lineLimit(1)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }

    private var metaText: String {
        var parts: [String] = []
        if let app = item.sourceAppName { parts.append(app) }
        parts.append(item.createdAt.formatted(date: .abbreviated, time: .shortened))
        switch item.kind {
        case .image:
            parts.append("\(item.imageWidth)×\(item.imageHeight) px")
            if let url = imageURL, let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            }
        case .filePath:
            let n = PathResolver.paths(in: item.text ?? "").count
            if n > 1 { parts.append("\(n) items") }
        default:
            let s = ContentInspector.stats(for: item.text ?? "")
            parts.append("\(s.characters) chars")
            if s.words > 1 { parts.append("\(s.words) words") }
            if s.lines > 1 { parts.append("\(s.lines) lines") }
        }
        if item.useCount > 0 { parts.append("used \(item.useCount)×") }
        return parts.joined(separator: " · ")
    }
}

/// Keeps a few decoded full-size images so moving the selection stays smooth.
@MainActor
enum PreviewImageCache {
    private static let cache: NSCache<NSURL, NSImage> = {
        let c = NSCache<NSURL, NSImage>()
        c.countLimit = 12
        return c
    }()

    static func image(at url: URL) -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
