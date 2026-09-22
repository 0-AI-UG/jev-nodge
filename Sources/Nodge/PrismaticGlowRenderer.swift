import SwiftUI

enum PrismaticGlowRenderer {
    /// Draws the spectral ribbons shared by the live HUD and static app icon.
    static func draw(
        in context: GraphicsContext,
        size: CGSize,
        level: Double,
        time: Double,
        reduceMotion: Bool = false,
        scale: Double = 1
    ) {
        let input = min(max(level, 0), 1)
        let idle = reduceMotion ? 0.08 : 0.09
            + 0.025 * (1 + sin(time * 0.38))
            + 0.012 * (1 + sin(time * 0.19 + 1.8))
        let energy = max(input, idle)
        let breath = 0.80
            + 0.035 * sin(time * 0.32)
            + 0.015 * sin(time * 0.17 + 0.8)
            + input * 0.28
        let lift = 0.84 + energy * 1.18
        let drift = reduceMotion ? 0 : 0.012 * sin(time * 0.18) + 0.005 * sin(time * 0.31 + 1.2)
        let center = size.width * (0.5 + drift)
        let span = size.width * (0.36 + energy * 0.07)

        func ribbon(
            _ color: Color,
            offset: Double,
            width: Double,
            blur: Double,
            opacity: Double,
            whiteBeam: Bool = false
        ) {
            var path = Path()
            for index in 0...96 {
                let u = Double(index) / 96
                let x = center + (u * 2 - 1) * span
                let envelope = pow(sin(u * .pi), 2)
                let flare = sin(u * .pi * 3 - time * 0.32)
                    + 0.16 * sin(u * .pi * 5 + time * 0.18)
                let convergence = min(1, max(0, (u - 0.25) / 0.45))
                let blend = convergence * convergence * (3 - 2 * convergence)
                let spread = (offset + (5 - offset) * blend) * scale
                let wave = 1.2 * scale + spread * 0.12 * flare
                let y = size.height - 1.8 * scale - envelope * (wave + spread) * lift
                let point = CGPoint(x: x, y: y)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }

            var layer = context
            layer.addFilter(.blur(radius: blur * scale))
            layer.opacity = opacity * breath
            layer.stroke(
                path,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: whiteBeam ? .clear : color.opacity(0.85), location: 0.18),
                        .init(color: whiteBeam ? color.opacity(0.7) : color, location: 0.5),
                        .init(color: whiteBeam ? .white : color.opacity(0.25), location: 0.72),
                        .init(color: whiteBeam ? color.opacity(0.9) : .clear, location: 0.88),
                        .init(color: .clear, location: 1),
                    ]),
                    startPoint: CGPoint(x: center - span, y: 0),
                    endPoint: CGPoint(x: center + span, y: 0)
                ),
                style: StrokeStyle(lineWidth: width * scale, lineCap: .round)
            )
        }

        let spectrum: [(Color, Double)] = [
            (Color(red: 1, green: 0.02, blue: 0.16), 21),
            (Color(red: 1, green: 0.42, blue: 0), 17.5),
            (Color(red: 1, green: 0.95, blue: 0), 14),
            (Color(red: 0.12, green: 1, blue: 0.22), 10.5),
            (Color(red: 0, green: 0.95, blue: 1), 7),
            (Color(red: 0.06, green: 0.16, blue: 1), 3.5),
        ]
        for (color, offset) in spectrum {
            ribbon(color, offset: offset, width: 8, blur: 9, opacity: 0.48)
        }
        for (color, offset) in spectrum {
            ribbon(color, offset: offset, width: 4.5, blur: 3.2, opacity: 0.95)
        }
        ribbon(.white, offset: 5, width: 12, blur: 9, opacity: 0.7, whiteBeam: true)
        ribbon(.white, offset: 5, width: 5, blur: 3, opacity: 0.95, whiteBeam: true)
        ribbon(.white, offset: 5, width: 2.5, blur: 0.8, opacity: 1, whiteBeam: true)
    }
}
