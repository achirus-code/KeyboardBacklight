import SwiftUI

struct PopupView: View {
    @EnvironmentObject var state: AppState
    var onClose: () -> Void = {}
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tastaturbeleuchtung").font(.headline)
                Spacer()
                Toggle("", isOn: $state.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .help("Tasten abfangen ein/aus")
            }

            if !state.backlight.isAvailable {
                Label("Keine Tastaturbeleuchtung gefunden", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 8) {
                Image(systemName: "light.min").foregroundStyle(.secondary)
                Slider(value: Binding(get: { state.brightness },
                                      set: { state.setBrightness($0) }), in: 0...1)
                Image(systemName: "light.max").foregroundStyle(.secondary)
                Text("\(Int((state.brightness * 100).rounded())) %")
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }

            Toggle("An Umgebungslicht anpassen", isOn: Binding(get: { state.autoBrightness },
                                                             set: { state.setAutoBrightness($0) }))
                .help("Bei hellem Licht schaltet macOS die Beleuchtung dann ganz aus. Tastendruck schaltet die Automatik ab.")

            if !state.hasAccessibility {
                accessibilityWarning
            }

            Divider()

            Text("Tasten").font(.subheadline.weight(.semibold))
            keyRow("Dunkler", action: .darker)
            keyRow("Heller", action: .brighter)
            HStack {
                Button("Tauschen") { state.swapKeys() }
                Button("Standard") { state.resetKeys() }
                Spacer()
            }
            .controlSize(.small)
            Text("⌥⇧ gedrückt halten für feinere Schritte")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Anzeige beim Ändern einblenden", isOn: $state.showHUD)
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Menüleisten-Icon ausblenden", isOn: $state.hideIcon)
                Text("Zurückholen: App erneut öffnen (Finder, Spotlight).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
            Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        try LaunchAtLogin.set(on)
                        loginError = nil
                    } catch {
                        loginError = error.localizedDescription
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }

            Divider()

            HStack {
                Button("Beenden") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                Spacer()
                Button("Schließen", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 300)

    }

    private func keyRow(_ title: String, action: AppState.Action) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).frame(width: 60, alignment: .leading)
            if state.learning == action {
                Text("Taste drücken … (Esc)")
                    .foregroundStyle(.tint)
            } else {
                Text(state.label(for: action))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(state.learning == action ? "Abbrechen" : "Ändern") { state.startLearning(action) }
                .controlSize(.small)
                .disabled(!state.hasAccessibility)
        }
    }

    private var accessibilityWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Bedienungshilfen-Zugriff fehlt", systemImage: "hand.raised")
                .foregroundStyle(.orange)
            Text("Ohne ihn kann KeyboardBacklight die Mond- und Zurück-Taste nicht abfangen.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Systemeinstellungen öffnen") { state.openAccessibilitySettings() }
                .controlSize(.small)
        }
    }
}
