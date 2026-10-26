import SwiftUI
#if os(iOS)
import UIKit
#else
import ServiceManagement
#endif

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("historyLimit") private var historyLimit = 500
    @State private var confirmClear = false
    #if os(macOS)
    @State private var launchError: String?
    @State private var launchEnabled = SMAppService.mainApp.status == .enabled

    private var launchAtLogin: Binding<Bool> {
        Binding(get: { launchEnabled }, set: { on in
            do {
                if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                launchEnabled = on
                launchError = nil
            } catch {
                launchError = error.localizedDescription
            }
        })
    }
    #endif

    var body: some View {
        Form {
            Section("History") {
                Picker("Keep", selection: $historyLimit) {
                    Text("100 items").tag(100)
                    Text("500 items").tag(500)
                    Text("1 000 items").tag(1000)
                    Text("Unlimited").tag(0)
                }
                .onChange(of: historyLimit) { _, limit in model.store.enforceLimit(limit) }
                Text("Pinned and saved items never count toward the limit.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Clear History…", role: .destructive) { confirmClear = true }
            }

            #if os(iOS)
            Section("Capturing") {
                Text("iOS does not let apps read the clipboard in the background. ClipBar reads it every time you open the app — add the ClipBar control to Control Center or a widget to open it in one tap.")
                    .font(.footnote)
                Text("To stop the “Allow Paste?” prompt, set Paste from Other Apps to Allow in Settings.")
                    .font(.footnote)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open ClipBar Settings", destination: url)
                }
            }
            #else
            Section("Capturing") {
                Toggle("Launch at login", isOn: launchAtLogin)
                Text("ClipBar lives in the menu bar and watches the clipboard while it is running. Passwords and other concealed content are skipped.")
                    .font(.footnote)
                Text("Paths can be opened in Finder or Terminal from an item's context menu.")
                    .font(.footnote)
                if let error = launchError { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            #endif

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            #endif
        }
        .confirmationDialog("Clear history?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear (keep pinned & saved)", role: .destructive) { model.clearHistory() }
        } message: {
            Text("Pinned and saved items are kept.")
        }
    }
}
