import AppKit
import SwiftUI

/// A small glass capsule shown near the top of the screen for feedback while the panel is hidden
/// (copies from the status menu, permission hints).
@MainActor
final class HUD {
    static let shared = HUD()

    private var window: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(_ message: String, systemImage: String, duration: Duration = .seconds(1.8)) {
        let view = Label(message, systemImage: systemImage)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(2)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .padding(10)
            .fixedSize()
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = window ?? makeWindow()
        panel.contentView = hosting
        let screen = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.maxY - size.height - 8,
                              width: size.width, height: size.height), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        window = panel

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated { panel.orderOut(nil) }
            })
        }
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}
