import AppKit
import SwiftUI

/// Einblendung wie beim alten macOS: Symbol und 16 Segmente, unten mittig auf dem Bildschirm.
@MainActor
final class BrightnessHUD {
    private let model = Model()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    final class Model: ObservableObject {
        @Published var level: Double = 0
    }

    func show(level: Double) {
        model.level = level
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 140))
        }

        hideWork?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.4
                panel?.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    if panel?.alphaValue == 0 { panel?.orderOut(nil) }
                }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 200, height: 200)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .init(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true

        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 22
        blur.layer?.masksToBounds = true

        let host = NSHostingView(rootView: HUDView(model: model))
        host.frame = blur.bounds
        host.autoresizingMask = [.width, .height]
        blur.addSubview(host)
        panel.contentView = blur
        return panel
    }
}

private struct HUDView: View {
    @ObservedObject var model: BrightnessHUD.Model
    private let segments = 16

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: model.level > 0 ? "light.max" : "light.min")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.primary)
                .frame(height: 96)
            HStack(spacing: 2) {
                ForEach(0..<segments, id: \.self) { i in
                    Rectangle()
                        .fill(Double(i) < (model.level * Double(segments)).rounded() ? Color.primary : Color.primary.opacity(0.18))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
