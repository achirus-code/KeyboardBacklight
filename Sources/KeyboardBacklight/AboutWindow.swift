import AppKit
import SwiftUI

/// "About" window: app icon, name, version, author and a link to buymeacoffee.com.
@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        if !window.isVisible { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // No focus ring on the coffee card when the window opens
        DispatchQueue.main.async { window.makeFirstResponder(nil) }
    }

    private func makeWindow() -> NSWindow {
        // Fixed size computed up front: a self-sizing hosting controller combined with
        // .fullSizeContentView ends up in an endless constraint loop (crash).
        let host = NSHostingView(rootView: AboutView().ignoresSafeArea())
        let size = host.fittingSize
        host.sizingOptions = []
        let window = AboutPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.titled, .closable, .fullSizeContentView],
                                backing: .buffered, defer: false)
        window.contentView = host
        window.title = String(localized: "About \(AboutView.appName)")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        return window
    }
}

/// Esc closes the window – the app has no menu bar with "Close".
private final class AboutPanel: NSWindow {
    override func cancelOperation(_ sender: Any?) { close() }
}

private struct AboutView: View {
    static let appName = "KeyboardBacklight"
    private static let author = "Tillmann David"
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text(Self.appName).font(.title2.weight(.bold))
                Text("by \(Self.author)").font(.body)
                Text("Version \(Self.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CoffeeButton()
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 320)
    }
}

/// Link to buymeacoffee.com with the official button image
private struct CoffeeButton: View {
    private static let url = URL(string: "https://buymeacoffee.com/achirus")!
    private static let image = Bundle.main.url(forResource: "BuyMeACoffee", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))

    @Environment(\.openURL) private var openURL
    @State private var hovering = false

    var body: some View {
        Button { openURL(Self.url) } label: {
            if let image = Self.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160)
            } else {
                Text("Buy me a coffee")
            }
        }
        .buttonStyle(.plain)
        .brightness(hovering ? 0.04 : 0)
        .onHover { hovering = $0 }
        .help("buymeacoffee.com/achirus")
    }
}
