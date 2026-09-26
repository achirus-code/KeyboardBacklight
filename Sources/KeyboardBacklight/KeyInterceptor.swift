import AppKit
import ApplicationServices
import os

/// Globaler Event-Tap: fängt die zugewiesenen Tasten ab, bevor macOS sie verarbeitet
/// (z. B. „Nicht stören“ oder Musik zurück). Benötigt den Bedienungshilfen-Zugriff.
final class KeyInterceptor {
    struct Press {
        let trigger: KeyTrigger
        let isRepeat: Bool
        let flags: CGEventFlags
    }

    /// Liefert true, wenn die Taste verbraucht (nicht an macOS weitergereicht) werden soll.
    var onPress: ((Press) -> Bool)?
    /// Liefert true, wenn der zugehörige keyUp ebenfalls verschluckt werden soll.
    var isBound: ((KeyTrigger) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let log = Logger(subsystem: "de.achirus.keyboardbacklight", category: "keys")

    private static let systemDefined = CGEventType(rawValue: 14)!  // NSEvent.EventType.systemDefined

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << Self.systemDefined.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<KeyInterceptor>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("Event-Tap konnte nicht erstellt werden (Bedienungshilfen-Zugriff fehlt?)")
            return false
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Event-Tap aktiv")
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown, .keyUp:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let trigger = KeyTrigger.key(code)
            // Nur die Funktionsreihe protokollieren, keine normalen Tasten
            if type == .keyDown, code >= 96 {
                log.debug("keyDown \(code, privacy: .public)")
            }
            if type == .keyUp {
                return isBound?(trigger) == true ? nil : Unmanaged.passUnretained(event)
            }
            let press = Press(trigger: trigger,
                              isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                              flags: event.flags)
            return onPress?(press) == true ? nil : Unmanaged.passUnretained(event)

        case Self.systemDefined:
            guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else {
                return Unmanaged.passUnretained(event)
            }
            let data = ns.data1
            let code = (data & 0xFFFF_0000) >> 16
            let state = (data & 0xFF00) >> 8   // 0xA = gedrückt, 0xB = losgelassen
            let trigger = KeyTrigger.media(code)
            log.debug("media \(code, privacy: .public) state \(state, privacy: .public)")
            if state != 0xA {
                return isBound?(trigger) == true ? nil : Unmanaged.passUnretained(event)
            }
            let press = Press(trigger: trigger, isRepeat: data & 0x1 != 0, flags: event.flags)
            return onPress?(press) == true ? nil : Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
