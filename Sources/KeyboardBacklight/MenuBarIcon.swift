import AppKit

/// Menüleisten-Symbol wie das alte macOS-Symbol für Tastaturhelligkeit: ein Balken mit fünf
/// Punkten im Halbkreis. Die Punkte leuchten von links nach rechts mit der Helligkeit auf;
/// nicht leuchtende Punkte sind klein und blass.
enum MenuBarIcon {
    private static let dotCount = 5

    static func image(level: Double) -> NSImage {
        // 0 Punkte nur bei ganz aus, sonst mindestens einer
        let lit = level <= 0 ? 0 : max(1, Int((level * Double(dotCount)).rounded(.up)))
        if let cached = cache[lit] { return cached }

        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            let center = NSPoint(x: 11, y: 4)

            // Balken
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: center.x - 3.9, y: center.y - 0.85, width: 7.8, height: 1.7),
                         xRadius: 0.85, yRadius: 0.85).fill()

            // Punkte im Halbkreis, von links (180°) nach rechts (0°)
            let angles: [Double] = [180, 138, 90, 42, 0]
            for (i, angle) in angles.enumerated() {
                let rad = angle * .pi / 180
                let p = NSPoint(x: center.x + cos(rad) * 7.6, y: center.y + sin(rad) * 7.6)
                let on = i < lit
                let r = on ? 1.35 : 0.9
                NSColor.black.withAlphaComponent(on ? 1 : 0.35).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).fill()
            }
            return true
        }
        image.isTemplate = true
        cache[lit] = image
        return image
    }

    nonisolated(unsafe) private static var cache: [Int: NSImage] = [:]
}
