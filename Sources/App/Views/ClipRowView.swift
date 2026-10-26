import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    var shortcutIndex: Int?

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                primary
                secondary
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var leading: some View {
        switch item.kind {
        case .image:
            if let image = Image.fromData(item.thumbnailData) {
                image.resizable().scaledToFit()
                    .frame(maxWidth: 120, maxHeight: 72)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            } else {
                icon("photo")
            }
        case .link: icon("link")
        case .filePath: icon(isDirectory ? "folder.fill" : "doc.fill")
        case .text: icon((item.text ?? "").looksLikeCode ? "terminal" : "text.alignleft")
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var primary: some View {
        switch item.kind {
        case .text:
            Text(item.title)
                .font((item.text ?? "").looksLikeCode ? .system(.body, design: .monospaced) : .body)
                .lineLimit(2)
        default:
            Text(item.title).font(.body.weight(.medium)).lineLimit(1)
        }
    }

    @ViewBuilder
    private var secondary: some View {
        switch item.kind {
        case .link, .filePath:
            Text(item.text ?? "")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        case .image:
            Text(item.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
        case .text:
            EmptyView()
        }
    }

    private var trailing: some View {
        HStack(spacing: 6) {
            if item.isPinned { Image(systemName: "pin.fill").foregroundStyle(.orange) }
            if item.isSaved { Image(systemName: "bookmark.fill").foregroundStyle(.blue) }
            if item.useCount > 0 {
                Text("\(item.useCount)").font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            }
            #if os(macOS)
            if let n = shortcutIndex {
                Text("⌘\(n)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            #endif
        }
        .font(.caption)
    }

    private var isDirectory: Bool {
        guard let url = PathActions.resolvedURL(for: item) else { return (item.text ?? "").hasSuffix("/") }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

}
