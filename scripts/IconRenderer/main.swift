import AppKit
import SwiftUI

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: icon-renderer PREVIEW.png OUTPUT.icns")
}

let fileManager = FileManager.default
let previewURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let workURL = fileManager.temporaryDirectory
    .appendingPathComponent("NodgeIcon-\(UUID().uuidString)")
let iconsetURL = workURL.appendingPathComponent("Nodge.iconset")
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: workURL) }

struct NodgeAppIcon: View {
    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 210, style: .continuous)
        ZStack {
            tile.fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.045, green: 0.05, blue: 0.06),
                        Color(red: 0.008, green: 0.01, blue: 0.014),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Canvas { context, size in
                PrismaticGlowRenderer.draw(
                    in: context,
                    size: size,
                    level: 0.35,
                    time: 0,
                    scale: size.width / 350
                )
            }
            .frame(height: 230)
            .frame(maxHeight: .infinity, alignment: .bottom)

            Image(systemName: "waveform.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .white)
                .font(.system(size: 410, weight: .semibold))
                .offset(y: -62)

            tile.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.25), .white.opacity(0.035)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 5
            )
        }
        .frame(width: 1024, height: 1024)
        .clipShape(tile)
        .padding(34)
        .frame(width: 1092, height: 1092)
    }
}

let image: NSImage = MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: NodgeAppIcon())
    renderer.scale = 1
    guard let image = renderer.nsImage else {
        fatalError("Could not render app icon")
    }
    return image
}
guard let tiff = image.tiffRepresentation,
      let sourceBitmap = NSBitmapImageRep(data: tiff),
      let preview = sourceBitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render app icon")
}
try fileManager.createDirectory(
    at: previewURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try preview.write(to: previewURL)

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
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero,
        operation: .copy,
        fraction: 1
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
