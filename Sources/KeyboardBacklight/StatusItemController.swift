import AppKit
import Combine
import SwiftUI

/// Menu bar icon with popover. Added or removed depending on `AppState.iconVisible`.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let state: AppState
    private let popover = NSPopover()
    private var item: NSStatusItem?
    private var outsideClickMonitor: Any?
    private var subscriptions = Set<AnyCancellable>()

    init(state: AppState) {
        self.state = state
        super.init()

        let host = NSHostingController(rootView: PopupView().environmentObject(state))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        // Closing on a click outside is handled by `outsideClickMonitor`: `.transient` would already
        // close the popover during app launch when the focus shifts.
        popover.behavior = .applicationDefined
        popover.delegate = self

        state.$iconVisible
            .removeDuplicates()
            .sink { [weak self] visible in self?.setVisible(visible) }
            .store(in: &subscriptions)
        state.$brightness
            .sink { [weak self] level in self?.item?.button?.image = MenuBarIcon.image(level: level) }
            .store(in: &subscriptions)
    }

    /// Manual launch or reopening: show the icon and open the settings.
    func reveal() {
        state.iconVisible = true
        // Give the newly created icon a moment to be placed in the menu bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showPopover()
        }
    }

    private func setVisible(_ visible: Bool) {
        if visible, item == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = MenuBarIcon.image(level: state.brightness)
            item.button?.target = self
            item.button?.action = #selector(togglePopover)
            self.item = item
        } else if !visible, let item {
            popover.performClose(nil)
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = item?.button, !popover.isShown else { return }
        state.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidShow(_ notification: Notification) {
        // Global monitors only see clicks in other apps – exactly "next to the settings"
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
        state.popupDidClose()
    }
}
