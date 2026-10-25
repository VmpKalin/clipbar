import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

@main
struct ClipBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentClipsWidget()
        OpenClipBarControl()
    }
}

// MARK: - Control Center button

struct OpenClipBarIntent: AppIntent {
    static let title: LocalizedStringResource = "Open ClipBar"
    static let description = IntentDescription("Opens ClipBar and saves the current clipboard.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "clipbar://open")!))
    }
}

struct OpenClipBarControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aholoiad.clipbar.open") {
            ControlWidgetButton(action: OpenClipBarIntent()) {
                Label("ClipBar", systemImage: "doc.on.clipboard")
            }
        }
        .displayName("ClipBar")
        .description("Open ClipBar and save the clipboard.")
    }
}

// MARK: - Recent clips widget

struct ClipSnapshot: Identifiable {
    let id: UUID
    let title: String
    let kind: ClipKind
    let thumbnail: Data?
}

struct RecentEntry: TimelineEntry {
    let date: Date
    let clips: [ClipSnapshot]
}

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: .now, clips: [
            ClipSnapshot(id: UUID(), title: "https://apple.com", kind: .link, thumbnail: nil),
            ClipSnapshot(id: UUID(), title: "Meeting notes", kind: .text, thumbnail: nil),
            ClipSnapshot(id: UUID(), title: "~/Desktop/report.pdf", kind: .filePath, thumbnail: nil),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (RecentEntry) -> Void) {
        Task { @MainActor in completion(RecentEntry(date: .now, clips: Self.loadRecent())) }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<RecentEntry>) -> Void) {
        Task { @MainActor in
            completion(Timeline(entries: [RecentEntry(date: .now, clips: Self.loadRecent())], policy: .never))
        }
    }

    @MainActor
    static func loadRecent(limit: Int = 3) -> [ClipSnapshot] {
        guard let container = try? AppGroup.makeModelContainer() else { return [] }
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        let items = (try? container.mainContext.fetch(descriptor)) ?? []
        return items.map { ClipSnapshot(id: $0.id, title: $0.title, kind: $0.kind, thumbnail: $0.thumbnailData) }
    }
}

struct RecentClipsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.aholoiad.clipbar.recent", provider: RecentProvider()) { entry in
            RecentClipsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Clips")
        .description("Your latest clipboard items. Tap to open ClipBar and save the clipboard.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct RecentClipsView: View {
    let entry: RecentEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "doc.on.clipboard")
                    .font(.title2)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label("ClipBar", systemImage: "doc.on.clipboard").font(.headline)
                    if let first = entry.clips.first {
                        Text(first.title).font(.caption).lineLimit(2)
                    } else {
                        Text("Tap to save clipboard").font(.caption)
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("ClipBar", systemImage: "doc.on.clipboard").font(.headline)
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                    }
                    if entry.clips.isEmpty {
                        Text("Tap to save the clipboard").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(entry.clips.prefix(family == .systemSmall ? 2 : 3)) { clip in
                        HStack(spacing: 6) {
                            if clip.kind == .image, let data = clip.thumbnail, let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 18, height: 18).clipShape(.rect(cornerRadius: 4))
                            } else {
                                Image(systemName: icon(for: clip.kind)).font(.caption).foregroundStyle(.secondary)
                                    .frame(width: 18)
                            }
                            Text(clip.title).font(.caption).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .widgetURL(URL(string: "clipbar://open"))
    }

    private func icon(for kind: ClipKind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .filePath: "folder"
        }
    }
}
