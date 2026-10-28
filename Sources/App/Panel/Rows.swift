import AppKit
import SwiftUI

// MARK: - Shared bits

enum RelativeTime {
    static func short(_ date: Date, now: Date = .now) -> String {
        let s = now.timeIntervalSince(date)
        switch s {
        case ..<45: return "now"
        case ..<3600: return "\(Int(s / 60))m"
        case ..<86_400: return "\(Int(s / 3600))h"
        case ..<(86_400 * 7): return "\(Int(s / 86_400))d"
        default: return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

extension Image {
    static func fromData(_ data: Data?) -> Image? {
        guard let data, let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
    }
}

extension Color {
    init?(clipText: String) {
        guard let c = ContentInspector.color(in: clipText) else { return nil }
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

/// Rounded square icon tile used at the start of rows.
struct IconTile: View {
    let systemImage: String
    var tint: Color = .secondary
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: .rect(cornerRadius: size * 0.28))
    }
}

struct ShortcutBadge: View {
    let number: Int
    var body: some View {
        Text("⌘\(number)")
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .foregroundStyle(.tertiary)
    }
}

/// Selection / hover background shared by all rows.
struct RowChrome: ViewModifier {
    let selected: Bool
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.accentColor.opacity(0.2))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.5))
                }
            }
            .contentShape(.rect(cornerRadius: 11))
    }
}

// MARK: - Clip row

struct ClipRow: View {
    let item: ClipItem
    let shortcut: Int?
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ClipLeading(item: item)
            VStack(alignment: .leading, spacing: 2) {
                primary
                subtitle
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                if item.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.orange)
                }
                if let shortcut { ShortcutBadge(number: shortcut) }
            }
        }
        .modifier(RowChrome(selected: selected))
    }

    @ViewBuilder
    private var primary: some View {
        let isCode = item.tags.contains(.code)
        Text(item.title)
            .font(isCode ? .system(size: 12, design: .monospaced) : .system(size: 13))
            .lineLimit(item.kind == .text ? 2 : 1)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
    }

    private var subtitle: some View {
        HStack(spacing: 5) {
            if let icon = AppIcons.icon(for: item.sourceAppBundleID) {
                Image(nsImage: icon).resizable().frame(width: 12, height: 12)
            }
            Text(detail)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 10.5))
        .foregroundStyle(.secondary)
    }

    private var detail: String {
        var parts: [String] = []
        switch item.kind {
        case .link: if let t = item.text { parts.append(t) }
        case .filePath: if let t = item.text { parts.append(PathResolver.paths(in: t).first ?? t) }
        default: if let name = item.sourceAppName { parts.append(name) }
        }
        parts.append(RelativeTime.short(item.createdAt))
        if item.useCount > 0 { parts.append("used \(item.useCount)×") }
        return parts.joined(separator: " · ")
    }
}

struct ClipLeading: View {
    let item: ClipItem

    var body: some View {
        switch item.kind {
        case .image:
            if let image = Image.fromData(item.thumbnailData) {
                image.resizable().scaledToFill()
                    .frame(width: 40, height: 30)
                    .clipShape(.rect(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.15)))
            } else {
                IconTile(systemImage: "photo", tint: .purple)
            }
        case .link:
            IconTile(systemImage: "globe", tint: .blue)
        case .filePath:
            if let url = PathActions.resolvedURLs(for: item).first {
                Image(nsImage: AppIcons.icon(forFile: url)).resizable().frame(width: 28, height: 28)
            } else {
                IconTile(systemImage: "questionmark.folder", tint: .gray)
            }
        case .text:
            let tags = item.tags
            if tags.contains(.color), let text = item.text, let color = Color(clipText: text) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.primary.opacity(0.15)))
            } else if tags.contains(.email) {
                IconTile(systemImage: "envelope", tint: .teal)
            } else if tags.contains(.phone) {
                IconTile(systemImage: "phone", tint: .green)
            } else if tags.contains(.json) {
                IconTile(systemImage: "curlybraces", tint: .orange)
            } else if tags.contains(.code) {
                IconTile(systemImage: "terminal", tint: .indigo)
            } else if tags.contains(.number) {
                IconTile(systemImage: "number", tint: .mint)
            } else {
                IconTile(systemImage: "text.alignleft", tint: .secondary)
            }
        }
    }
}

// MARK: - Snippet row

struct SnippetRow: View {
    let snippet: Snippet
    let preview: String
    let shortcut: Int?
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            IconTile(systemImage: snippet.isDynamic ? "wand.and.stars" : (snippet.group?.symbol ?? "text.quote"),
                     tint: snippet.isDynamic ? .pink : .purple)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snippet.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if !snippet.keyword.isEmpty {
                        Text(snippet.keyword)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(preview.replacingOccurrences(of: "\n", with: " ⏎ "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let shortcut { ShortcutBadge(number: shortcut) }
        }
        .modifier(RowChrome(selected: selected))
    }
}

// MARK: - Contacts

struct ContactAvatar: View {
    let card: ContactCard
    var size: CGFloat = 26

    var body: some View {
        Group {
            if let image = Image.fromData(card.thumbnail) {
                image.resizable().scaledToFill()
            } else {
                LinearGradient(colors: [.gray.opacity(0.55), .gray.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                    .overlay(Text(card.initials).font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(.white))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
    }
}

struct ContactHeaderRow: View {
    let card: ContactCard

    var body: some View {
        HStack(spacing: 9) {
            ContactAvatar(card: card)
            VStack(alignment: .leading, spacing: 0) {
                Text(card.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if !card.organization.isEmpty, card.organization != card.name {
                    Text(card.organization).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

struct ContactFieldRow: View {
    let field: ContactCard.Field
    let shortcut: Int?
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: field.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(field.value.replacingOccurrences(of: "\n", with: ", "))
                .font(.system(size: 12.5))
                .lineLimit(1)
                .truncationMode(.middle)
            if !field.label.isEmpty {
                Text(field.label).font(.system(size: 10.5)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if let shortcut { ShortcutBadge(number: shortcut) }
        }
        .modifier(RowChrome(selected: selected))
    }
}

struct SectionHeaderRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(title.uppercased())
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .tracking(0.6)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
