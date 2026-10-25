import SwiftData
import SwiftUI

@main
struct ClipBarApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    private var content: some View {
        let base = RootView()
            .environment(model)
            .modelContainer(model.container)
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { model.capture.captureNow() }
            }
            .onOpenURL { _ in model.capture.captureNow() }
        #if os(macOS)
        return base
            .onAppear { model.capture.startPolling() }
            .frame(minWidth: 560, minHeight: 420)
        #else
        return base
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            content
        }
        .defaultSize(width: 760, height: 560)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Capture Clipboard Now") { model.capture.captureNow() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        Settings {
            SettingsView()
                .environment(model)
                .modelContainer(model.container)
        }
        #else
        WindowGroup {
            content
        }
        #endif
    }
}
