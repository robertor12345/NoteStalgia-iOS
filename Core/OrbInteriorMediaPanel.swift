import SwiftUI

/// Clips flowing media to the resident / visuals orb interior and keeps the logo arc frame visible.
struct OrbInteriorMediaPanel<Media: View>: View {
    var orbSize: CGSize
    /// Slightly inset so the persistent nebula shell + arc frame remain visible around the clip.
    var mediaFillScale: CGFloat = 0.90
    var showArcFrame: Bool = true
    /// 0 = circular orb; 1 = full rectangular page. Morphs the clip shape from a perfect circle to a
    /// lightly-rounded rectangle so the media can grow to cover the entire screen (corners included)
    /// as a playlist expands, then shrink back to the orb.
    var pageExpansion: CGFloat = 0
    @ViewBuilder var media: () -> Media

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flowOrbPulseAnchor) private var flowOrbPulseAnchor
    @Environment(\.flowPanelPulseSpeed) private var flowPanelPulseSpeed

    private var pulseAnchor: Date {
        flowOrbPulseAnchor == .distantPast ? Date() : flowOrbPulseAnchor
    }

    var body: some View {
        let expansion = min(max(pageExpansion, 0), 1)
        let boxW = orbSize.width
        let boxH = orbSize.height
        let mediaW = boxW * mediaFillScale
        let mediaH = boxH * mediaFillScale
        let minSide = min(mediaW, mediaH)
        // Circle (radius = half the short side) → gentle page corner as it expands.
        let cornerRadius = minSide / 2 * (1 - expansion * 0.9)
        // Ease the tiny pulse breathing out as it fills the page so edges never reveal a gap.
        let pulseDamping = 1 - expansion

        // Built once per body pass, not once per tick: for the nature reel, `media()` runs
        // `NatureVideoCompilationView.init`, which re-shuffles its playlist every call.
        let mediaView = media()

        // When the media fills the page, pulse damping is ~0 — stop the timeline so we don't
        // spend a 60fps tick for a static scale of 1.
        TimelineView(
            .animation(
                minimumInterval: OrbRenderBudget.contentFrameInterval(reduceMotion: reduceMotion),
                paused: reduceMotion || expansion >= 0.95
            )
        ) { timeline in
            let elapsed = timeline.date.timeIntervalSince(pulseAnchor) * flowPanelPulseSpeed
            let sample = OrbPulseSample.sample(
                at: elapsed,
                mode: .calm,
                reduceMotion: reduceMotion
            )
            let contentScale = expansion >= 0.95 ? 1 : (1 + (sample.shellScale - 1) * pulseDamping)
            let shortDiameter = min(boxW, boxH)

            ZStack {
                mediaView
                    .frame(width: mediaW, height: mediaH)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .scaleEffect(contentScale)

                // Large panels have no visible frame (the old ripple-rings canvas drew nothing).
                if showArcFrame, expansion < 0.02, shortDiameter < 96 {
                    NoteStalgiaOrbAnimatedArcFrame(
                        diameter: shortDiameter * 1.02,
                        lineWidth: max(1.5, shortDiameter * 0.004),
                        swirlPhase: elapsed,
                        glowPulse: sample.glowPulse,
                        breathe: contentScale
                    )
                }
            }
            .frame(width: boxW, height: boxH)
        }
        .frame(width: boxW, height: boxH)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
