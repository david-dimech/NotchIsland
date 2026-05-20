import SwiftUI

// Custom island shape whose corner radii animate independently.
//
// Compact state  → topRadius = 0, bottomRadius = kNotchBottomRadius (12 pt)
//   Flat top (hidden inside the physical notch) + 12 pt bottom corners.
//   Corner bezier control-point ratio k ≈ 0.552 is taken directly from the
//   SVG file the user provided (Notch.svg, 369×52, inner width 306 units,
//   corner box 15.56×15.56).
//
// Expanded state → topRadius = kIslandCornerRadius (14 pt), bottomRadius = 14 pt
//   Standard rounded rectangle on all four corners.
//
// Because IslandShape conforms to Animatable, SwiftUI interpolates both radii
// during the expand/collapse spring, giving a smooth morph.
struct IslandShape: Shape, Animatable {
    var topRadius:    CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    // k ≈ 0.552 gives the same bezier quarter-circle as Apple's notch SVG.
    private static let k: CGFloat = 0.552

    func path(in rect: CGRect) -> Path {
        let tr = clamp(topRadius,    rect)
        let br = clamp(bottomRadius, rect)
        let k  = Self.k
        var p  = Path()

        // ── top-left corner ──────────────────────────────────────────────
        p.move(to: CGPoint(x: rect.minX + tr, y: rect.minY))

        // top edge
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))

        // top-right corner (radius = 0 in compact → straight corner)
        if tr > 0 {
            p.addCurve(
                to:       CGPoint(x: rect.maxX,      y: rect.minY + tr),
                control1: CGPoint(x: rect.maxX - tr*(1-k), y: rect.minY),
                control2: CGPoint(x: rect.maxX,      y: rect.minY + tr*(1-k))
            )
        }

        // right edge
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))

        // bottom-right corner
        p.addCurve(
            to:       CGPoint(x: rect.maxX - br, y: rect.maxY),
            control1: CGPoint(x: rect.maxX,      y: rect.maxY - br*(1-k)),
            control2: CGPoint(x: rect.maxX - br*(1-k), y: rect.maxY)
        )

        // bottom edge
        p.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))

        // bottom-left corner
        p.addCurve(
            to:       CGPoint(x: rect.minX,      y: rect.maxY - br),
            control1: CGPoint(x: rect.minX + br*(1-k), y: rect.maxY),
            control2: CGPoint(x: rect.minX,      y: rect.maxY - br*(1-k))
        )

        // left edge
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tr))

        // top-left corner (radius = 0 in compact)
        if tr > 0 {
            p.addCurve(
                to:       CGPoint(x: rect.minX + tr, y: rect.minY),
                control1: CGPoint(x: rect.minX,      y: rect.minY + tr*(1-k)),
                control2: CGPoint(x: rect.minX + tr*(1-k), y: rect.minY)
            )
        }

        p.closeSubpath()
        return p
    }

    private func clamp(_ r: CGFloat, _ rect: CGRect) -> CGFloat {
        min(max(r, 0), min(rect.width, rect.height) / 2)
    }
}
