import SwiftUI

struct ImageGridView: View {
    let items: [ClipItem]
    @Environment(AppModel.self) private var model
    @State private var preview: ClipItem?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    cell(item)
                }
            }
            .padding(12)
        }
        .sheet(item: $preview) { item in
            ImagePreviewView(item: item)
        }
    }

    private func cell(_ item: ClipItem) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = Image.fromData(item.thumbnailData) {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                Text(item.title)
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .glassEffect(.regular, in: .capsule)
                    .padding(6)
            }
            if item.isPinned {
                Image(systemName: "pin.fill").font(.caption).foregroundStyle(.white)
                    .padding(5).background(.orange, in: .circle).padding(6)
            }
        }
        .contentShape(.rect)
        .onTapGesture { model.copy(item) }
        .onLongPressGesture { preview = item }
        .contextMenu {
            Button { preview = item } label: { Label("Preview", systemImage: "eye") }
            ClipContextMenu(item: item)
        }
    }
}

struct ImagePreviewView: View {
    let item: ClipItem
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image = Image.fromData(model.imageData(for: item)) {
                    image.resizable().scaledToFit().padding()
                } else {
                    ContentUnavailableView("Image missing", systemImage: "photo")
                }
            }
            .navigationTitle(item.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { model.copy(item); dismiss() } label: { Label("Copy", systemImage: "doc.on.doc") }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 360)
        #endif
    }
}
