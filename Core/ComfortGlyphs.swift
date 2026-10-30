import SwiftUI

// MARK: - The sun and the cloud
//
// "Feels good" and "try something else" are the two answers a resident can give, and the only words they ever need are
// a sun and a cloud. They are drawn here as flat, geometric shapes — a disc with eight rounded rays, a cloud made of
// three round bumps on a rounded base — so they read at a glance from across a room and look the same at 14 pt in a
// staff list as at 48 pt on the resident's button. The colours are the ones the buttons always had; only the drawing
// changed from SF Symbols (`sun.max.fill`, `cloud.fill`), whose rays and outline thin out at small sizes.

enum ComfortGlyphKind {
    case sun
    case cloud
}

/// A disc with eight short, round-capped rays.
struct SunGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
        let centre = CGPoint(x: origin.x + s / 2, y: origin.y + s / 2)
        var path = Path()
        let discRadius = 0.235 * s
        path.addEllipse(in: CGRect(x: centre.x - discRadius, y: centre.y - discRadius, width: discRadius * 2, height: discRadius * 2))
        let rayWidth = 0.105 * s
        let ray = Path(
            roundedRect: CGRect(x: -rayWidth / 2, y: -0.48 * s, width: rayWidth, height: 0.15 * s),
            cornerRadius: rayWidth / 2
        )
        for index in 0 ..< 8 {
            let turn = CGAffineTransform(translationX: centre.x, y: centre.y).rotated(by: CGFloat(index) * .pi / 4)
            path.addPath(ray, transform: turn)
        }
        return path
    }
}

/// Three round bumps — a tall one in the middle, a smaller one either side — sitting on a rounded base.
struct CloudGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGRect {
            CGRect(x: origin.x + (x - r) * s, y: origin.y + (y - r) * s, width: 2 * r * s, height: 2 * r * s)
        }
        var path = Path()
        path.addEllipse(in: circle(0.50, 0.44, 0.22))
        path.addEllipse(in: circle(0.30, 0.56, 0.16))
        path.addEllipse(in: circle(0.69, 0.54, 0.17))
        path.addPath(Path(
            roundedRect: CGRect(x: origin.x + 0.12 * s, y: origin.y + 0.56 * s, width: 0.76 * s, height: 0.22 * s),
            cornerRadius: 0.11 * s
        ))
        return path
    }
}

/// The flat sun or cloud, in one colour. `shadow` adds the hard-edged, un-blurred drop a flat illustration uses to lift a
/// light shape off a light disc; leave it off for a glyph in a list.
struct ComfortGlyph: View {
    let kind: ComfortGlyphKind
    var color: Color = .white
    var shadow: Color? = nil

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                if let shadow {
                    shape.fill(shadow).offset(y: side * 0.045)
                }
                shape.fill(color)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var shape: AnyShape {
        switch kind {
        case .sun: return AnyShape(SunGlyphShape())
        case .cloud: return AnyShape(CloudGlyphShape())
        }
    }
}
