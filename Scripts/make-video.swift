// Renders the demo video for the website: docs/video/demo.mp4 and docs/img/video-poster.jpg.
// Uses the app's own menu bar icon (MenuBarIcon.swift) and mirrors the overlay of BrightnessHUD.swift.
//
//   swiftc -O -parse-as-library Scripts/make-video.swift Sources/KeyboardBacklight/MenuBarIcon.swift -o .build/make-video
//   .build/make-video
import AppKit
import AVFoundation

// MARK: - Timeline

/// Scene size in points; rendered at `scale` for a sharp 1080p video.
let W: CGFloat = 1280, H: CGFloat = 720, scale: CGFloat = 1.5
let fps: Int32 = 30

struct Press { let t: Double; let key: String; let level: Double }

/// Key presses like a real user: single taps, then holding the key (≈ 11 steps per second, like the app).
func makeTimeline() -> (presses: [Press], duration: Double) {
    var presses: [Press] = []
    var t = 1.0, step = 0
    func tap(_ key: String, _ n: Int, every: Double) {
        for _ in 0..<n {
            step += key == "f6" ? 1 : -1
            presses.append(Press(t: t, key: key, level: Double(step) / 16))
            t += every
        }
    }
    tap("f6", 6, every: 0.42)   // 0 → 6/16 in single taps
    t += 0.5
    tap("f6", 10, every: 0.09)  // hold: up to 100 %
    t += 1.6
    tap("f5", 6, every: 0.42)   // 100 % → 10/16
    t += 0.5
    tap("f5", 10, every: 0.09)  // hold: down to 0
    return (presses, t + 1.8)
}

/// Brightness, pressed key and overlay opacity at time t.
func state(at t: Double, _ presses: [Press]) -> (level: Double, pressed: String?, hudAlpha: Double, lastLevel: Double) {
    let past = presses.filter { $0.t <= t }
    guard let last = past.last else { return (0, nil, 0, 0) }
    // Key counts as pressed until 0.14 s after the last press of a run
    let pressed = t - last.t < 0.14 ? last.key : nil
    // Brightness fades in like the hardware (~0.12 s)
    let prev = past.count > 1 ? past[past.count - 2].level : 0
    let k = min(1, (t - last.t) / 0.12)
    let level = prev + (last.level - prev) * k
    // Overlay: visible 1.2 s after the last press, then fades out over 0.4 s (like the app)
    let since = t - last.t
    let hud = since < 1.2 ? 1 : max(0, 1 - (since - 1.2) / 0.4)
    return (level, pressed, hud, last.level)
}

// MARK: - Drawing

let bgTop = NSColor(srgbRed: 0.03, green: 0.035, blue: 0.10, alpha: 1)
let bgBottom = NSColor(srgbRed: 0.047, green: 0.063, blue: 0.19, alpha: 1)
let indigo = NSColor(srgbRed: 0.165, green: 0.192, blue: 0.44, alpha: 1)
let keyCap = NSColor(srgbRed: 0.105, green: 0.11, blue: 0.135, alpha: 1)
let legendOff = NSColor(srgbRed: 0.27, green: 0.27, blue: 0.29, alpha: 1)
let legendOn = NSColor(srgbRed: 1, green: 0.914, blue: 0.722, alpha: 1)  // --glow
let amber = NSColor(srgbRed: 1, green: 0.702, blue: 0.278, alpha: 1)     // --amber-2

func mix(_ a: NSColor, _ b: NSColor, _ t: Double) -> NSColor {
    let a = a.usingColorSpace(.sRGB)!, b = b.usingColorSpace(.sRGB)!
    let t = CGFloat(max(0, min(1, t)))
    return NSColor(srgbRed: a.redComponent + (b.redComponent - a.redComponent) * t,
                   green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                   blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t,
                   alpha: a.alphaComponent + (b.alphaComponent - a.alphaComponent) * t)
}

func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
}

func drawCentered(_ image: NSImage, at center: CGPoint) {
    let s = image.size
    image.draw(in: CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height),
               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

func drawText(_ text: String, at center: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    let s = (text as NSString).size(withAttributes: attrs)
    (text as NSString).draw(at: CGPoint(x: center.x - s.width / 2, y: center.y - s.height / 2), withAttributes: attrs)
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> NSBezierPath { NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius) }

// Keyboard: function row with symbols, then four rows of the German layout
let fnRow: [(id: String, symbol: String?, label: String)] = [
    ("esc", nil, "esc"),
    ("f1", "sun.min", "F1"), ("f2", "sun.max", "F2"), ("f3", "rectangle.3.group", "F3"), ("f4", "magnifyingglass", "F4"),
    ("f5", "mic", "F5"), ("f6", "moon", "F6"), ("f7", "backward", "F7"), ("f8", "playpause", "F8"),
    ("f9", "forward", "F9"), ("f10", "speaker", "F10"), ("f11", "speaker.wave.1", "F11"), ("f12", "speaker.wave.3", "F12"),
    ("touchid", nil, ""),
]
let letterRows: [(lead: CGFloat, keys: [String], trail: CGFloat)] = [
    (1.0, ["^", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "ß", "´"], 1.5),
    (1.5, ["Q", "W", "E", "R", "T", "Z", "U", "I", "O", "P", "Ü", "+"], 1.0),
    (1.75, ["A", "S", "D", "F", "G", "H", "J", "K", "L", "Ö", "Ä", "#"], 0.75),
    (1.25, ["<", "Y", "X", "C", "V", "B", "N", "M", ",", ".", "-"], 2.25),
]

func drawKey(_ rect: CGRect, level: Double, pressed: Bool, draw legend: (CGRect, NSColor) -> Void) {
    let r = pressed ? rect.insetBy(dx: 1.5, dy: 1.5).offsetBy(dx: 0, dy: 1) : rect
    // Light from under the key cap
    if level > 0 {
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = amber.withAlphaComponent(0.85 * level)
        glow.shadowBlurRadius = 9
        glow.set()
        keyCap.setFill()
        rounded(r, 6).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    (pressed ? NSColor(white: 0.07, alpha: 1) : keyCap).setFill()
    rounded(r, 6).fill()
    if pressed {
        amber.withAlphaComponent(0.9).setStroke()
        let ring = rounded(r.insetBy(dx: 0.75, dy: 0.75), 5.5)
        ring.lineWidth = 1.5
        ring.stroke()
    }
    // Backlit legends glow with the brightness
    NSGraphicsContext.saveGraphicsState()
    if level > 0.02 {
        let halo = NSShadow()
        halo.shadowColor = amber.withAlphaComponent(level)
        halo.shadowBlurRadius = 3 + 6 * level
        halo.set()
    }
    legend(r, mix(legendOff, legendOn, pow(level, 0.55)))
    NSGraphicsContext.restoreGraphicsState()
}

func drawKeyboard(in area: CGRect, level: Double, pressed: String?) {
    let gap: CGFloat = 7
    // Height of a letter key: four letter rows plus the lower function row fill the area
    let unit = (area.height - gap * 4) / 4.75
    var y = area.minY

    // Function row: lower keys, esc 1.5 wide
    let fnH: CGFloat = unit * 0.75
    var x = area.minX
    for key in fnRow {
        let w = key.id == "esc" ? unit * 1.5 + gap * 0.5 : (area.maxX - area.minX - unit * 1.5 - gap * 13.5) / 13
        let rect = CGRect(x: x, y: y, width: w, height: fnH)
        if key.id == "touchid" {
            NSColor(white: 0.06, alpha: 1).setFill()
            rounded(rect, 6).fill()
            NSColor(white: 0.2, alpha: 1).setStroke()
            let ring = NSBezierPath(ovalIn: CGRect(x: rect.midX - 11, y: rect.midY - 11, width: 22, height: 22))
            ring.lineWidth = 1.2
            ring.stroke()
        } else {
            drawKey(rect, level: level, pressed: pressed == key.id) { r, color in
                if let name = key.symbol, let img = symbol(name, size: 15, color: color) {
                    drawCentered(img, at: CGPoint(x: r.midX, y: r.midY - 8))
                    drawText(key.label, at: CGPoint(x: r.midX, y: r.maxY - 10), size: 9.5, color: color)
                } else {
                    drawText(key.label, at: CGPoint(x: r.minX + 18, y: r.maxY - 12), size: 11, color: color)
                }
            }
        }
        x += w + gap
    }
    y += fnH + gap

    for row in letterRows {
        x = area.minX
        let widths = [row.lead] + Array(repeating: 1, count: row.keys.count) + [row.trail]
        let labels = [""] + row.keys + [""]
        let total = widths.reduce(0, +)
        let u = (area.width - gap * CGFloat(widths.count - 1)) / total
        for (w, label) in zip(widths, labels) {
            let rect = CGRect(x: x, y: y, width: u * w + gap * max(0, w - 1), height: unit)
            drawKey(rect, level: level, pressed: false) { r, color in
                if !label.isEmpty { drawText(label, at: CGPoint(x: r.midX, y: r.midY), size: 17, color: color) }
            }
            x += rect.width + gap
        }
        y += unit + gap
    }
}

func drawMenuBar(in screen: CGRect, level: Double) {
    let bar = CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: 34)
    NSColor(white: 0, alpha: 0.28).setFill()
    bar.fill()
    let white = NSColor(white: 1, alpha: 0.92)
    var x = bar.maxX - 22

    drawText("9:41", at: CGPoint(x: x - 18, y: bar.midY), size: 14, weight: .medium, color: white)
    x -= 58
    for name in ["battery.75percent", "wifi"] {
        if let img = symbol(name, size: 15, color: white) { drawCentered(img, at: CGPoint(x: x, y: bar.midY)) }
        x -= 36
    }
    // KeyboardBacklight's menu bar icon, tinted like a template image
    let icon = MenuBarIcon.image(level: level)
    let size = NSSize(width: icon.size.width * 1.6, height: icon.size.height * 1.6)
    let tinted = NSImage(size: size, flipped: false) { r in
        icon.draw(in: r)
        white.set()
        r.fill(using: .sourceAtop)
        return true
    }
    // Subtle highlight so the eye finds the icon
    NSColor(white: 1, alpha: 0.10).setFill()
    rounded(CGRect(x: x - 22, y: bar.minY + 4, width: 44, height: bar.height - 8), 6).fill()
    drawCentered(tinted, at: CGPoint(x: x, y: bar.midY))
}

func drawHUD(in screen: CGRect, level: Double, alpha: Double) {
    guard alpha > 0 else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.setAlpha(CGFloat(alpha))
    let size: CGFloat = 180
    let rect = CGRect(x: screen.midX - size / 2, y: screen.maxY - size - 34, width: size, height: size)
    NSColor(white: 0.12, alpha: 0.78).setFill()
    rounded(rect, 20).fill()
    NSColor(white: 1, alpha: 0.08).setStroke()
    rounded(rect.insetBy(dx: 0.5, dy: 0.5), 20).stroke()

    let white = NSColor(white: 1, alpha: 0.95)
    if let img = symbol(level > 0 ? "light.max" : "light.min", size: 64, color: white) {
        drawCentered(img, at: CGPoint(x: rect.midX, y: rect.minY + 74))
    }
    let segments = 16, segW: CGFloat = 6.3, segGap: CGFloat = 1.8
    let total = CGFloat(segments) * segW + CGFloat(segments - 1) * segGap
    let lit = Int((level * Double(segments)).rounded())
    for i in 0..<segments {
        (i < lit ? white : NSColor(white: 1, alpha: 0.18)).setFill()
        CGRect(x: rect.midX - total / 2 + CGFloat(i) * (segW + segGap), y: rect.maxY - 42, width: segW, height: segW).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
}

func drawFrame(_ ctx: CGContext, t: Double, presses: [Press]) {
    let s = state(at: t, presses)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: H * scale)
    ctx.scaleBy(x: scale, y: -scale)   // flipped: y grows downwards
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

    // Background like the website
    NSGradient(starting: bgTop, ending: bgBottom)!.draw(in: CGRect(x: 0, y: 0, width: W, height: H), angle: 90)

    // Screen with wallpaper
    let screen = CGRect(x: 170, y: 26, width: W - 340, height: 318)
    NSColor(white: 0.02, alpha: 1).setFill()
    rounded(screen.insetBy(dx: -12, dy: -12), 22).fill()
    NSGraphicsContext.saveGraphicsState()
    rounded(screen, 10).addClip()
    NSGradient(colors: [indigo, NSColor(srgbRed: 0.09, green: 0.1, blue: 0.24, alpha: 1), bgTop])!
        .draw(in: screen, angle: -90)
    drawMenuBar(in: screen, level: s.level)
    drawHUD(in: screen, level: s.lastLevel, alpha: s.hudAlpha)
    NSGraphicsContext.restoreGraphicsState()

    // Keyboard deck with a warm glow that grows with the brightness
    let deck = CGRect(x: 110, y: 372, width: W - 220, height: H - 372 - 22)
    NSColor(srgbRed: 0.16, green: 0.17, blue: 0.2, alpha: 1).setFill()
    rounded(deck, 26).fill()
    let kbArea = deck.insetBy(dx: 34, dy: 24)
    NSColor(white: 0.05, alpha: 1).setFill()
    rounded(kbArea.insetBy(dx: -8, dy: -8), 12).fill()
    if s.level > 0 {
        NSGradient(colors: [amber.withAlphaComponent(0.22 * s.level), amber.withAlphaComponent(0)])!
            .draw(in: rounded(kbArea.insetBy(dx: -8, dy: -8), 12), relativeCenterPosition: .zero)
    }
    drawKeyboard(in: kbArea, level: s.level, pressed: s.pressed)

    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()
}

// MARK: - Encoding

@main
struct VideoMaker {
    static func main() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let videoURL = root.appendingPathComponent("docs/video/demo.mp4")
        let posterURL = root.appendingPathComponent("docs/img/video-poster.jpg")
        try FileManager.default.createDirectory(at: videoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: videoURL)

        let (presses, duration) = makeTimeline()
        let pw = Int(W * scale), ph = Int(H * scale)

        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pw, AVVideoHeightKey: ph,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_200_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: pw, kCVPixelBufferHeightKey as String: ph,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frames = Int(duration * Double(fps))
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { usleep(2000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            guard let buffer else { fatalError("no pixel buffer") }
            CVPixelBufferLockBaseAddress(buffer, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: pw, height: ph, bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            let t = Double(frame) / Double(fps)
            drawFrame(ctx, t: t, presses: presses)

            // Poster: full brightness with the overlay visible
            if abs(t - 5.4) < 0.5 / Double(fps), let image = ctx.makeImage() {
                let rep = NSBitmapImageRep(cgImage: image)
                try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])!.write(to: posterURL)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        if let error = writer.error { throw error }
        print("Done: \(videoURL.path) (\(frames) frames, \(String(format: "%.1f", duration)) s)")
    }
}
