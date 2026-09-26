import SwiftUI

@main
struct KeyboardBacklightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The menu bar icon is managed by StatusItemController (AppKit): MenuBarExtra(isInserted:)
    // hangs in an endless loop when it is hidden.
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
            // Icon hidden: a manual launch shows the settings, a launch at login doesn't
            if AppState.shared.hideIcon && !LaunchContext.launchedAtLogin() {
                controller.reveal()
            }
        }
        // Opening the app again (Finder, Spotlight, Launchpad) brings back a hidden icon.
        // SwiftUI doesn't pass the reopen event on → handle it directly.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleReopen(_:reply:)),
            forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(kAEReopenApplication))
    }

    @objc private func handleReopen(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        MainActor.assumeIsolated { statusItem?.reveal() }
    }
}
