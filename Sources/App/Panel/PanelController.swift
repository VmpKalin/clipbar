import AppKit
import SwiftUI

/// A borderless panel that can take keyboard focus without activating the app,
/// so the app the user was in stays frontmost (needed for pasting into it).
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Shows and hides the Liquid Glass panel under the menu bar icon.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    enum Position: String, CaseIterable, Identifiable {
        case statusItem, mouse, center
        var id: String { rawValue }
        var title: String {
            switch self {
            case .statusItem: "Under the menu bar icon"
            case .mouse: "At the mouse pointer"
            case .center: "Center of the screen"
            }
        }
    }

    enum Size: String, CaseIterable, Identifiable {
        case compact, regular, large
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var size: NSSize {
            switch self {
            case .compact: NSSize(width: 420, height: 520)
            case .regular: NSSize(width: 480, height: 620)
            case .large: NSSize(width: 580, height: 740)
            }
        }
    }

    let state = PanelState()
    private let model: AppModel
    private let panel: KeyPanel
    private weak var statusButton: NSStatusBarButton?
    private(set) var previousApp: NSRunningApplication?
    private var isClosing = false

    var isVisible: Bool { panel.isVisible }

    init(model: AppModel, statusButton: NSStatusBarButton?) {
        self.model = model
        self.statusButton = statusButton
        panel = KeyPanel(contentRect: NSRect(origin: .zero, size: Size.regular.size),
                         styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                         backing: .buffered, defer: true)
        super.init()
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.delegate = self

        let root = PanelRootView()
            .environment(model)
            .environment(state)
            .modelContainer(model.container)
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        panel.contentView = hosting
        model.panel = self
    }

    static var currentSize: Size {
        Size(rawValue: UserDefaults.standard.string(forKey: "panelSize") ?? "") ?? .regular
    }

    static var currentPosition: Position {
        Position(rawValue: UserDefaults.standard.string(forKey: "panelPosition") ?? "") ?? .statusItem
    }

    func toggle(fromHotKey: Bool = false) {
        if panel.isVisible { close() } else { show(fromHotKey: fromHotKey) }
    }

    func show(fromHotKey: Bool = false) {
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front
        model.capture.captureNow()
        state.prepareForOpen()

        let size = Self.currentSize.size
        let origin = origin(for: size, fromHotKey: fromHotKey)
        let final = NSRect(origin: origin, size: size)
        isClosing = false
        panel.setFrame(final.offsetBy(dx: 0, dy: 10), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(final, display: true)
        }
        statusButton?.highlight(true)
    }

    /// Hides the panel. `immediately` skips the fade so keyboard focus returns to the previous app
    /// at once (required before posting ⌘V).
    func close(immediately: Bool = false) {
        if immediately {
            guard panel.isVisible else { return }
            isClosing = false
            statusButton?.highlight(false)
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }
        guard panel.isVisible, !isClosing else { return }
        isClosing = true
        statusButton?.highlight(false)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isClosing else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
                self.isClosing = false
            }
        })
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    // MARK: Positioning

    private func origin(for size: NSSize, fromHotKey: Bool) -> NSPoint {
        var position = Self.currentPosition
        if !fromHotKey { position = .statusItem }

        switch position {
        case .statusItem:
            if let button = statusButton, let window = button.window {
                let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
                let screen = window.screen ?? NSScreen.main
                var x = rect.midX - size.width / 2
                if let visible = screen?.visibleFrame {
                    x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
                }
                return NSPoint(x: x, y: rect.minY - size.height - 6)
            }
            fallthrough
        case .center:
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            return NSPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2 + screen.height * 0.1)
        case .mouse:
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }?.visibleFrame
                ?? NSScreen.main?.visibleFrame ?? .zero
            var x = mouse.x - 24
            var y = mouse.y - size.height + 12
            x = min(max(x, screen.minX + 8), screen.maxX - size.width - 8)
            y = min(max(y, screen.minY + 8), screen.maxY - size.height - 8)
            return NSPoint(x: x, y: y)
        }
    }
}
