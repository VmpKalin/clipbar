import SwiftUI
import WidgetKit

@main
struct ClipBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "placeholder", provider: P()) { _ in Text("ClipBar") }
    }
}
struct E: TimelineEntry { let date: Date }
struct P: TimelineProvider {
    func placeholder(in context: Context) -> E { E(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (E) -> Void) { completion(E(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<E>) -> Void) { completion(Timeline(entries: [E(date: .now)], policy: .never)) }
}
