// Draws the app icon and creates Resources/AppIcon.icns.
// Usage: swift Scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func draw(_ ctx: CGContext, _ s: CGFloat) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    ctx.scaleBy(x: s / 1024, y: s / 1024)

    // Background: squircle with a night sky gradient (macOS grid: 824 pt with a 100 pt margin)
    let bg = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bgPath = CGPath(roundedRect: bg, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(bgPath)
    ctx.setFillColor(color(0x10142B))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let sky = CGGradient(colorsSpace: space, colors: [color(0x2A3170), color(0x0B0D1E)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Warm glow behind the key
    let glow = CGGradient(colorsSpace: space,
                          colors: [color(0xFFD27A, 0.95), color(0xFFB347, 0.45), color(0xFF9A3C, 0)] as CFArray,
                          locations: [0, 0.35, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 470), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 470), endRadius: 360, options: [])

    // Light rays above the key
    ctx.setLineCap(.round)
    ctx.setLineWidth(34)
    ctx.setStrokeColor(color(0xFFE3A8, 0.95))
    let c = CGPoint(x: 512, y: 470)
    for angle in stride(from: 30.0, through: 150.0, by: 30.0) {
        let r = angle * .pi / 180
        ctx.move(to: CGPoint(x: c.x + cos(r) * 255, y: c.y + sin(r) * 255))
        ctx.addLine(to: CGPoint(x: c.x + cos(r) * 335, y: c.y + sin(r) * 335))
    }
    ctx.strokePath()
    ctx.restoreGState()

    // Keycap: base + slightly smaller top
    let base = CGRect(x: 272, y: 230, width: 480, height: 330)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 40, color: color(0xFFB347, 0.9))
    ctx.addPath(CGPath(roundedRect: base, cornerWidth: 70, cornerHeight: 70, transform: nil))
    ctx.setFillColor(color(0x1C1E26))
    ctx.fillPath()
    ctx.restoreGState()

    let top = CGRect(x: 312, y: 290, width: 400, height: 250)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: top, cornerWidth: 50, cornerHeight: 50, transform: nil))
    ctx.clip()
    let cap = CGGradient(colorsSpace: space, colors: [color(0x3A3D4A), color(0x24262F)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(cap, start: CGPoint(x: 512, y: top.maxY), end: CGPoint(x: 512, y: top.minY), options: [])
    ctx.restoreGState()

    // Glowing moon on the key (the F6 key)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 30, color: color(0xFFD27A, 1))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color(0xFFE9B8))
    ctx.fillEllipse(in: CGRect(x: 442, y: 345, width: 140, height: 140))
    ctx.setBlendMode(.destinationOut)
    ctx.fillEllipse(in: CGRect(x: 488, y: 382, width: 124, height: 124))
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

let sizes: [(String, Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
    ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
    ("512x512", 512), ("512x512@2x", 1024),
]
for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext, CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: iconset.appendingPathComponent("icon_\(name).png"))
}

let icns = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try! task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("Done: \(icns.path)")
