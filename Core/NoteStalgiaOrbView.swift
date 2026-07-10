import SwiftUI

enum OrbEnvelopeMorph {
    static func morph(pulse: Double) -> CGFloat {
        CGFloat(pulse) * 0.52 + CGFloat(sin(pulse * .pi * 2)) * 0.05
    }

    static func envelopeShape(
        width: CGFloat,
        height: CGFloat,
        pulse: Double,
        morphOffset: CGFloat = 0
    ) -> GlowingBubbleEnvelopeShape {
        GlowingBubbleEnvelopeShape(
            width: width,
            height: height,
            morph: morph(pulse: pulse) + morphOffset
        )
    }

    static func rectPanelMorph(pulse: Double, intensity: CGFloat = 1) -> CGFloat {
        let base =
            pulse * 0.78
            + sin(pulse * .pi * 2) * 0.14
            + cos(pulse * .pi * 3.0 + 0.35) * 0.05
        return CGFloat(base) * intensity
    }

    static func rectPanelShape(
        width: CGFloat,
        height: CGFloat,
        pulse: Double,
        morphOffset: CGFloat = 0,
        deformStrength: CGFloat = 1
    ) -> GlowingRectEnvelopeShape {
        GlowingRectEnvelopeShape(
            width: width,
            height: height,
            morph: rectPanelMorph(pulse: pulse, intensity: deformStrength) + morphOffset,
            deformStrength: deformStrength
        )
    }

    /// Rectangular panel breathe — `intensity` scales how far the shell expands.
    static func rectPanelShellScale(pulse: Double, intensity: CGFloat = 1) -> CGFloat {
        CGFloat(0.90 + 0.16 * pulse * Double(intensity))
    }
}

enum OrbPulseMode: Equatable {
    case idle
    /// Slower breathe — home, resident, discovery shells.
    case calm
    case loading
    case success
    case dormant
}

struct OrbPulseSample {
    let pulse: Double
    let floatY: CGFloat
    let floatX: CGFloat
    let glowPulse: Double

    var shellScale: CGFloat { OrbHeartbeat.shellScale(forPulse: pulse) }

    var innerContentScale: CGFloat { OrbHeartbeat.innerContentScale(forPulse: pulse) }

    var contentFloatY: CGFloat { floatY * 0.95 }
    var contentFloatX: CGFloat { floatX * 0.95 }

    var softShellScale: CGFloat { shellScale }

    var softInnerContentScale: CGFloat { innerContentScale }

    static func sample(
        at elapsed: TimeInterval,
        mode: OrbPulseMode = .calm,
        reduceMotion: Bool,
        speedMultiplier: Double = 1
    ) -> OrbPulseSample {
        if reduceMotion || mode == .dormant {
            return OrbPulseSample(pulse: 0.5, floatY: 0, floatX: 0, glowPulse: 0.72)
        }

        let pulse = OrbHeartbeat.pulse(at: elapsed, speedMultiplier: speedMultiplier)
        let glowPulse = OrbHeartbeat.glow(at: elapsed, speedMultiplier: speedMultiplier)
        let drift = sin(elapsed * OrbHeartbeat.angularFrequency * 0.5)
        let floatY = CGFloat(drift * 3.5)
        let floatX = CGFloat(cos(elapsed * OrbHeartbeat.angularFrequency * 0.5 + 0.35) * 2.0)
        return OrbPulseSample(pulse: pulse, floatY: floatY, floatX: floatX, glowPulse: glowPulse)
    }

    /// Legacy soften — now identical rhythm, optional amplitude dampening only.
    func softened(factor: CGFloat = 0.30) -> OrbPulseSample {
        let damped = 0.5 + (pulse - 0.5) * Double(factor)
        return OrbPulseSample(
            pulse: damped,
            floatY: floatY * factor,
            floatX: floatX * factor,
            glowPulse: glowBaseBlend(glowPulse, factor: factor)
        )
    }

    private func glowBaseBlend(_ glow: Double, factor: CGFloat) -> Double {
        0.62 + (glow - 0.62) * Double(factor)
    }

    /// Blend reference orb swell with live music energy (resident playlist).
    func blendedWithMusic(pulse musicPulse: Double, glow musicGlow: Double, musicWeight: CGFloat = 0.82) -> OrbPulseSample {
        let w = Double(min(1, max(0, musicWeight)))
        let ref = 1 - w
        return OrbPulseSample(
            pulse: pulse * ref + musicPulse * w,
            floatY: floatY,
            floatX: floatX,
            glowPulse: glowPulse * ref + musicGlow * w
        )
    }
}

/// Pulsating sky-blue envelope that wraps menu content (soft blob, not a fixed circle).
struct NoteStalgiaOrbEnvelopeView: View {
    var size: CGSize
    var pulseMode: OrbPulseMode = .idle
    var anchor: Date = Date()
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 18
    var envelopeScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: OrbRenderBudget.shellFrameInterval(reduceMotion: reduceMotion), paused: pulseMode == .dormant)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(anchor)
            let sample = OrbPulseSample.sample(
                at: elapsed,
                mode: pulseMode,
                reduceMotion: reduceMotion
            )
            NoteStalgiaOrbEnvelopeBackdrop(
                width: max(120, (size.width - horizontalPadding * 2) * envelopeScale),
                height: max(160, (size.height - verticalPadding * 2) * envelopeScale),
                pulse: sample.pulse,
                glowPulse: sample.glowPulse,
                shellScale: sample.shellScale
            )
            .offset(x: sample.contentFloatX * 0.35, y: sample.contentFloatY * 0.35)
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Soft glowing bubble — gentle breathing silhouette (not a spiky organic blob).
struct GlowingBubbleEnvelopeShape: Shape {
    var width: CGFloat
    var height: CGFloat
    /// Subtle live morph (tie to pulse for breathing).
    var morph: CGFloat = 0

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        smoothClosedCurve(through: bubblePoints(in: rect))
    }

    private func bubblePoints(in rect: CGRect) -> [CGPoint] {
        let cx = rect.midX
        let cy = rect.midY
        let rx = width * 0.5
        let ry = height * 0.5
        let steps = 28
        let live = Double(morph)

        return (0..<steps).map { i in
            let t = Double(i) / Double(steps) * (.pi * 2)
            let breathe = sin(t * 2.0 + live * 0.55) * 0.024
            let shimmer = cos(t * 3.0 + 0.65 + live * 0.35) * 0.014
            let radial = 1.0 + breathe + shimmer
            let verticalSoft = 0.985 + sin(t + 1.2 + live * 0.4) * 0.028

            let x = cx + CGFloat(cos(t) * Double(rx) * radial)
            let y = cy + CGFloat(sin(t) * Double(ry) * radial * verticalSoft)
            return CGPoint(x: x, y: y)
        }
    }

    private func smoothClosedCurve(through points: [CGPoint]) -> Path {
        guard points.count > 2 else { return Path() }

        var path = Path()
        let count = points.count
        path.move(to: points[0])

        for i in 0..<count {
            let p0 = points[(i - 1 + count) % count]
            let p1 = points[i]
            let p2 = points[(i + 1) % count]
            let p3 = points[(i + 2) % count]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 5.5,
                y: p1.y + (p2.y - p0.y) / 5.5
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 5.5,
                y: p2.y - (p3.y - p1.y) / 5.5
            )
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        path.closeSubpath()
        return path
    }
}

/// Living rectangular blob — rounded silhouette with sides that bow, ripple, and flex with pulse.
struct GlowingRectEnvelopeShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var morph: CGFloat = 0
    /// Scales side bow / ripple — use < 1 for calmer discovery pulse.
    var deformStrength: CGFloat = 1

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        smoothClosedCurve(through: outlinePoints(in: rect))
    }

    private func outlinePoints(in rect: CGRect) -> [CGPoint] {
        let cx = rect.midX
        let cy = rect.midY
        let hw = width * 0.5
        let hh = height * 0.5
        let steps = 52
        let live = Double(morph)
        let n = 3.65
        let sizeScale = min(width, height)
        let strength = Double(deformStrength)

        return (0..<steps).map { i in
            let t = Double(i) / Double(steps) * (.pi * 2)
            let cosT = cos(t)
            let sinT = sin(t)

            let xUnit = copysign(pow(abs(cosT), 2.0 / n), cosT)
            let yUnit = copysign(pow(abs(sinT), 2.0 / n), sinT)
            var px = xUnit * Double(hw)
            var py = yUnit * Double(hh)

            let nx = xUnit == 0 ? cosT : xUnit * (2.0 / n) * pow(abs(cosT), 2.0 / n - 1.0)
            let ny = yUnit == 0 ? sinT : yUnit * (2.0 / n) * pow(abs(sinT), 2.0 / n - 1.0)
            let nLen = max(0.001, sqrt(nx * nx + ny * ny))
            let normalX = nx / nLen
            let normalY = ny / nLen

            let tangentX = -sinT
            let tangentY = cosT

            let horizontalEdge = pow(abs(cos(2.0 * t)), 0.18)
            let verticalEdge = pow(abs(sin(2.0 * t)), 0.18)
            let onFlatSide = max(horizontalEdge, verticalEdge)
            let nearCorner = 1.0 - onFlatSide

            let sideBow =
                (sin(t * 2.0 + live * 1.15) * 0.038 * horizontalEdge
                + cos(t * 2.0 + live * 0.92 + 0.6) * 0.028 * verticalEdge) * strength

            let edgeRipple =
                (sin(t * 5.0 + live * 1.45) * 0.016
                + cos(t * 7.0 + live * 1.05 + 0.3) * 0.010) * strength

            let tangentialFlex =
                (sin(t * 4.0 + live * 0.88) * 0.022 * onFlatSide
                + sin(t * 6.0 + live * 1.2 + 1.1) * 0.009 * nearCorner) * strength

            let cornerSoftening = sin(t * 3.0 + live * 0.7) * 0.012 * nearCorner * strength

            let globalBreathe = 1.0
                + sin(live * 1.25) * 0.014 * strength
                + cos(t * 2.0 + live * 0.65) * 0.011 * strength

            let normalDisp = (sideBow + edgeRipple + cornerSoftening) * Double(sizeScale)
            let tangentDisp = tangentialFlex * Double(sizeScale)

            px = (px + normalX * normalDisp + tangentX * tangentDisp) * globalBreathe
            py = (py + normalY * normalDisp + tangentY * tangentDisp) * globalBreathe

            return CGPoint(x: cx + CGFloat(px), y: cy + CGFloat(py))
        }
    }

    private func smoothClosedCurve(through points: [CGPoint]) -> Path {
        guard points.count > 2 else { return Path() }

        var path = Path()
        let count = points.count
        path.move(to: points[0])

        for i in 0..<count {
            let p0 = points[(i - 1 + count) % count]
            let p1 = points[i]
            let p2 = points[(i + 1) % count]
            let p3 = points[(i + 2) % count]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 5.5,
                y: p1.y + (p2.y - p0.y) / 5.5
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 5.5,
                y: p2.y - (p3.y - p1.y) / 5.5
            )
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        path.closeSubpath()
        return path
    }
}

/// Legacy alias — menu envelope now uses the smoother bubble silhouette.
typealias IrregularMenuEnvelopeShape = GlowingBubbleEnvelopeShape

/// Circular discovery bubble (equalizer + era media live inside).
struct GlowingBubbleShape: Shape {
    var diameter: CGFloat
    var morph: CGFloat = 0

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        GlowingBubbleEnvelopeShape(
            width: diameter,
            height: diameter,
            morph: morph
        ).path(in: rect)
    }
}

struct NoteStalgiaOrbEnvelopeBackdrop: View {
    var width: CGFloat
    var height: CGFloat
    var pulse: Double
    var glowPulse: Double
    var shellScale: CGFloat? = nil
    var nebulaFillOpacity: CGFloat = 1
    var showArcFrame: Bool = true
    var shellGlowScale: CGFloat = 1
    var animationElapsed: TimeInterval? = nil

    var body: some View {
        let scale = shellScale ?? CGFloat(0.94 + 0.06 * pulse)
        NoteStalgiaNebulaOrbShell(
            width: width,
            height: height,
            pulse: pulse,
            glowPulse: glowPulse,
            shellScale: scale,
            showArcFrame: showArcFrame,
            nebulaFillOpacity: nebulaFillOpacity,
            shellGlowScale: shellGlowScale,
            animationElapsed: animationElapsed
        )
    }
}

/// Discovery / resident playback shell — circular nebula orb.
struct FlowRoundedEnvelopeBackdrop: View {
    var width: CGFloat
    var height: CGFloat
    var pulse: Double
    var glowPulse: Double
    var shellScale: CGFloat
    var deformStrength: CGFloat = 1

    var body: some View {
        let d = min(width, height)
        NoteStalgiaNebulaOrbShell(
            width: d,
            height: d,
            pulse: pulse,
            glowPulse: glowPulse,
            shellScale: shellScale,
            showArcFrame: true
        )
    }
}

/// Compact circular orb for buttons and icons.
struct NoteStalgiaOrbView: View {
    var diameter: CGFloat
    var pulseMode: OrbPulseMode = .idle
    var anchor: Date = Date()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: OrbRenderBudget.shellFrameInterval(reduceMotion: reduceMotion), paused: pulseMode == .dormant)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(anchor)
            let sample = OrbPulseSample.sample(
                at: elapsed,
                mode: pulseMode,
                reduceMotion: reduceMotion
            )

            NoteStalgiaOrbBackdrop(
                diameter: diameter,
                pulse: sample.pulse,
                glowPulse: sample.glowPulse
            )
            .offset(x: sample.contentFloatX * 0.65, y: sample.contentFloatY * 0.65)
        }
    }
}

struct NoteStalgiaOrbBackdrop: View {
    var diameter: CGFloat
    var pulse: Double
    var glowPulse: Double

    var body: some View {
        let scale = CGFloat(0.94 + 0.06 * pulse)
        NoteStalgiaNebulaOrbShell(
            width: diameter,
            height: diameter,
            pulse: pulse,
            glowPulse: glowPulse,
            shellScale: scale,
            showArcFrame: diameter >= 40
        )
    }
}
