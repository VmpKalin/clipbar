import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var section: ClipSection = .all
    @State private var menuOpen = false
    @State private var showSettings = false
    @AppStorage("didOnboard") private var didOnboard = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            if sizeClass == .compact {
                drawerLayout
            } else {
                splitLayout
            }
            #else
            splitLayout
            #endif
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 360)
                #endif
        }
        #if os(iOS)
        .sheet(isPresented: Binding(get: { !didOnboard }, set: { didOnboard = !$0 })) {
            OnboardingView()
        }
        #endif
        .overlay(alignment: .bottom) { CopiedToast() }
        .overlay(alignment: .top) {
            if let warning = model.storageWarning {
                Text(warning)
                    .font(.footnote)
                    .padding(10)
                    .glassEffect(.regular.tint(.orange.opacity(0.4)), in: .capsule)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: iPad / macOS

    private var splitLayout: some View {
        NavigationSplitView {
            SideMenuView(selection: $section, showSettings: $showSettings, dismissMenu: nil)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                HistoryListView(section: section, menuButton: nil)
            }
        }
    }

    // MARK: iPhone drawer

    private var drawerLayout: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                HistoryListView(section: section, menuButton: { toggleMenu() })
            }
            .disabled(menuOpen)

            if menuOpen {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { toggleMenu() }
                    .transition(.opacity)
            }

            SideMenuView(selection: $section, showSettings: $showSettings, dismissMenu: { toggleMenu() })
                .frame(width: 290)
                .padding(.vertical, 12)
                .padding(.leading, 8)
                .offset(x: menuOpen ? 0 : -330)
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: menuOpen)
        .gesture(edgeSwipe)
    }

    private var edgeSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if !menuOpen, value.startLocation.x < 40, value.translation.width > 60 { toggleMenu() }
                if menuOpen, value.translation.width < -60 { toggleMenu() }
            }
    }

    private func toggleMenu() { menuOpen.toggle() }
}

/// Small glass capsule that confirms a copy.
struct CopiedToast: View {
    @Environment(AppModel.self) private var model
    @State private var visible = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if visible {
                Label("Copied \(model.lastCopiedTitle.prefix(28))", systemImage: "checkmark.circle.fill")
                    .lineLimit(1)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: visible)
        .onChange(of: model.copyCount) { _, _ in
            visible = true
            hideTask?.cancel()
            hideTask = Task {
                try? await Task.sleep(for: .seconds(1.4))
                if !Task.isCancelled { visible = false }
            }
        }
        #if os(iOS)
        .sensoryFeedback(.success, trigger: model.copyCount)
        #endif
    }
}
