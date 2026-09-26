import AppKit
import Combine
import SwiftUI

/// Menüleisten-Icon mit Popover. Wird je nach `AppState.iconVisible` hinzugefügt oder entfernt.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let state: AppState
    private let popover = NSPopover()
    private var item: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()

    init(state: AppState) {
        self.state = state
        super.init()

        let host = NSHostingController(rootView: PopupView(onClose: { [weak self] in self?.popover.performClose(nil) })
            .environmentObject(state))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.delegate = self

        state.$iconVisible
            .removeDuplicates()
            .sink { [weak self] visible in self?.setVisible(visible) }
            .store(in: &subscriptions)
        state.$brightness
            .sink { [weak self] level in self?.item?.button?.image = MenuBarIcon.image(level: level) }
            .store(in: &subscriptions)
    }

    /// Manueller Start bzw. erneutes Öffnen: Icon einblenden und Einstellungen öffnen. Sie bleiben
    /// offen, bis der Benutzer sie schließt – ein Klick daneben schließt sie nicht.
    func reveal() {
        state.iconVisible = true
        // Dem frisch angelegten Icon einen Moment geben, bis es in der Menüleiste platziert ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showPopover(pinned: true)
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
            showPopover(pinned: false)
        }
    }

    private func showPopover(pinned: Bool) {
        guard let button = item?.button else { return }
        popover.behavior = pinned ? .applicationDefined : .transient
        if popover.isShown { return }
        state.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        state.popupDidClose()
    }
}
