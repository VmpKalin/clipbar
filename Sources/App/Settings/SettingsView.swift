import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            CaptureSettings()
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            LibrarySettings()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 470)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage(HotKey.Preset.defaultsKey) private var hotkey = HotKey.Preset.shiftCommandV.rawValue
    @AppStorage("panelPosition") private var position = PanelController.Position.statusItem.rawValue
    @AppStorage("panelSize") private var size = PanelController.Size.regular.rawValue
    @AppStorage("flashOnCapture") private var flashOnCapture = true
    @State private var trusted = Paster.isTrusted

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Open ClipBar") {
                Picker("Keyboard shortcut", selection: $hotkey) {
                    ForEach(HotKey.Preset.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Panel opens", selection: $position) {
                    ForEach(PanelController.Position.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Text("Clicking the menu bar icon always opens the panel under the icon.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("Panel size", selection: $size) {
                    ForEach(PanelController.Size.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
            Section("When you pick an item") {
                Picker("Return key", selection: $model.primaryDelivery) {
                    ForEach(AppModel.Delivery.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Option-Return") { Text(model.secondaryDelivery.title).foregroundStyle(.secondary) }
                HStack {
                    Image(systemName: trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Pasting into other apps is allowed." : "Pasting into other apps needs Accessibility permission.")
                    Spacer()
                    if !trusted {
                        Button("Allow…") {
                            Paster.requestTrust()
                            Paster.openAccessibilitySettings()
                        }
                    }
                }
                .font(.callout)
            }
            Section {
                Toggle("Launch ClipBar at login", isOn: $model.launchAtLogin)
                Toggle("Flash the menu bar icon when something is copied", isOn: $flashOnCapture)
            }
        }
        .formStyle(.grouped)
        .task {
            // Accessibility can be granted while this window is open.
            while !Task.isCancelled {
                trusted = Paster.isTrusted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

// MARK: - Clipboard

private struct CaptureSettings: View {
    @Environment(AppModel.self) private var model
    @AppStorage("historyLimit") private var historyLimit = 1000
    @AppStorage("secretLifetimeMinutes") private var secretMinutes = 10
    @AppStorage("historyMaxAgeDays") private var maxAgeDays = 0
    @State private var confirmClear = false

    var body: some View {
        @Bindable var capture = model.capture
        Form {
            Section("History") {
                Toggle("Pause capturing", isOn: $capture.isPaused)
                Picker("Keep", selection: $historyLimit) {
                    Text("200 items").tag(200)
                    Text("500 items").tag(500)
                    Text("1 000 items").tag(1000)
                    Text("5 000 items").tag(5000)
                    Text("Unlimited").tag(0)
                }
                .onChange(of: historyLimit) { _, limit in model.store.enforceLimit(limit) }
                Text("Pinned items never count toward the limit. Passwords and other concealed content are never stored.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Clear History…", role: .destructive) { confirmClear = true }
            }
            Section("Privacy") {
                Picker("Remove secrets after", selection: $secretMinutes) {
                    Text("1 minute").tag(1)
                    Text("10 minutes").tag(10)
                    Text("1 hour").tag(60)
                    Text("Never").tag(0)
                }
                Text("API keys, tokens and private keys are masked in the list and removed automatically unless pinned.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("Remove clips older than", selection: $maxAgeDays) {
                    Text("1 day").tag(1)
                    Text("1 week").tag(7)
                    Text("1 month").tag(30)
                    Text("3 months").tag(90)
                    Text("Never").tag(0)
                }
                .onChange(of: maxAgeDays) { _, _ in model.capture.runMaintenance() }
            }
            Section("Ignore these apps") {
                if capture.ignoredBundleIDs.isEmpty {
                    Text("No apps ignored.").foregroundStyle(.secondary)
                }
                ForEach(capture.ignoredBundleIDs, id: \.self) { id in
                    HStack(spacing: 8) {
                        if let icon = AppIcons.icon(for: id) {
                            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "app.dashed").frame(width: 18)
                        }
                        Text(appName(id))
                        Text(id).font(.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            capture.ignoredBundleIDs.removeAll { $0 == id }
                        } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                    }
                }
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "?") {
                            if let id = app.bundleIdentifier, !capture.ignoredBundleIDs.contains(id) {
                                capture.ignoredBundleIDs.append(id)
                            }
                        }
                    }
                }
                .fixedSize()
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear) {
            Button("Clear (keep pinned)", role: .destructive) { model.clearHistory() }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func appName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

// MARK: - Library

private struct LibrarySettings: View {
    @Environment(AppModel.self) private var model
    @State private var message: String?

    var body: some View {
        Form {
            Section("Dynamic tokens") {
                VStack(alignment: .leading, spacing: 4) {
                    tokenRow("{date}", "today, e.g. Oct 28, 2026")
                    tokenRow("{date:dd.MM.yyyy}", "today in any format")
                    tokenRow("{time}  {datetime}  {iso}  {timestamp}", "the current time")
                    tokenRow("{weekday}  {year}", "parts of the date")
                    tokenRow("{uuid}", "a fresh UUID every time")
                    tokenRow("{clipboard}", "what is on the clipboard now")
                    tokenRow("{user}  {fullname}  {hostname}  {home}", "about this Mac")
                }
                .font(.callout)
            }
            Section("Backup") {
                HStack {
                    Button("Export Library…", action: export)
                    Button("Import Library…", action: importArchive)
                    Spacer()
                }
                Button("Import My Card from Contacts") { Task { await model.importMyCard() } }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
    }

    private func tokenRow(_ token: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(token).font(.system(.callout, design: .monospaced))
            Spacer()
            Text(meaning).foregroundStyle(.secondary)
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ClipBar Library.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.library.exportArchive().write(to: url, options: .atomic)
            message = "Exported to \(url.lastPathComponent)."
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importArchive() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let added = try model.library.importArchive(Data(contentsOf: url))
            message = "Imported \(added) item\(added == 1 ? "" : "s")."
        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            Text("ClipBar").font(.title.bold())
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")")
                .foregroundStyle(.secondary)
            Text("Your clipboard history, library and contacts in the menu bar.")
                .foregroundStyle(.secondary)
            Button("Show Data Folder") { NSWorkspace.shared.open(Storage.containerURL) }
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
