import SwiftUI

/// Legacy logo arc pair — kept for compact icon orbs.
private struct NoteStalgiaOrbLogoArc: Shape {
    var startDegrees: Double
    var endDegrees: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.48
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        return path
    }
}

/// Slow-rotating glowing arc frame — interlocking upper / lower sweeps like the NoteStalgia logo.
struct NoteStalgiaOrbAnimatedArcFrame: View {
    var diameter: CGFloat
    var lineWidth: CGFloat = 2
    var swirlPhase: Double = 0
    var glowPulse: Double = 0.72
    var breathe: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Upper-right sweep over the top toward the left; lower-left sweep under the bottom toward the right.
    private static let upperArc = (start: -52.0, end: 128.0)
    private static let lowerArc = (start: 148.0, end: 308.0)

    var body: some View {
        let spin = reduceMotion ? 0.0 : sin((swirlPhase / 0.35) * OrbHeartbeat.angularFrequency) * 3.5
        let shimmer = reduceMotion ? 1.0 : (0.78 + 0.22 * glowPulse)

        ZStack {
            logoArcStrokes(
                lineWidth: lineWidth * 4.4,
                gradient: LinearGradient(
                    colors: [
                        BrandTheme.logoPink.opacity(0.34 * shimmer),
                        BrandTheme.logoCyan.opacity(0.28 * shimmer),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                blur: lineWidth * 3
            )

            logoArcStrokes(
                lineWidth: lineWidth,
                gradient: LinearGradient(
                    colors: [
                        .white.opacity(0.96),
                        BrandTheme.logoCyan.opacity(0.90),
                        BrandTheme.logoPink.opacity(0.86),
                        .white.opacity(0.94),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                blur: 0
            )
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(breathe)
        .rotationEffect(.degrees(spin))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func logoArcStrokes(lineWidth lw: CGFloat, gradient: LinearGradient, blur: CGFloat) -> some View {
        ZStack {
            NoteStalgiaOrbLogoArc(startDegrees: Self.upperArc.start, endDegrees: Self.upperArc.end)
                .stroke(gradient, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            NoteStalgiaOrbLogoArc(startDegrees: Self.lowerArc.start, endDegrees: Self.lowerArc.end)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
                )
        }
        .blur(radius: blur)
    }
}

/// Legacy alias — prefer ``NoteStalgiaOrbAnimatedArcFrame``.
typealias NoteStalgiaOrbArcFrame = NoteStalgiaOrbAnimatedArcFrame

// MARK: - Reference orb exterior smoke wisps

struct NoteStalgiaOrbExteriorWisps: View {
    var diameter: CGFloat
    var swirlPhase: Double
    var glowPulse: Double
    var drift: Double = 0

    var body: some View {
        let sway = CGFloat(sin(swirlPhase * 0.85 + drift * 0.4)) * diameter * 0.018
        let lift = CGFloat(cos(swirlPhase * 0.62)) * diameter * 0.012

        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            BrandTheme.nebulaCyan.opacity(0.82 * glowPulse),
                            BrandTheme.nebulaTeal.opacity(0.36),
                            BrandTheme.nebulaBeltHighlight.opacity(0.14),
                            .clear,
                        ],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                )
                .frame(width: diameter * 1.05, height: diameter * 0.34)
                .offset(x: -diameter * 0.42 + sway, y: lift * 0.4)
                .blur(radius: diameter * 0.07)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            BrandTheme.nebulaPeach.opacity(0.78 * glowPulse),
                            BrandTheme.nebulaSalmon.opacity(0.48),
                            BrandTheme.nebulaLavender.opacity(0.22),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: diameter * 1.12, height: diameter * 0.40)
                .offset(x: diameter * 0.40 - sway * 0.6, y: -lift * 0.25)
                .blur(radius: diameter * 0.075)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.nebulaLavender.opacity(0.24 * glowPulse),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * 0.22
                    )
                )
                .frame(width: diameter * 0.55, height: diameter * 0.28)
                .offset(x: diameter * 0.08, y: -diameter * 0.34 + lift)
                .blur(radius: diameter * 0.05)
        }
        .frame(width: diameter * 1.45, height: diameter * 1.15)
        // Blurred gradient ellipses were rasterised on the CPU (`PaintShapeLayer`) every frame —
        // ~20% of main-thread time. Flatten them on the GPU instead; the padding keeps the offset
        // ellipses and their blur tails inside the offscreen so nothing is clipped, and the
        // negative padding restores the original layout size. Pixels are unchanged.
        .padding(.horizontal, diameter * Self.renderBleedX)
        .padding(.vertical, diameter * Self.renderBleedY)
        .drawingGroup(opaque: false, colorMode: .nonLinear)
        .padding(.horizontal, -diameter * Self.renderBleedX)
        .padding(.vertical, -diameter * Self.renderBleedY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Extra offscreen margin (fraction of diameter) beyond the 1.45 × 1.15 layout box: the side
    /// ellipses reach ~0.95d from centre and blur adds up to ~0.25d.
    private static let renderBleedX: CGFloat = 0.6
    private static let renderBleedY: CGFloat = 0.35
}

// MARK: - Animated nebula interior (reference video match)

struct NoteStalgiaNebulaFill: View {
    var diameter: CGFloat
    var swirlPhase: Double
    var glowPulse: Double
    /// Lower when video fills the orb interior so media stays visible beneath the arc frame.
    var fillOpacity: CGFloat = 1

    var body: some View {
        ReferenceOrbNebulaInterior(
            diameter: diameter,
            phase: swirlPhase,
            glowPulse: glowPulse,
            fillOpacity: fillOpacity
        )
        .opacity(fillOpacity)
    }
}

// MARK: - Full orb shell (menu circle · panels · icon size)

struct NoteStalgiaNebulaOrbShell: View {
    var width: CGFloat
    var height: CGFloat
    var pulse: Double
    var glowPulse: Double
    var shellScale: CGFloat
    var anchor: Date = Date()
    var showArcFrame: Bool = true
    var nebulaFillOpacity: CGFloat = 1
    var shellGlowScale: CGFloat = 1
    /// When set, the parent timeline drives animation (avoids a second 60fps timer).
    var animationElapsed: TimeInterval? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flowAmbientPaused) private var flowAmbientPaused
    @Environment(\.scenePhase) private var scenePhase

    private var bounds: CGFloat { min(width, height) }

    private var baseDiameter: CGFloat { min(width, height) }

    private var diameter: CGFloat { baseDiameter * shellScale }

    private var shellFrameInterval: Double {
        if reduceMotion { return 1 / OrbRenderBudget.reducedMotionFramesPerSecond }
        // Small self-driven orbs have no per-frame nebula noise (lite interior) — only slow wisp
        // and arc drift — so a calmer cadence is visually identical.
        if diameter < OrbRenderBudget.iconOrbMaxDiameter { return 1 / OrbRenderBudget.iconFramesPerSecond }
        return 1 / OrbRenderBudget.shellFramesPerSecond
    }

    var body: some View {
        Group {
            if let animationElapsed {
                orbShellContent(elapsed: animationElapsed)
            } else {
                // Self-driven (icon orbs). Freeze — same frame, not a different one — while the
                // keyboard is up, a staff list is scrolling, or the app is in the background.
                TimelineView(
                    .animation(
                        minimumInterval: shellFrameInterval,
                        paused: flowAmbientPaused || scenePhase != .active
                    )
                ) { timeline in
                    orbShellContent(elapsed: timeline.date.timeIntervalSince(anchor))
                }
            }
        }
    }

    private func orbShellContent(elapsed: TimeInterval) -> some View {
        let swirl = reduceMotion ? 0 : elapsed * 0.32
        let breathe = OrbHeartbeat.breatheScale(forPulse: pulse)
        let glowStrength = min(1.35, shellGlowScale)
        let wispDrift = OrbReferenceMotion.wispDrift(at: elapsed)

        return ZStack {
            // Pre-rendered halo (see `OrbGlowSprites`) — same pixels as re-blurring it every frame.
            OrbGlowSprites.sprite(.halo, diameter: diameter, bloom: glowPulse * Double(glowStrength))

            proceduralOrbInterior(
                swirl: swirl,
                breathe: breathe,
                glowStrength: glowStrength,
                wispDrift: wispDrift
            )
        }
        .frame(width: diameter * OrbHeartbeat.visualHeadroom, height: diameter * OrbHeartbeat.visualHeadroom)
        .shadow(color: BrandTheme.nebulaCyan.opacity(0.34 * glowPulse * Double(glowStrength)), radius: bounds * 0.24, y: 0)
        .shadow(color: BrandTheme.nebulaPeach.opacity(0.22 * glowPulse * Double(glowStrength)), radius: bounds * 0.17, y: 0)
        .shadow(
            color: BrandTheme.nebulaMagenta.opacity(0.20 * glowPulse * Double(glowStrength)),
            radius: bounds * 0.11,
            y: bounds * 0.014
        )
    }

    @ViewBuilder
    private func proceduralOrbInterior(
        swirl: Double,
        breathe: CGFloat,
        glowStrength: CGFloat,
        wispDrift: Double
    ) -> some View {
        NoteStalgiaOrbExteriorWisps(
            diameter: diameter,
            swirlPhase: swirl,
            glowPulse: glowPulse,
            drift: wispDrift
        )

        // Pre-rendered inner glow (see `OrbGlowSprites`).
        OrbGlowSprites.sprite(.glow, diameter: diameter, bloom: glowPulse * Double(glowStrength))
            .scaleEffect(breathe)

        NoteStalgiaNebulaFill(
            diameter: diameter,
            swirlPhase: swirl,
            glowPulse: glowPulse,
            fillOpacity: nebulaFillOpacity
        )
        .scaleEffect(breathe)

        // Large shells used to add a "ripple rings" Canvas here that drew nothing; only small
        // orbs show an arc frame.
        if showArcFrame, diameter < 96 {
            NoteStalgiaOrbAnimatedArcFrame(
                diameter: diameter * 1.01,
                lineWidth: max(1.5, diameter * 0.004),
                swirlPhase: swirl,
                glowPulse: glowPulse,
                breathe: breathe
            )
        }
    }
}

// MARK: - Brand wordmark

struct NoteStalgiaWordmark: View {
    var font: Font = BrandTheme.orbTitleFont(.largeTitle)
    var tracking: CGFloat = 4
    /// Main wordmark point size — scales the ™ mark proportionally.
    var pointSize: CGFloat = 32

    private var trademarkSize: CGFloat { max(8, pointSize * 0.30) }
    private var trademarkBaselineOffset: CGFloat { pointSize * 0.42 }

    var body: some View {
        (Text("NoteStalgia")
            .font(font)
            .tracking(tracking)
         + Text("™")
            .font(.system(size: trademarkSize, weight: .medium, design: .default))
            .baselineOffset(trademarkBaselineOffset))
            .foregroundStyle(BrandTheme.textOnOrb)
            .orbOverlayTextStyle()
            .accessibilityLabel("NoteStalgia")
    }
}


// MARK: - Cached orb glow sprites

/// The orb's outer radiance halo and inner glow are two large blurred radial gradients. Both are
/// scale-invariant (every radius and blur is a fixed fraction of the diameter) and every colour
/// stop's opacity is a multiple of `bloom`, so each frame is exactly "the same image, scaled and
/// faded". Rendering them once and drawing the bitmap removes two full-size Gaussian blurs per
/// frame — the single most expensive GPU work on every screen — without changing what's drawn.
@MainActor
enum OrbGlowSprites {
    enum Kind { case halo, glow }

    /// Sprite canvas as a multiple of diameter: content frame + room for the blur tails.
    private static func canvas(_ kind: Kind) -> CGFloat {
        switch kind {
        case .halo: return 2.1   // 1.42d circle, σ = 0.09d blur
        case .glow: return 1.44  // 1.04d circle, σ = 0.058d blur
        }
    }

    /// Highest bloom the shell produces (glowPulse ≤ 1, glow strength ≤ 1.35); sprites are
    /// rendered here and faded down, so no stop ever exceeds full opacity.
    private static let referenceBloom: Double = 1.35
    private static let referenceDiameter: CGFloat = 420
    private static let renderScale: CGFloat = 2
    private static var cache: [Kind: Image] = [:]

    static func prewarm() {
        _ = image(.halo)
        _ = image(.glow)
    }

    static func sprite(_ kind: Kind, diameter: CGFloat, bloom: Double) -> some View {
        let side = diameter * canvas(kind)
        return image(kind)
            .resizable()
            // Bilinear is plenty for a heavily blurred gradient; `.high` resampling every frame
            // cost more GPU time than the blur it replaced.
            .interpolation(.medium)
            .frame(width: side, height: side)
            .opacity(min(1, max(0, bloom / referenceBloom)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static func image(_ kind: Kind) -> Image {
        if let cached = cache[kind] { return cached }
        let d = referenceDiameter
        let side = d * canvas(kind)
        let content = Group {
            switch kind {
            case .halo: haloContent(diameter: d, bloom: referenceBloom)
            case .glow: glowContent(diameter: d, bloom: referenceBloom)
            }
        }
        .frame(width: side, height: side)
        let renderer = ImageRenderer(content: content)
        renderer.scale = renderScale
        renderer.isOpaque = false
        let image = renderer.cgImage.map { Image(decorative: $0, scale: renderScale) } ?? Image(systemName: "circle")
        cache[kind] = image
        return image
    }

    static func haloContent(diameter: CGFloat, bloom: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.nebulaCyan.opacity(bloom * 0.32),
                            BrandTheme.nebulaLavender.opacity(bloom * 0.18),
                            BrandTheme.nebulaPeach.opacity(bloom * 0.10),
                            .clear,
                        ],
                        center: .center,
                        startRadius: diameter * 0.34,
                        endRadius: diameter * 0.82
                    )
                )
                .frame(width: diameter * 1.42, height: diameter * 1.42)
                .blur(radius: diameter * 0.09)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(bloom * 0.22),
                            BrandTheme.nebulaBeltHighlight.opacity(bloom * 0.38),
                            BrandTheme.nebulaCyan.opacity(bloom * 0.16),
                            .clear,
                        ],
                        center: UnitPoint(x: 0.40, y: 0.36),
                        startRadius: 0,
                        endRadius: diameter * 0.44
                    )
                )
                .frame(width: diameter * 1.08, height: diameter * 1.08)
                .blur(radius: diameter * 0.048)
                .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func glowContent(diameter: CGFloat, bloom: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.nebulaCyan.opacity(bloom * 0.62),
                            BrandTheme.nebulaLavender.opacity(bloom * 0.38),
                            BrandTheme.nebulaPeach.opacity(bloom * 0.24),
                            .clear,
                        ],
                        center: .center,
                        startRadius: diameter * 0.04,
                        endRadius: diameter * 0.62
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(bloom * 0.26),
                            BrandTheme.nebulaBeltHighlight.opacity(bloom * 0.20),
                            .clear,
                        ],
                        center: UnitPoint(x: 0.38, y: 0.34),
                        startRadius: 0,
                        endRadius: diameter * 0.28
                    )
                )
                .blendMode(.plusLighter)
        }
        .frame(width: diameter * 1.04, height: diameter * 1.04)
        .blur(radius: diameter * 0.058)
    }
}
