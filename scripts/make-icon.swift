#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("usage: make-icon.swift OUTPUT.icns")
}

let fileManager = FileManager.default
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let workURL = fileManager.temporaryDirectory
    .appendingPathComponent("NodgeIcon-\(UUID().uuidString)")
let iconsetURL = workURL.appendingPathComponent("Nodge.iconset")
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: workURL) }

let variants = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, pixels) in variants {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Could not create icon bitmap") }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    bounds.fill()

    let inset = CGFloat(pixels) * 0.035
    let tile = bounds.insetBy(dx: inset, dy: inset)
    NSColor(calibratedWhite: 0.035, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: tile,
        xRadius: CGFloat(pixels) * 0.22,
        yRadius: CGFloat(pixels) * 0.22
    ).fill()

    let sizeConfiguration = NSImage.SymbolConfiguration(
        pointSize: CGFloat(pixels) * 0.5,
        weight: .medium
    )
    let colorConfiguration = NSImage.SymbolConfiguration(paletteColors: [.black, .white])
    let configuration = sizeConfiguration.applying(colorConfiguration)
    guard let symbol = NSImage(
        systemSymbolName: "waveform.circle.fill",
        accessibilityDescription: "Jev Nodge"
    )?.withSymbolConfiguration(configuration) else { fatalError("SF Symbol unavailable") }

    let symbolSize = CGFloat(pixels) * 0.56
    symbol.draw(
        in: NSRect(
            x: (CGFloat(pixels) - symbolSize) / 2,
            y: (CGFloat(pixels) - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode icon")
    }
    try png.write(to: iconsetURL.appendingPathComponent(name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
