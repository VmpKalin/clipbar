import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut registered with Carbon (works without Accessibility permission).
@MainActor
final class HotKey {
    enum Preset: String, CaseIterable, Identifiable {
        case shiftCommandV, optionCommandV, controlCommandV, optionSpace, controlOptionCommandC

        var id: String { rawValue }

        var title: String {
            switch self {
            case .shiftCommandV: "⇧⌘V"
            case .optionCommandV: "⌥⌘V"
            case .controlCommandV: "⌃⌘V"
            case .optionSpace: "⌥Space"
            case .controlOptionCommandC: "⌃⌥⌘C"
            }
        }

        var keyCode: UInt32 {
            switch self {
            case .shiftCommandV, .optionCommandV, .controlCommandV: UInt32(kVK_ANSI_V)
            case .optionSpace: UInt32(kVK_Space)
            case .controlOptionCommandC: UInt32(kVK_ANSI_C)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .shiftCommandV: UInt32(cmdKey | shiftKey)
            case .optionCommandV: UInt32(cmdKey | optionKey)
            case .controlCommandV: UInt32(cmdKey | controlKey)
            case .optionSpace: UInt32(optionKey)
            case .controlOptionCommandC: UInt32(cmdKey | optionKey | controlKey)
            }
        }

        static let defaultsKey = "hotkeyPreset"
        static var current: Preset {
            Preset(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .shiftCommandV
        }
    }

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        id = Self.nextID
        Self.nextID += 1
        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_4250), id: id) // 'CLBP'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        self.ref = ref
        Self.handlers[id] = handler
    }

    convenience init?(preset: Preset, handler: @escaping () -> Void) {
        self.init(keyCode: preset.keyCode, modifiers: preset.modifiers, handler: handler)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        Self.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            let id = hotKeyID.id
            MainActor.assumeIsolated {
                HotKey.handlers[id]?()
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
