import AppKit
import Foundation

// Deterministic vector artwork: paper, independent quota gauges, and a pin.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}

let forest = color(0.259, 0.471, 0.353)
let tile = NSBezierPath(roundedRect: NSRect(x: 104, y: 112, width: 816, height: 816), xRadius: 180, yRadius: 180)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 36
shadow.shadowOffset = NSSize(width: 0, height: -16)
shadow.set()
color(0.84, 0.83, 0.77).setFill()
tile.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(starting: color(1, 0.992, 0.961), ending: color(0.93, 0.92, 0.85))!
    .draw(in: tile, angle: -90)
tile.lineWidth = 3
NSColor.white.withAlphaComponent(0.7).setStroke()
tile.stroke()

for (y, fraction) in [(CGFloat(550), CGFloat(0.75)), (CGFloat(340), CGFloat(0.45))] {
    let rect = NSRect(x: 230, y: y, width: 564, height: 102)
    let track = NSBezierPath(roundedRect: rect, xRadius: 51, yRadius: 51)
    NSGradient(starting: color(0.75, 0.77, 0.70), ending: color(0.85, 0.87, 0.80))!
        .draw(in: track, angle: -90)
    let fill = NSBezierPath(
        roundedRect: NSRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height),
        xRadius: 51, yRadius: 51
    )
    NSGradient(starting: color(0.35, 0.59, 0.44), ending: forest)!.draw(in: fill, angle: -90)
    let sheen = NSBezierPath()
    sheen.move(to: NSPoint(x: rect.minX + 48, y: rect.maxY - 12))
    sheen.line(to: NSPoint(x: rect.minX + rect.width * fraction - 48, y: rect.maxY - 12))
    sheen.lineWidth = 3
    NSColor.white.withAlphaComponent(0.22).setStroke()
    sheen.stroke()
}

let needle = NSBezierPath()
needle.move(to: NSPoint(x: 755, y: 766))
needle.line(to: NSPoint(x: 730, y: 713))
needle.lineWidth = 13
needle.lineCapStyle = .round
forest.setStroke()
needle.stroke()
let pin = NSBezierPath(ovalIn: NSRect(x: 724, y: 752, width: 66, height: 66))
NSGradient(starting: color(0.42, 0.65, 0.50), ending: forest)!.draw(in: pin, angle: -90)
image.unlockFocus()

let iconset = root.appendingPathComponent("dist/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = pointSize * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(pointSize)x\(pointSize)\(scale == 2 ? "@2x" : "").png"
        let data = bitmap.representation(using: .png, properties: [:])!
        try data.write(to: iconset.appendingPathComponent(name))
        if pixels == 1024 {
            try data.write(to: root.appendingPathComponent("Resources/AppIcon.png"))
        }
    }
}
