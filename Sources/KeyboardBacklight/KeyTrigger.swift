import Foundation

/// Eine Taste, die eine Aktion auslöst. Die obere Tastenreihe liefert je nach Taste
/// und Einstellung „F1, F2 usw. als Standard-Funktionstasten“ unterschiedliche Events:
/// normale Tastencodes (z. B. F6, Mond-Taste) oder Media-Keys (z. B. Zurück ◀◀).
enum KeyTrigger: Codable, Hashable {
    /// Normales keyDown mit virtuellem Tastencode
    case key(Int64)
    /// Sondertaste (NSSystemDefined, Subtyp 8) mit NX_KEYTYPE_*-Code
    case media(Int)

    var label: String {
        switch self {
        case .key(let code):
            if let name = Self.keyNames[code] { return name }
            return "Taste \(code)"
        case .media(let code):
            if let name = Self.mediaNames[code] { return name }
            return "Sondertaste \(code)"
        }
    }

    private static let keyNames: [Int64: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15",
        176: "Diktat 🎙", 177: "Spotlight 🔍", 178: "Nicht stören 🌙",
    ]

    private static let mediaNames: [Int: String] = [
        0: "Lauter", 1: "Leiser", 2: "Bildschirm heller", 3: "Bildschirm dunkler",
        7: "Ton aus", 16: "Wiedergabe ▶︎⏸", 17: "Weiter ▶▶", 18: "Zurück ◀◀",
        19: "Vorspulen", 20: "Zurückspulen ◀◀", 21: "Tastatur heller", 22: "Tastatur dunkler",
    ]

    // Mond-Taste (F6) → dunkler, Zurück (F7) → heller – wie früher links dunkler, rechts heller.
    // Die Varianten decken beide Einstellungen der Funktionstasten ab.
    static let defaultDarker: [KeyTrigger] = [.key(178), .key(97)]
    static let defaultBrighter: [KeyTrigger] = [.media(18), .media(20), .key(98)]
}
