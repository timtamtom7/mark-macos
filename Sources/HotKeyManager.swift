import AppKit
import Carbon

// MARK: - Hotkey Action

enum HotkeyAction: String, CaseIterable, Codable {
    case toggleOverlay = "toggle_overlay"
    case clearAnnotations = "clear_annotations"
    case undo = "undo"
    case redo = "redo"
    case captureScreen = "capture_screen"
    case selectArrow = "select_arrow"
    case selectRectangle = "select_rectangle"
    case selectText = "select_text"
    case selectFreehand = "select_freehand"
    case selectHighlighter = "select_highlighter"

    var defaultKeyCode: UInt32 {
        switch self {
        case .toggleOverlay: return 3        // T
        case .clearAnnotations: return 14  // K
        case .undo: return 6                // Z
        case .redo: return 8               // Z (Shift+Z via modifier)
        case .captureScreen: return 1       // S
        case .selectArrow: return 18        // 1
        case .selectRectangle: return 19    // 2
        case .selectText: return 20        // 3
        case .selectFreehand: return 21    // 4
        case .selectHighlighter: return 22  // 5
        }
    }

    var defaultModifiers: UInt32 {
        switch self {
        case .redo: return UInt32(cmdKey | shiftKey)
        default: return UInt32(cmdKey)
        }
    }

    var displayName: String {
        switch self {
        case .toggleOverlay: return "Toggle Overlay"
        case .clearAnnotations: return "Clear Annotations"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .captureScreen: return "Capture Screen"
        case .selectArrow: return "Arrow Tool"
        case .selectRectangle: return "Rectangle Tool"
        case .selectText: return "Text Tool"
        case .selectFreehand: return "Freehand Tool"
        case .selectHighlighter: return "Highlighter Tool"
        }
    }
}

// MARK: - Hotkey Binding

struct HotkeyBinding: Codable, Equatable {
    var action: HotkeyAction
    var keyCode: UInt32
    var modifiers: UInt32  // Carbon modifiers

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
            21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K",
            41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
            36: "Return", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyMap[keyCode] ?? "?"
    }
}

// MARK: - HotKey Manager

class HotKeyManager {
    static let shared = HotKeyManager()

    private var bindings: [HotkeyAction: HotkeyBinding] = [:]
    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [EventHotKeyRef?] = []
    private var callback: ((HotkeyAction) -> Void)?

    private let bindingsKey = "hotkeyBindings"

    init() {
        loadBindings()
    }

    func setCallback(_ callback: @escaping (HotkeyAction) -> Void) {
        self.callback = callback
    }

    func start() {
        registerAllBindings()
    }

    func stop() {
        unregisterAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    func loadBindings() {
        if let data = UserDefaults.standard.data(forKey: bindingsKey),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            for binding in decoded {
                bindings[binding.action] = binding
            }
        }

        // Fill in defaults for any missing
        for action in HotkeyAction.allCases {
            if bindings[action] == nil {
                bindings[action] = HotkeyBinding(
                    action: action,
                    keyCode: action.defaultKeyCode,
                    modifiers: action.defaultModifiers
                )
            }
        }
        saveBindings()
    }

    func saveBindings() {
        let bindingsList = Array(bindings.values)
        if let data = try? JSONEncoder().encode(bindingsList) {
            UserDefaults.standard.set(data, forKey: bindingsKey)
        }
    }

    func updateBinding(action: HotkeyAction, keyCode: UInt32, modifiers: UInt32) {
        bindings[action] = HotkeyBinding(action: action, keyCode: keyCode, modifiers: modifiers)
        saveBindings()
        // Re-register this hotkey
        registerBinding(action: action)
    }

    func getBinding(for action: HotkeyAction) -> HotkeyBinding? {
        return bindings[action]
    }

    func getAllBindings() -> [HotkeyBinding] {
        return Array(bindings.values)
    }

    // MARK: - Carbon Registration

    private func registerAllBindings() {
        unregisterAll()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            if status == noErr {
                for (action, binding) in manager.bindings {
                    let id = HotKeyIDManager.shared.getID(for: action)
                    if hotkeyID.id == id {
                        DispatchQueue.main.async {
                            manager.callback?(action)
                        }
                        break
                    }
                }
            }
            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            userData,
            &eventHandler
        )

        for action in HotkeyAction.allCases {
            registerBinding(action: action)
        }
    }

    private func registerBinding(action: HotkeyAction) {
        guard let binding = bindings[action] else { return }

        var hotkeyID = EventHotKeyID()
        hotkeyID.signature = OSType(0x4D4B5F5F)  // "MK__"
        hotkeyID.id = HotKeyIDManager.shared.getID(for: action)
        
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            registeredHotkeys.append(hotkeyRef)
        }
    }

    private func unregisterAll() {
        for ref in registeredHotkeys {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        registeredHotkeys.removeAll()
    }
}

// MARK: - HotKey ID Manager (singleton for ID mapping)

class HotKeyIDManager {
    static let shared = HotKeyIDManager()

    private var nextID: UInt32 = 1
    private var idMap: [HotkeyAction: UInt32] = [:]

    private init() {}

    func getID(for action: HotkeyAction) -> UInt32 {
        if let id = idMap[action] { return id }
        let id = nextID
        nextID += 1
        idMap[action] = id
        return id
    }
}

// MARK: - Modifier helpers

func carbonModifiersFrom(_ nsFlags: NSEvent.ModifierFlags) -> UInt32 {
    var mods: UInt32 = 0
    if nsFlags.contains(.command) { mods |= UInt32(cmdKey) }
    if nsFlags.contains(.shift) { mods |= UInt32(shiftKey) }
    if nsFlags.contains(.option) { mods |= UInt32(optionKey) }
    if nsFlags.contains(.control) { mods |= UInt32(controlKey) }
    return mods
}
