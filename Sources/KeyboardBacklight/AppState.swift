import AppKit
import Combine
import os

/// Zentraler Zustand: Helligkeit, Tastenbelegung, Einstellungen.
@MainActor
final class AppState: ObservableObject {
    enum Action { case darker, brighter }

    static let shared = AppState()

    @Published private(set) var brightness: Double = 0
    @Published private(set) var autoBrightness = false
    @Published private(set) var hasAccessibility = KeyInterceptor.hasAccessibility
    @Published private(set) var learning: Action?

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var showHUD: Bool { didSet { defaults.set(showHUD, forKey: "showHUD") } }
    /// Menüleisten-Icon ausblenden. Wirkt sofort; nur ein manueller Start oder erneutes Öffnen
    /// zeigt Icon und Einstellungen wieder (siehe `StatusItemController.reveal`).
    @Published var hideIcon: Bool {
        didSet {
            defaults.set(hideIcon, forKey: "hideIcon")
            iconVisible = !hideIcon
        }
    }
    /// Ob das Menüleisten-Icon gerade eingeblendet ist (bei `hideIcon` nur, solange die Einstellungen offen sind)
    @Published var iconVisible = true {
        didSet { if iconVisible != oldValue { log.info("Menüleisten-Icon \(self.iconVisible ? "eingeblendet" : "ausgeblendet", privacy: .public)") } }
    }
    @Published private(set) var darkerKeys: [KeyTrigger] { didSet { save(darkerKeys, "darkerKeys") } }
    @Published private(set) var brighterKeys: [KeyTrigger] { didSet { save(brighterKeys, "brighterKeys") } }

    let backlight = Backlight()
    private let interceptor = KeyInterceptor()
    private let hud = BrightnessHUD()
    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "de.achirus.keyboardbacklight", category: "ui")
    private var accessibilityTimer: Timer?
    private var lastChange = Date.distantPast

    /// 16 Stufen wie früher; mit ⌥⇧ gedrückt Viertelstufen (64).
    private let steps = 16.0
    private let fineSteps = 64.0

    private init() {
        defaults.register(defaults: ["enabled": true, "showHUD": true])
        enabled = defaults.bool(forKey: "enabled")
        showHUD = defaults.bool(forKey: "showHUD")
        hideIcon = defaults.bool(forKey: "hideIcon")
        darkerKeys = Self.load("darkerKeys") ?? KeyTrigger.defaultDarker
        brighterKeys = Self.load("brighterKeys") ?? KeyTrigger.defaultBrighter
        iconVisible = !hideIcon

        interceptor.onPress = { [weak self] press in
            MainActor.assumeIsolated { self?.handle(press) ?? false }
        }
        interceptor.isBound = { [weak self] trigger in
            MainActor.assumeIsolated { self?.isBound(trigger) ?? false }
        }
        refresh()
        startInterceptor()
    }

    // MARK: - Menüleisten-Icon

    func popupDidClose() {
        // Nach dem Schließen der Einstellungen wieder verstecken
        if hideIcon { iconVisible = false }
    }

    // MARK: - Helligkeit

    func refresh() {
        brightness = Double(backlight.brightness)
        autoBrightness = backlight.autoBrightness
    }

    func setBrightness(_ value: Double, showOverlay: Bool = false) {
        // Bei hellem Umgebungslicht hält die Automatik die Beleuchtung aus → abschalten
        if backlight.autoBrightness {
            backlight.autoBrightness = false
            autoBrightness = false
        }
        let clamped = max(0, min(1, value))
        backlight.brightness = Float(clamped)
        brightness = clamped
        lastChange = Date()
        if showOverlay && showHUD { hud.show(level: clamped) }
    }

    func step(_ action: Action, fine: Bool = false) {
        let n = fine ? fineSteps : steps
        // Während schneller Tastendrücke den eigenen Wert nehmen (die Hardware blendet noch über),
        // sonst den aktuellen Systemwert – die Automatik kann ihn inzwischen geändert haben.
        if Date().timeIntervalSince(lastChange) > 2 { refresh() }
        let current = (brightness * n).rounded()
        let next = current + (action == .brighter ? 1 : -1)
        setBrightness(next / n, showOverlay: true)
    }

    func setAutoBrightness(_ on: Bool) {
        backlight.autoBrightness = on
        // Die Automatik übernimmt verzögert – kurz danach den tatsächlichen Wert lesen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refresh() }
        autoBrightness = on
    }

    // MARK: - Tasten

    private func handle(_ press: KeyInterceptor.Press) -> Bool {
        if let action = learning {
            if press.trigger == .key(53) {  // Esc bricht ab
                learning = nil
                return true
            }
            assign(press.trigger, to: action)
            learning = nil
            return true
        }
        guard enabled else { return false }

        let action: Action
        if darkerKeys.contains(press.trigger) {
            action = .darker
        } else if brighterKeys.contains(press.trigger) {
            action = .brighter
        } else {
            return false
        }
        // Gedrückt halten wiederholt ~30× pro Sekunde – auf ein angenehmes Tempo bremsen
        if press.isRepeat && Date().timeIntervalSince(lastChange) < 0.09 { return true }
        let fine = press.flags.contains(.maskAlternate) && press.flags.contains(.maskShift)
        step(action, fine: fine)
        return true
    }

    private func isBound(_ trigger: KeyTrigger) -> Bool {
        enabled && (darkerKeys.contains(trigger) || brighterKeys.contains(trigger))
    }

    func label(for action: Action) -> String {
        let keys = action == .darker ? darkerKeys : brighterKeys
        return keys.isEmpty ? "–" : keys.map(\.label).joined(separator: ", ")
    }

    func startLearning(_ action: Action) {
        learning = learning == action ? nil : action
    }

    private func assign(_ trigger: KeyTrigger, to action: Action) {
        darkerKeys.removeAll { $0 == trigger }
        brighterKeys.removeAll { $0 == trigger }
        switch action {
        case .darker: darkerKeys = [trigger]
        case .brighter: brighterKeys = [trigger]
        }
    }

    func swapKeys() {
        (darkerKeys, brighterKeys) = (brighterKeys, darkerKeys)
    }

    func resetKeys() {
        darkerKeys = KeyTrigger.defaultDarker
        brighterKeys = KeyTrigger.defaultBrighter
    }

    // MARK: - Bedienungshilfen

    private func startInterceptor() {
        hasAccessibility = KeyInterceptor.hasAccessibility
        if hasAccessibility {
            interceptor.start()
            return
        }
        KeyInterceptor.requestAccessibility()
        // Warten, bis der Zugriff in den Systemeinstellungen erteilt wurde
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, KeyInterceptor.hasAccessibility else { return }
                timer.invalidate()
                self.hasAccessibility = true
                self.interceptor.start()
            }
        }
    }

    func openAccessibilitySettings() {
        KeyInterceptor.requestAccessibility()
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Speichern

    private func save(_ keys: [KeyTrigger], _ key: String) {
        defaults.set(try? JSONEncoder().encode(keys), forKey: key)
    }

    private static func load(_ key: String) -> [KeyTrigger]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([KeyTrigger].self, from: data)
    }
}
