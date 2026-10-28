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
        let offline = SnapshotRenderer.isRequested || SelfTest.isRequested
        return AppModel(inMemory: offline, startCapture: !offline)
    }()
    private var statusItem: NSStatusItem?
    private var panel: PanelController?
    private var hotKey: HotKey?
    private var saveHotKey: HotKey?
    private var registeredSaveShortcut: SaveSelectionShortcut?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if SnapshotRenderer.isRequested {
            SnapshotRenderer.run(model: model)
            return
        }
        if SelfTest.isRequested {
            SelfTest.run()
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
        registerSaveHotKey()
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
        if SaveSelectionShortcut.current != registeredSaveShortcut { registerSaveHotKey() }
        let paused = model.capture.isPaused
        if paused != lastPaused {
            lastPaused = paused
            statusItem?.button?.image = statusImage(paused: paused)
        }
    }

    private func registerSaveHotKey() {
        saveHotKey?.unregister()
        saveHotKey = nil
        let shortcut = SaveSelectionShortcut.current
        registeredSaveShortcut = shortcut
        guard let code = shortcut.keyCode else { return }
        saveHotKey = HotKey(keyCode: code, modifiers: shortcut.modifiers) { [weak self] in
            self?.saveSelectionToLibrary()
        }
    }

    /// Copies the selection in the frontmost app and opens "Add to Library" with it.
    private func saveSelectionToLibrary() {
        let before = NSPasteboard.general.changeCount
        guard Paster.copySelection() else {
            Paster.requestTrust()
            panel?.show(fromHotKey: true)
            model.notify("Allow Accessibility so ClipBar can copy your selection", systemImage: "hand.raised")
            return
        }
        Task { @MainActor in
            for _ in 0..<10 where NSPasteboard.general.changeCount == before {
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard NSPasteboard.general.changeCount != before,
                  let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
                self.panel?.show(fromHotKey: true)
                self.model.notify("Select some text first", systemImage: "text.cursor")
                return
            }
            self.model.capture.captureNow()
            self.panel?.show(fromHotKey: true)
            let state = self.panel?.state
            let group = self.model.library.groups().first?.id
            let title = String(text.split(whereSeparator: \.isWhitespace).prefix(4).joined(separator: " ").prefix(40))
            state?.editor = .snippet(.init(title: title, value: text, groupID: group))
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
        func item(_ title: String, _ action: Selector, key: String = "", image: String? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.target = self
            if let image { i.image = NSImage(systemSymbolName: image, accessibilityDescription: nil) }
            return i
        }
        let open = item("Open ClipBar", #selector(openPanel), image: "doc.on.clipboard")
        open.keyEquivalent = HotKey.Preset.current.keyEquivalent
        open.keyEquivalentModifierMask = HotKey.Preset.current.modifierMask
        menu.addItem(open)
        menu.addItem(.separator())

        // Pinned clips, one click to copy.
        let pinned = model.store.allItems().filter(\.isPinned).prefix(12)
        if !pinned.isEmpty {
            menu.addItem(NSMenuItem.sectionHeader(title: "Pinned"))
            for clip in pinned {
                let i = item(String(clip.title.prefix(48)), #selector(copyClipFromMenu(_:)), image: "pin")
                i.representedObject = clip.id
                menu.addItem(i)
            }
            menu.addItem(.separator())
        }

        // Library groups as submenus.
        let groups = model.library.groups().filter { !$0.snippets.isEmpty }
        if !groups.isEmpty {
            menu.addItem(NSMenuItem.sectionHeader(title: "Library"))
            for group in groups {
                let sub = NSMenu()
                for snippet in group.sortedSnippets.prefix(30) {
                    let i = item(snippet.title, #selector(copySnippetFromMenu(_:)))
                    i.representedObject = snippet.id
                    i.toolTip = model.expanded(snippet)
                    sub.addItem(i)
                }
                let g = NSMenuItem(title: group.name, action: nil, keyEquivalent: "")
                g.image = NSImage(systemSymbolName: group.symbol, accessibilityDescription: nil)
                g.submenu = sub
                menu.addItem(g)
            }
            menu.addItem(.separator())
        }

        menu.addItem(item(model.capture.isPaused ? "Resume Capturing" : "Pause Capturing", #selector(togglePause),
                          image: model.capture.isPaused ? "play.circle" : "pause.circle"))
        menu.addItem(item("Settings…", #selector(openSettings), key: ",", image: "gearshape"))
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit ClipBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func copyClipFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let clip = model.store.allItems().first(where: { $0.id == id }) else { return }
        model.deliver(clip, as: .copy)
        model.notify("Copied “\(clip.title.prefix(30))”", systemImage: "checkmark.circle")
    }

    @objc private func copySnippetFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let snippet = model.library.allSnippets().first(where: { $0.id == id }) else { return }
        model.deliver(snippet, as: .copy)
        model.notify("Copied “\(snippet.title.prefix(30))”", systemImage: "checkmark.circle")
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
            return
        }
        // Before the panel has ever been shown, use the Settings item SwiftUI puts in the app menu.
        let items = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        if let item = items.first(where: { $0.keyEquivalent == "," && $0.keyEquivalentModifierMask == .command }),
           let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
