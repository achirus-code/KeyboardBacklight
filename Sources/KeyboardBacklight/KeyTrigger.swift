import Foundation

/// A key that triggers an action. Depending on the key and on the setting "Use F1, F2, etc.
/// keys as standard function keys", the top row sends different events: regular key codes
/// (e.g. F5, Dictation) or media keys (e.g. Previous ◀◀).
enum KeyTrigger: Codable, Hashable {
    /// Regular keyDown with a virtual key code
    case key(Int64)
    /// Special key (NSSystemDefined, subtype 8) with an NX_KEYTYPE_* code
    case media(Int)

    var label: String {
        switch self {
        case .key(let code):
            if let name = Self.keyNames[code] { return String(localized: String.LocalizationValue(name)) }
            return String(localized: "Key \(code)")
        case .media(let code):
            if let name = Self.mediaNames[code] { return String(localized: String.LocalizationValue(name)) }
            return String(localized: "Special key \(code)")
        }
    }

    private static let keyNames: [Int64: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
        176: "Dictation 🎙", 177: "Spotlight 🔍", 178: "Do Not Disturb 🌙",
    ]

    private static let mediaNames: [Int: String] = [
        0: "Volume Up", 1: "Volume Down", 2: "Display Brighter", 3: "Display Darker",
        7: "Mute", 16: "Play/Pause ▶︎⏸", 17: "Next ▶▶", 18: "Previous ◀◀",
        19: "Fast Forward", 20: "Rewind ◀◀", 21: "Keyboard Brighter", 22: "Keyboard Darker",
    ]

    // F5 (Dictation) → darker, F6 (Do Not Disturb) → brighter – like the keyboard brightness
    // keys on older MacBooks. The variants cover both settings of the function keys.
    static let defaultDarker: [KeyTrigger] = [.key(176), .key(96)]
    static let defaultBrighter: [KeyTrigger] = [.key(178), .key(97)]
}
