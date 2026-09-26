import Foundation

/// Access to the keyboard backlight through the private CoreBrightness framework
/// (`KeyboardBrightnessClient`) – the same interface macOS itself uses.
final class Backlight {
    private let client: NSObject?
    private var keyboardID: UInt64 = 0

    private typealias CopyIDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
    private typealias GetFloat = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias GetBool = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias SetFloat = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private typealias SetBool = @convention(c) (AnyObject, Selector, Bool, UInt64) -> Bool

    init() {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let cls = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else {
            client = nil
            return
        }
        client = cls.init()

        // Prefer the built-in keyboard, otherwise the first one with a backlight
        let ids = (call("copyKeyboardBacklightIDs", as: CopyIDs.self)?(client!, sel("copyKeyboardBacklightIDs"))?
            .takeRetainedValue() as? [NSNumber] ?? []).map(\.uint64Value)
        let isBuiltIn = call("isKeyboardBuiltIn:", as: GetBool.self)
        keyboardID = ids.first { isBuiltIn?(client!, sel("isKeyboardBuiltIn:"), $0) == true } ?? ids.first ?? 0
    }

    var isAvailable: Bool { client != nil && keyboardID != 0 }

    /// Brightness 0…1
    var brightness: Float {
        get { getFloat("brightnessForKeyboard:") }
        set {
            guard let f = call("setBrightness:forKeyboard:", as: SetFloat.self) else { return }
            _ = f(client!, sel("setBrightness:forKeyboard:"), max(0, min(1, newValue)), keyboardID)
        }
    }

    /// "Adjust keyboard brightness in low light". In bright ambient light the automatic adjustment
    /// keeps the backlight off – manual values only take effect once it is turned off.
    var autoBrightness: Bool {
        get { getBool("isAutoBrightnessEnabledForKeyboard:") }
        set {
            guard let f = call("enableAutoBrightness:forKeyboard:", as: SetBool.self) else { return }
            _ = f(client!, sel("enableAutoBrightness:forKeyboard:"), newValue, keyboardID)
        }
    }

    // MARK: - Objective-C calls

    private func sel(_ name: String) -> Selector { NSSelectorFromString(name) }

    private func call<T>(_ name: String, as type: T.Type) -> T? {
        guard let client, client.responds(to: sel(name)) else { return nil }
        return unsafeBitCast(client.method(for: sel(name)), to: type)
    }

    private func getFloat(_ name: String) -> Float {
        guard isAvailable, let f = call(name, as: GetFloat.self) else { return 0 }
        return f(client!, sel(name), keyboardID)
    }

    private func getBool(_ name: String) -> Bool {
        guard isAvailable, let f = call(name, as: GetBool.self) else { return false }
        return f(client!, sel(name), keyboardID)
    }
}
