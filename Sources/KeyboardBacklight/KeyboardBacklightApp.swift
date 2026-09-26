import SwiftUI

@main
struct KeyboardBacklightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Das Menüleisten-Icon verwaltet StatusItemController (AppKit): MenuBarExtra(isInserted:)
    // hängt sich beim Ausblenden in einer Endlosschleife auf.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let controller = StatusItemController(state: AppState.shared)
            statusItem = controller
            // Bei ausgeblendetem Icon: manueller Start zeigt die Einstellungen, Autostart nicht
            if AppState.shared.hideIcon && !LaunchContext.launchedAtLogin() {
                controller.reveal()
            }
        }
        // Erneutes Öffnen (Finder, Spotlight, Launchpad) holt ein ausgeblendetes Icon zurück.
        // SwiftUI reicht das Reopen-Event nicht weiter → direkt abfangen.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleReopen(_:reply:)),
            forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(kAEReopenApplication))
    }

    @objc private func handleReopen(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        MainActor.assumeIsolated { statusItem?.reveal() }
    }
}
