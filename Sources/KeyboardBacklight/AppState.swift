import AppKit
import Combine
import os

/// Central state: brightness, key bindings, settings.
@MainActor
final class AppState: ObservableObject {
    enum Action { case darker, brighter }

    static let shared = AppState()

    @Published private(set) var brightness: Double = 0
    @Published private(set) var autoBrightness = false
    @Published private(set) var hasAccessibility = KeyInterceptor.hasAccessibility
    @Published private(set) var learning: Action?

    @Published var showHUD: Bool { didSet { defaults.set(showHUD, forKey: "showHUD") } }
    /// Hides the menu bar icon. Takes effect immediately; only a manual launch or reopening the app
    /// shows the icon and settings again (see `StatusItemController.reveal`).
    @Published var hideIcon: Bool {
        didSet {
            defaults.set(hideIcon, forKey: "hideIcon")
            iconVisible = !hideIcon
        }
    }
    /// Whether the menu bar icon is currently shown (with `hideIcon` only while the settings are open)
    @Published var iconVisible = true {
        didSet { if iconVisible != oldValue { log.info("Menu bar icon \(self.iconVisible ? "shown" : "hidden", privacy: .public)") } }
    }
    /// Turn "Adjust to ambient light" back on after `autoRevertMinutes` without a manual change
    @Published var autoRevertEnabled: Bool {
        didSet {
            defaults.set(autoRevertEnabled, forKey: "autoRevertEnabled")
            scheduleAutoRevert()
        }
    }
    @Published var autoRevertMinutes: Int {
        didSet {
            defaults.set(autoRevertMinutes, forKey: "autoRevertMinutes")
            scheduleAutoRevert()
        }
    }
    static let autoRevertChoices = [5, 15, 30, 60, 120, 240, 480]
    @Published private(set) var darkerKeys: [KeyTrigger] { didSet { save(darkerKeys, "darkerKeys") } }
    @Published private(set) var brighterKeys: [KeyTrigger] { didSet { save(brighterKeys, "brighterKeys") } }

    let backlight = Backlight()
    private let interceptor = KeyInterceptor()
    private let hud = BrightnessHUD()
    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "de.achirus.keyboardbacklight", category: "ui")
    private var accessibilityTimer: Timer?
    private var lastChange = Date.distantPast
    private var autoRevertTimer: Timer?
    /// When the automatic brightness will be turned back on (nil = nothing scheduled)
    private var autoRevertDate: Date?

    /// 16 steps like before; with ⌥⇧ held, quarter steps (64).
    private let steps = 16.0
    private let fineSteps = 64.0

    private init() {
        defaults.register(defaults: ["showHUD": true])
        defaults.removeObject(forKey: "enabled")   // former "capture keys" switch, no longer exists
        showHUD = defaults.bool(forKey: "showHUD")
        hideIcon = defaults.bool(forKey: "hideIcon")
        // Earlier versions had only the time menu with "never" (0) instead of the checkbox
        let storedMinutes = defaults.integer(forKey: "autoRevertMinutes")
        autoRevertEnabled = defaults.object(forKey: "autoRevertEnabled") as? Bool ?? (storedMinutes > 0)
        autoRevertMinutes = Self.autoRevertChoices.contains(storedMinutes) ? storedMinutes : 30
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

        // A switch back that was pending when the app quit (e.g. restart) – overdue ones happen right away
        if let pending = defaults.object(forKey: "autoRevertDate") as? Date { startAutoRevertTimer(at: pending) }
        // Timers don't count the time the Mac sleeps → check again after waking up
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let date = self.autoRevertDate else { return }
                self.startAutoRevertTimer(at: date)
            }
        }
    }

    // MARK: - Menu bar icon

    func popupDidClose() {
        // Hide the icon again once the settings are closed
        if hideIcon { iconVisible = false }
    }

    // MARK: - Brightness

    func refresh() {
        brightness = Double(backlight.brightness)
        autoBrightness = backlight.autoBrightness
    }

    func setBrightness(_ value: Double, showOverlay: Bool = false) {
        // In bright ambient light the automatic adjustment keeps the backlight off → turn it off
        if backlight.autoBrightness {
            backlight.autoBrightness = false
            autoBrightness = false
        }
        let clamped = max(0, min(1, value))
        backlight.brightness = Float(clamped)
        brightness = clamped
        lastChange = Date()
        scheduleAutoRevert()
        if showOverlay && showHUD { hud.show(level: clamped) }
    }

    func step(_ action: Action, fine: Bool = false) {
        let n = fine ? fineSteps : steps
        // During rapid key presses use our own value (the hardware is still fading),
        // otherwise the current system value – the automatic adjustment may have changed it.
        if Date().timeIntervalSince(lastChange) > 2 { refresh() }
        let current = (brightness * n).rounded()
        let next = current + (action == .brighter ? 1 : -1)
        setBrightness(next / n, showOverlay: true)
    }

    func setAutoBrightness(_ on: Bool) {
        backlight.autoBrightness = on
        autoBrightness = on
        if on { cancelAutoRevert() } else { scheduleAutoRevert() }
        // The automatic adjustment takes over with a delay – read the actual value shortly after
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.refresh() }
    }

    // MARK: - Back to automatic brightness

    /// (Re)starts the countdown back to the automatic brightness – after every manual change.
    private func scheduleAutoRevert() {
        guard autoRevertEnabled, !autoBrightness else { return cancelAutoRevert() }
        startAutoRevertTimer(at: Date().addingTimeInterval(Double(autoRevertMinutes) * 60))
    }

    private func startAutoRevertTimer(at date: Date) {
        autoRevertTimer?.invalidate()
        autoRevertDate = date
        defaults.set(date, forKey: "autoRevertDate")
        // A date in the past fires right away
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.revertToAutoBrightness() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        autoRevertTimer = timer
    }

    private func cancelAutoRevert() {
        autoRevertTimer?.invalidate()
        autoRevertTimer = nil
        autoRevertDate = nil
        defaults.removeObject(forKey: "autoRevertDate")
    }

    private func revertToAutoBrightness() {
        cancelAutoRevert()
        guard !backlight.autoBrightness else { return }
        log.info("Back to automatic brightness")
        setAutoBrightness(true)
    }

    // MARK: - Keys

    private func handle(_ press: KeyInterceptor.Press) -> Bool {
        if let action = learning {
            if press.trigger == .key(53) {  // Esc cancels
                learning = nil
                return true
            }
            assign(press.trigger, to: action)
            learning = nil
            return true
        }
        let action: Action
        if darkerKeys.contains(press.trigger) {
            action = .darker
        } else if brighterKeys.contains(press.trigger) {
            action = .brighter
        } else {
            return false
        }
        // Holding a key repeats ~30× per second – slow it down to a comfortable pace
        if press.isRepeat && Date().timeIntervalSince(lastChange) < 0.09 { return true }
        let fine = press.flags.contains(.maskAlternate) && press.flags.contains(.maskShift)
        step(action, fine: fine)
        return true
    }

    private func isBound(_ trigger: KeyTrigger) -> Bool {
        darkerKeys.contains(trigger) || brighterKeys.contains(trigger)
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

    func resetKeys() {
        darkerKeys = KeyTrigger.defaultDarker
        brighterKeys = KeyTrigger.defaultBrighter
    }

    // MARK: - Accessibility

    private func startInterceptor() {
        hasAccessibility = KeyInterceptor.hasAccessibility
        if hasAccessibility {
            interceptor.start()
            return
        }
        KeyInterceptor.requestAccessibility()
        // Wait until access has been granted in System Settings
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

    // MARK: - Persistence

    private func save(_ keys: [KeyTrigger], _ key: String) {
        defaults.set(try? JSONEncoder().encode(keys), forKey: key)
    }

    private static func load(_ key: String) -> [KeyTrigger]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([KeyTrigger].self, from: data)
    }
}
