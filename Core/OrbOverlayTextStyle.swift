import SwiftUI

extension View {
    /// High-contrast orb copy with a dark halo for legibility on the nebula.
    func orbOverlayTextStyle(intensity: CGFloat = 1) -> some View {
        let i = max(0.55, intensity)
        return shadow(color: Color.black.opacity(0.58 * i), radius: 1.5 * i, x: 0, y: 1)
            .shadow(color: BrandTheme.nebulaDeep.opacity(0.62 * i), radius: 3 * i, x: 0, y: 2)
            .shadow(color: Color(white: 0.18, opacity: 0.48 * i), radius: 6 * i, x: 0, y: 0)
            .shadow(color: Color(white: 0.32, opacity: 0.30 * i), radius: 14 * i, x: 0, y: 0)
            // Four shadow passes per label, re-blurred by the render server on every frame while
            // the orb breathes. Flattened into one texture (re-rendered only when the text changes).
            .flattenedShadows(bleed: 14 * i * 2.5 + 2)
    }

    /// Renders this view and its shadows into a single texture so Core Animation composites one
    /// layer per frame instead of running one Gaussian blur pass per `.shadow`. On the iOS
    /// Simulator every such pass is a synchronous round-trip to the host GPU, and on the sign-in
    /// screen alone there were a dozen per frame — that, not the orb's own drawing, is what capped
    /// the breathing at ~25 fps. `bleed` must cover the largest shadow radius × ~2.5 plus offsets so
    /// no blur tail is clipped; the negative padding restores the original layout size.
    func flattenedShadows(bleed: CGFloat) -> some View {
        modifier(FlattenedShadows(bleed: bleed))
    }

    func orbOverlayText(muted: Bool = false, intensity: CGFloat = 1) -> some View {
        foregroundStyle(muted ? BrandTheme.textOnOrbMuted : BrandTheme.textOnOrb)
            .orbOverlayTextStyle(intensity: muted ? intensity * 0.94 : intensity)
    }
}

private struct FlattenedShadows: ViewModifier {
    var bleed: CGFloat

    func body(content: Content) -> some View {
        if OrbRenderBudget.experimentCAShadows {
            content
        } else {
            content
                .padding(bleed)
                .drawingGroup(opaque: false, colorMode: .nonLinear)
                .padding(-bleed)
        }
    }
}
