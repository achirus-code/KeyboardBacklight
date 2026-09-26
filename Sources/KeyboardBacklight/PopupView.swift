import SwiftUI

struct PopupView: View {
    @EnvironmentObject var state: AppState
    var onClose: () -> Void = {}
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard Backlight").font(.headline)
                Spacer()
                Toggle("", isOn: $state.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .help("Capture keys on/off")
            }

            if !state.backlight.isAvailable {
                Label("No keyboard backlight found", systemImage: "exclamationmark.triangle")
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

            Toggle("Adjust to ambient light", isOn: Binding(get: { state.autoBrightness },
                                                          set: { state.setAutoBrightness($0) }))
                .help("In bright light, macOS then turns the backlight off completely. Pressing a key turns the automatic adjustment off.")

            if !state.hasAccessibility {
                accessibilityWarning
            }

            Divider()

            Text("Keys").font(.subheadline.weight(.semibold))
            keyRow("Darker", action: .darker)
            keyRow("Brighter", action: .brighter)
            HStack {
                Button("Swap") { state.swapKeys() }
                Button("Default") { state.resetKeys() }
                Spacer()
            }
            .controlSize(.small)
            Text("Hold ⌥⇧ for finer steps")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("Show overlay when changing", isOn: $state.showHUD)
            VStack(alignment: .leading, spacing: 2) {
                Toggle("Hide menu bar icon", isOn: $state.hideIcon)
                Text("To bring it back, open the app again (Finder, Spotlight).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
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
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
                Spacer()
                Button("Close", action: onClose)
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
                Text("Press a key … (Esc)")
                    .foregroundStyle(.tint)
            } else {
                Text(state.label(for: action))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(state.learning == action ? "Cancel" : "Change") { state.startLearning(action) }
                .controlSize(.small)
                .disabled(!state.hasAccessibility)
        }
    }

    private var accessibilityWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Accessibility access missing", systemImage: "hand.raised")
                .foregroundStyle(.orange)
            Text("Without it, KeyboardBacklight can't capture the brightness keys.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open System Settings") { state.openAccessibilitySettings() }
                .controlSize(.small)
        }
    }
}
