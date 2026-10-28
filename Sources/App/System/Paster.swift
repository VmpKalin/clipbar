import AppKit
import ApplicationServices

/// Sends ⌘V to the frontmost app. Needs Accessibility permission.
@MainActor
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to Privacy & Security → Accessibility.
    static func requestTrust() {
        // The value of kAXTrustedCheckOptionPrompt; referenced literally to avoid a global var under Swift 6.
        let key = "AXTrustedCheckOptionPrompt"
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Re-activates `app` (if given) and pastes into it. Returns false when not permitted.
    @discardableResult
    static func paste(into app: NSRunningApplication?) -> Bool {
        guard isTrusted else { return false }
        if let app, !app.isActive {
            app.activate()
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(app?.isActive == false ? 180 : 60))
            postCommandV()
        }
        return true
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
