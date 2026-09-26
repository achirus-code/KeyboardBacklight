import AppKit

/// Menu bar symbol like the old macOS keyboard brightness symbol: a bar with five dots in a
/// semicircle. The dots light up from left to right with the brightness;
/// unlit dots are small and faint.
enum MenuBarIcon {
    private static let dotCount = 5

    static func image(level: Double) -> NSImage {
        // 0 dots only when completely off, otherwise at least one
        let lit = level <= 0 ? 0 : max(1, Int((level * Double(dotCount)).rounded(.up)))
        if let cached = cache[lit] { return cached }

        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            let center = NSPoint(x: 11, y: 4)

            // Bar
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: center.x - 3.9, y: center.y - 0.85, width: 7.8, height: 1.7),
                         xRadius: 0.85, yRadius: 0.85).fill()

            // Dots in a semicircle, from left (180°) to right (0°)
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
