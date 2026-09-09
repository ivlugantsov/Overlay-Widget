//
//  generate_icon.swift
//  Одноразовый генератор иконки — не часть таргета приложения, гоняется вручную
//  ("swift Scripts/generate_icon.swift") и кладёт готовые PNG в .iconset.
//
//  Идея: нейтральная (не про музыку и не про крипту) — две скруглённые плашки внахлёст,
//  буквально "оверлей" одного окна поверх другого, на фиолетово-синем градиенте.
//

import AppKit

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let outputDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/OverlayWidget/Resources/AppIcon.iconset")
    .path

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let context = NSGraphicsContext.current!.cgContext
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    // Скруглённый фон — радиус по гайдлайну Apple (~22.37% от размера канвы).
    let cornerRadius = size * 0.2237
    let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.94, alpha: 1),
        NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.95, alpha: 1)
    ])!
    context.saveGState()
    backgroundPath.addClip()
    gradient.draw(in: backgroundPath, angle: -60)
    context.restoreGState()

    // Две плашки внахлёст — сама идея "оверлея". Задняя полупрозрачная, передняя сплошная.
    let plateSize = size * 0.46
    let plateCorner = plateSize * 0.28
    let backOffset = size * 0.14

    let backOrigin = CGPoint(x: size * 0.24 - backOffset * 0.3, y: size * 0.5 - backOffset * 0.3)
    let backRect = CGRect(origin: backOrigin, size: CGSize(width: plateSize, height: plateSize))
    let backPath = NSBezierPath(roundedRect: backRect, xRadius: plateCorner, yRadius: plateCorner)
    NSColor.white.withAlphaComponent(0.38).setFill()
    backPath.fill()

    let frontOrigin = CGPoint(x: size * 0.32, y: size * 0.24)
    let frontRect = CGRect(origin: frontOrigin, size: CGSize(width: plateSize, height: plateSize))
    let frontPath = NSBezierPath(roundedRect: frontRect, xRadius: plateCorner, yRadius: plateCorner)
    NSColor.white.setFill()
    frontPath.fill()

    return image
}

func pngData(from image: NSImage, size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

let specs: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for spec in specs {
    let image = drawIcon(size: spec.size)
    let data = pngData(from: image, size: spec.size)
    let url = URL(fileURLWithPath: "\(outputDir)/\(spec.name).png")
    try! data.write(to: url)
    print("wrote \(url.path)")
}
