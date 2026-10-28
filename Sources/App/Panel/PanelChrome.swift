import SwiftData
import SwiftUI

// MARK: - Tabs

struct TabSwitcher: View {
    @Environment(PanelState.self) private var state
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PanelState.Tab.allCases) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        state.tab = tab
                        state.select(nil)
                    }
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                        .font(.system(size: 12, weight: state.tab == tab ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(state.tab == tab ? .primary : .secondary)
                        .background {
                            if state.tab == tab {
                                Capsule().fill(Color.primary.opacity(0.1))
                                    .matchedGeometryEffect(id: "tab", in: ns)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.05), in: .capsule)
    }
}

// MARK: - Filter chips

struct Chip: View {
    let title: String
    let systemImage: String
    var count: Int?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 10))
                Text(title)
                if let count, count > 0 {
                    Text("\(count)").monospacedDigit().foregroundStyle(selected ? .primary : .tertiary)
                }
            }
            .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 9)
            .padding(.vertical, 4.5)
            .background(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.055), in: .capsule)
            .overlay(Capsule().strokeBorder(selected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 0.5))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

struct FilterBar: View {
    let clips: [ClipItem]
    let groups: [SnippetGroup]
    @Environment(PanelState.self) private var state
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                switch state.tab {
                case .clipboard: clipChips
                case .library: libraryChips
                case .contacts: EmptyView()
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollClipDisabled()
        .frame(height: state.tab == .contacts ? 0 : 28)
        .opacity(state.tab == .contacts ? 0 : 1)
    }

    @ViewBuilder
    private var clipChips: some View {
        let counts = Dictionary(uniqueKeysWithValues: ClipSection.allCases.map { s in
            (s, s == .all ? clips.count : clips.count(where: { s.includes($0) }))
        })
        ForEach(ClipSection.allCases) { s in
            if s == .all || (counts[s] ?? 0) > 0 || state.clipSection == s {
                Chip(title: s.title, systemImage: s.systemImage, count: s == .all ? nil : counts[s],
                     selected: state.clipSection == s) {
                    withAnimation(.snappy(duration: 0.2)) {
                        state.clipSection = s
                        state.select(nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var libraryChips: some View {
        Chip(title: "All", systemImage: "square.grid.2x2", selected: state.libraryGroupID == nil) {
            state.libraryGroupID = nil
            state.select(nil)
        }
        ForEach(groups) { g in
            Chip(title: g.name, systemImage: g.symbol, count: g.snippets.count, selected: state.libraryGroupID == g.id) {
                state.libraryGroupID = g.id
                state.select(nil)
            }
            .contextMenu {
                Button("Edit Group…", systemImage: "pencil") {
                    state.editor = .group(.init(existingID: g.id, name: g.name, symbol: g.symbol))
                }
                Button("Delete Group and Its Items", systemImage: "trash", role: .destructive) {
                    if state.libraryGroupID == g.id { state.libraryGroupID = nil }
                    model.library.delete(g)
                }
            }
        }
        Button {
            state.editor = .group(.init())
        } label: {
            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .background(Color.primary.opacity(0.055), in: .capsule)
        }
        .buttonStyle(.plain)
        .help("New group")
    }
}

// MARK: - Footer

struct PanelFooter: View {
    let totalClips: Int
    @Environment(AppModel.self) private var model
    @Environment(PanelState.self) private var state
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.capture.isPaused.toggle()
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(model.capture.isPaused ? Color.orange : Color.green).frame(width: 7, height: 7)
                    Text(model.capture.isPaused ? "Paused" : "\(totalClips) clips")
                }
            }
            .buttonStyle(.plain)
            .help(model.capture.isPaused ? "Resume capturing" : "Pause capturing")

            Spacer()

            Text(hint).foregroundStyle(.tertiary).lineLimit(1)

            Spacer()

            if state.tab == .library {
                FooterIcon(systemImage: "plus", help: "New item  ⌘N") { PanelActions(model: model, state: state).newSnippet() }
            }
            FooterIcon(systemImage: state.showPreview ? "rectangle.bottomthird.inset.filled" : "rectangle",
                       help: "Toggle preview  ⌘I") {
                withAnimation(.snappy(duration: 0.2)) { state.showPreview.toggle() }
            }
            FooterIcon(systemImage: "gearshape", help: "Settings  ⌘,") {
                model.panel?.close()
                NSApp.activate()
                openSettings()
            }
            FooterIcon(systemImage: "power", help: "Quit ClipBar") { NSApp.terminate(nil) }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var hint: String {
        let primary = model.primaryDelivery == .copy ? "copy" : "paste"
        let secondary = model.primaryDelivery == .copy ? "paste" : "copy"
        return "↩ \(primary) · ⌥↩ \(secondary) · ⇥ tabs"
    }
}

struct FooterIcon: View {
    let systemImage: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .frame(width: 24, height: 22)
                .background(hovering ? Color.primary.opacity(0.09) : .clear, in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Toast

struct ToastView: View {
    let toast: AppModel.Toast

    var body: some View {
        Label(toast.message, systemImage: toast.systemImage)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

// MARK: - Empty states

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glass)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
