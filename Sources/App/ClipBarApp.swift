import SwiftData
import SwiftUI

@main
struct ClipBarApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra {
            MenuBarPanelView()
                .environment(model)
                .modelContainer(model.container)
        } label: {
            Image(systemName: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(model)
                .modelContainer(model.container)
                .frame(width: 440)
        }
        #else
        WindowGroup {
            RootView()
                .environment(model)
                .modelContainer(model.container)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { model.capture.captureNow() }
                }
                .onOpenURL { _ in model.capture.captureNow() }
        }
        #endif
    }
}
