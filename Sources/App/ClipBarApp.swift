import AppKit
import SwiftUI

@main
struct ClipBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(delegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var model: AppModel = {
        AppModel(inMemory: SnapshotRenderer.isRequested, startCapture: !SnapshotRenderer.isRequested)
    }()
    private var statusItem: NSStatusItem?
    private var panel: PanelController?
    private var hotKey: HotKey?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if SnapshotRenderer.isRequested {
            SnapshotRenderer.run(model: model)
            return
        }
        if CommandLine.arguments.contains("--register-login-item") {
            model.launchAtLogin = true
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = statusImage(paused: model.capture.isPaused)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "ClipBar"
        }
        statusItem = item
        panel = PanelController(model: model, statusButton: item.button)
        registerHotKey()
        observeCaptures()

        if CommandLine.arguments.contains("--open-panel") {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                self.panel?.show()
                if let button = self.statusItem?.button, let window = button.window {
                    FileHandle.standardError.write(Data("status item frame: \(window.convertToScreen(button.convert(button.bounds, to: nil))) visible: \(self.statusItem?.isVisible ?? false)\n".utf8))
                }
            }
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.defaultsChanged() }
        })
    }

    private var registeredPreset: HotKey.Preset?
    private var lastPaused: Bool?

    private func defaultsChanged() {
        if HotKey.Preset.current != registeredPreset { registerHotKey() }
        let paused = model.capture.isPaused
        if paused != lastPaused {
            lastPaused = paused
            statusItem?.button?.image = statusImage(paused: paused)
        }
    }

    private func registerHotKey() {
        hotKey?.unregister()
        let preset = HotKey.Preset.current
        registeredPreset = preset
        hotKey = HotKey(preset: preset) { [weak self] in
            self?.panel?.toggle(fromHotKey: true)
        }
    }

    /// Briefly shows a checkmark in the menu bar whenever something new is captured.
    private func observeCaptures() {
        withObservationTracking {
            _ = model.capture.captureCount
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.flashCapture()
                self?.observeCaptures()
            }
        }
    }

    private var flashTask: Task<Void, Never>?

    private func flashCapture() {
        guard UserDefaults.standard.object(forKey: "flashOnCapture") as? Bool ?? true,
              let button = statusItem?.button else { return }
        let check = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Captured")
        check?.isTemplate = true
        button.image = check
        flashTask?.cancel()
        flashTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self.statusItem?.button?.image = self.statusImage(paused: self.model.capture.isPaused)
        }
    }

    private func statusImage(paused: Bool) -> NSImage? {
        let name = paused ? "pause.circle" : "doc.on.clipboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "ClipBar")
        image?.isTemplate = true
        return image
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            panel?.toggle()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open ClipBar", action: #selector(openPanel), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let pause = NSMenuItem(title: model.capture.isPaused ? "Resume Capturing" : "Pause Capturing",
                               action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let quit = NSMenuItem(title: "Quit ClipBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPanel() { panel?.show() }

    @objc private func togglePause() {
        model.capture.isPaused.toggle()
    }

    @objc func openSettings() {
        panel?.close()
        NSApp.activate()
        SettingsOpener.open()
    }
}

/// Opens the SwiftUI Settings scene from AppKit code.
@MainActor
enum SettingsOpener {
    static var action: (() -> Void)?

    static func open() {
        NSApp.activate()
        if let action {
            action()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
