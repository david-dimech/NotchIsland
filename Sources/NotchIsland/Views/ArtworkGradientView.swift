import SwiftUI
import AppKit

// Animated 4-point blurred gradient that derives its colors from album artwork.
// Runs via TimelineView so each frame is driven by wall-clock time — no Timer needed.
struct ArtworkGradientView: View {
    let image: NSImage

    // Colors stay stable as long as the same artwork is displayed.
    private var colors: [Color] { Self.extract(image) }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GradientCanvas(colors: colors, time: t)
                .blur(radius: 22)
                .brightness(-0.15)   // darken so white text stays readable
                .allowsHitTesting(false)
        }
    }

    // MARK: – Color extraction

    private static func extract(_ nsImage: NSImage) -> [Color] {
        let side = 16
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return defaultColors
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                   bytesPerRow: side * 4, space: colorSpace,
                                   bitmapInfo: bitmapInfo.rawValue),
              let data = ctx.data else { return defaultColors }

        ctx.draw(cgImage, in: CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        let bytes = data.assumingMemoryBound(to: UInt8.self)

        // Sample four quadrant representatives (avoid exact corners to get richer hues)
        let positions = [(3, 3), (12, 3), (3, 12), (12, 12)]
        return positions.map { (x, y) in
            let offset = (y * side + x) * 4
            return Color(
                red:   Double(bytes[offset])     / 255,
                green: Double(bytes[offset + 1]) / 255,
                blue:  Double(bytes[offset + 2]) / 255
            )
        }
    }

    private static let defaultColors: [Color] = [.blue, .purple, .indigo, .cyan]
}

// MARK: – Canvas renderer

private struct GradientCanvas: View {
    let colors: [Color]
    let time:   Double

    // Each blob has its own amplitude and phase so they drift independently.
    private static let config: [(ax: Double, ay: Double, phase: Double, speed: Double)] = [
        (0.28, 0.22, 0.00,              0.27),
        (0.22, 0.28, Double.pi / 2,     0.23),
        (0.25, 0.20, Double.pi,         0.31),
        (0.20, 0.25, 3 * Double.pi / 2, 0.19),
    ]

    var body: some View {
        Canvas { ctx, size in
            for (i, color) in colors.prefix(4).enumerated() {
                let c = Self.config[i]
                let cx = size.width  * (0.5 + c.ax * sin(time * c.speed + c.phase))
                let cy = size.height * (0.5 + c.ay * cos(time * c.speed * 0.9 + c.phase))
                let radius = max(size.width, size.height) * 0.85

                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius,
                                           width:  radius * 2,
                                           height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [color.opacity(0.9), color.opacity(0)]),
                        center:      CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius:   radius
                    )
                )
            }
        }
    }
}
