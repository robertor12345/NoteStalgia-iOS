import SwiftUI
import UIKit

// MARK: - Oscillating ring equalizer (discovery orb + resident playlist hero)

enum OrbEqualizerMotion {
    static let barCount = 32

    static func barAmplified(index i: Int, phase t: Double, listenProgress frac: CGFloat) -> CGFloat {
        let ωA = 1.95 + Double(i % 15) * 0.068
        let ωB = 0.74 + Double((i ^ 11) % 17) * 0.049
        let wa = sin(t * ωA + Double(i) * 0.93)
        let wb = cos(t * ωB + Double(i) * 1.11)
        let weave = CGFloat((wa + wb + 1.8) / 3.6)

        let breath = 0.86 + CGFloat(sin(t * 0.47 + Double(i) * 0.08)) * 0.13
        let openness = CGFloat(sqrt(Double(frac)))
        let level = openness * CGFloat(0.38 + weave * Double(0.34 + frac * 0.28))
            + (1 - openness) * (0.12 + weave * (0.32 + frac * 0.22))
        return max(0.15, min(1, level * breath))
    }
}

/// Wiggling concentric rings hugging just outside a circular orb or glyph rim.
struct OrbRingEqualizerView: View {
    var canvasDiameter: CGFloat
    /// Exterior radius of the orb / hero disk — rings sit just outside this edge.
    var orbEdgeRadius: CGFloat
    /// 0…1 openness; discovery animates from slice timing, playlist uses 1.
    var listenProgress: CGFloat = 1
    /// When true, rings read the live `MusicReactiveBus` each frame and follow the music's spectrum.
    /// Read directly inside the per-frame Canvas so the parent view never re-renders for audio.
    var reactsToMusic: Bool = false
    /// Scales ring wiggle amplitude — resident hero glyph uses a higher value for clearer motion.
    var wiggleStrength: CGFloat = 1
    /// Extra gain on live spectrum bands before radial displacement.
    var liveAudioGain: CGFloat = 1

    private let ringCount = 5

    // The polygon geometry (angle, spectrum bar index, and angle's sin/cos) is identical every
    // frame and across all rings — precompute once instead of ~485 trig calls per frame.
    private static let stepCount = 96
    private static let angles: [Double] = (0 ... stepCount).map {
        Double($0) / Double(stepCount) * .pi * 2 - .pi / 2
    }
    private static let cosAngles: [Double] = angles.map(Foundation.cos)
    private static let sinAngles: [Double] = angles.map(Foundation.sin)
    private static let angle4: [Double] = angles.map { $0 * 4.0 }
    private static let angle7: [Double] = angles.map { $0 * 7.0 }
    private static let barIndices: [Int] = (0 ... stepCount).map {
        Int(Double($0) / Double(stepCount) * Double(OrbEqualizerMotion.barCount)) % OrbEqualizerMotion.barCount
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / OrbRenderBudget.contentFramesPerSecond, paused: false)) { timeline in
            let frac = min(1, max(0, listenProgress))
            let t = timeline.date.timeIntervalSinceReferenceDate
            let liveSnapshot = reactsToMusic ? MusicReactiveBus.shared.snapshot : nil
            let audioBandLevels: [CGFloat]? = (liveSnapshot?.isActive == true) ? liveSnapshot?.bands : nil
            let usesLiveAudio = (audioBandLevels?.count ?? 0) >= OrbEqualizerMotion.barCount

            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                let shimmer = 0.72 + 0.28 * frac
                let steps = Self.stepCount

                for ring in 0 ..< ringCount {
                    let ringT = Double(ring) / Double(max(1, ringCount - 1))
                    let baseRadius = orbEdgeRadius * (1.045 + ringT * 0.095)
                    let wiggleScale = orbEdgeRadius * (0.034 - ringT * 0.007) * wiggleStrength
                    let harmonicPhase = t * (2.0 + ringT * 0.8) + Double(ring) * 0.9
                    let synthPhase = t + ringT * 0.35

                    var path = Path()
                    for step in 0 ... steps {
                        let barIndex = Self.barIndices[step]
                        let amp: CGFloat
                        if usesLiveAudio, let levels = audioBandLevels {
                            let boosted = min(1, pow(max(0, levels[barIndex]), 0.84) * liveAudioGain)
                            amp = max(0.1, boosted)
                        } else {
                            amp = OrbEqualizerMotion.barAmplified(
                                index: barIndex,
                                phase: synthPhase,
                                listenProgress: frac
                            )
                        }
                        let liveBaseline: CGFloat = usesLiveAudio ? 0.18 : 0.38
                        let liveMultiplier: CGFloat = usesLiveAudio ? 4.8 * liveAudioGain : 2.4
                        let radialBump = (amp - liveBaseline) * wiggleScale * liveMultiplier
                        let harmonic = usesLiveAudio
                            ? 0
                            : sin(Self.angle4[step] + harmonicPhase) * wiggleScale * 0.32
                        let twist = usesLiveAudio
                            ? 0
                            : cos(Self.angle7[step] - t * 1.4 + Double(barIndex) * 0.15) * wiggleScale * 0.14
                        let radius = baseRadius + radialBump + harmonic + twist
                        let point = CGPoint(
                            x: center.x + CGFloat(Self.cosAngles[step] * radius),
                            y: center.y + CGFloat(Self.sinAngles[step] * radius)
                        )
                        if step == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    path.closeSubpath()

                    let strokeOpacity = (0.42 - ringT * 0.14) * shimmer
                    let lineWidth = max(1.1, canvasDiameter * (0.0048 - ringT * 0.0006))

                    context.stroke(
                        path,
                        with: .color(BrandTheme.nebulaCyan.opacity(strokeOpacity)),
                        lineWidth: lineWidth + 2.8
                    )
                    context.stroke(
                        path,
                        with: .color(BrandTheme.nebulaCyan.opacity(strokeOpacity * 0.35)),
                        lineWidth: lineWidth + 5.5
                    )
                    context.stroke(
                        path,
                        with: .color(
                            (ring.isMultiple(of: 2) ? BrandTheme.nebulaLavender : BrandTheme.nebulaPeach)
                                .opacity(strokeOpacity * 0.88)
                        ),
                        lineWidth: lineWidth
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: canvasDiameter, height: canvasDiameter)
    }
}

extension OrbRingEqualizerView {
    /// Matches discovery orb ring extent — canvas larger than core, rings in a background overlay.
    static let ringCanvasOutset: CGFloat = OrbHeartbeat.maxVisualExtentScale * 1.12

    static func canvasDiameter(for coreDiameter: CGFloat) -> CGFloat {
        coreDiameter * ringCanvasOutset
    }

    static func orbEdgeRadius(for coreDiameter: CGFloat, shellScale: CGFloat = 1) -> CGFloat {
        (coreDiameter * 0.5) * OrbHeartbeat.visualHeadroom * shellScale
    }

    /// Hero glyph on resident playlist — rings hug the disk without nebula headroom.
    static func glyphOrbEdgeRadius(for diskDiameter: CGFloat) -> CGFloat {
        diskDiameter * 0.52
    }

    static func glyphRingOutwardPad(for diskDiameter: CGFloat) -> CGFloat {
        let canvas = canvasDiameter(for: diskDiameter)
        return (canvas - diskDiameter) * 0.5
    }
}

// MARK: - Radial bar equalizer (resident playlist hero glyph)

enum OrbRadialBarEqualizerMotion {
    static let defaultBarCount = 120

    /// Interpolate the 32-band spectrum onto a dense ring of bars.
    static func interpolatedLevel(
        barIndex: Int,
        barCount: Int,
        levels: [CGFloat],
        phase: Double,
        liveAudioGain: CGFloat,
        applyMotionRipple: Bool = true,
        levelExponent: CGFloat = 0.68,
        neighbourMix: CGFloat = 0.32
    ) -> CGFloat {
        let bandCount = levels.count
        guard bandCount > 1 else { return 0.2 }

        let fractional = Double(barIndex) / Double(max(1, barCount - 1)) * Double(bandCount - 1)
        let lo = Int(floor(fractional))
        let hi = min(bandCount - 1, lo + 1)
        let mix = CGFloat(fractional - Double(lo))
        let blended = levels[lo] * (1 - mix) + levels[hi] * mix

        let prevIdx = max(0, lo - 1)
        let nextIdx = min(bandCount - 1, hi + 1)
        let neighbour = (levels[prevIdx] + levels[nextIdx]) * 0.5
        let woven = blended * (1 - neighbourMix) + neighbour * neighbourMix
        let ripple = applyMotionRipple
            ? CGFloat(sin(phase * 5.4 + Double(barIndex) * 0.37) * 0.14 + 1.0)
            : 1

        return min(1, pow(max(0, woven), levelExponent) * liveAudioGain * ripple)
    }

    /// Position around the ring (0…1), 0 at top, clockwise.
    static func angularPosition(forAngle angle: Double) -> CGFloat {
        let t = (angle + .pi / 2) / (2 * .pi)
        return CGFloat(t - floor(t))
    }

    /// Nebula orb palette sampled around the ring — cyan → lavender → pink → peach → cyan.
    private static let nebulaRingPalette: [Color] = [
        BrandTheme.nebulaCyan,
        BrandTheme.nebulaTeal,
        BrandTheme.logoCyan,
        BrandTheme.nebulaLavender,
        BrandTheme.logoLavenderBlue,
        BrandTheme.nebulaPurple,
        BrandTheme.nebulaMagenta,
        BrandTheme.nebulaPink,
        BrandTheme.logoPink,
        BrandTheme.nebulaPeach,
        BrandTheme.nebulaSalmon,
    ]

    // RGB components extracted once at startup instead of converting each `Color` via `UIColor`
    // on every bar, every frame (up to 120 bars × several conversions × 60fps). All blending
    // below works in plain (r, g, b) tuples and only builds a `Color` for the final result.
    private static let nebulaRingPaletteRGB: [(r: CGFloat, g: CGFloat, b: CGFloat)] =
        nebulaRingPalette.map(rgbaComponents)
    private static let whiteRGB: (r: CGFloat, g: CGFloat, b: CGFloat) = (1, 1, 1)

    private static func nebulaColorRGB(at position: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let palette = nebulaRingPaletteRGB
        guard palette.count > 1 else { return palette.first ?? (0, 0, 0) }

        let scaled = position * CGFloat(palette.count)
        let index = Int(floor(scaled)) % palette.count
        let next = (index + 1) % palette.count
        let frac = scaled - floor(scaled)
        return lerpRGB(palette[index], palette[next], t: frac)
    }

    static func spectrumColor(angle: Double, amplitude: CGFloat) -> Color {
        let base = nebulaColorRGB(at: angularPosition(forAngle: angle))
        let bright = lerpRGB(base, whiteRGB, t: 0.08 + amplitude * 0.14)
        let final = lerpRGB(base, bright, t: 0.55 + amplitude * 0.45)
        return Color(red: Double(final.r), green: Double(final.g), blue: Double(final.b))
    }

    private static func lerpRGB(
        _ a: (r: CGFloat, g: CGFloat, b: CGFloat),
        _ b: (r: CGFloat, g: CGFloat, b: CGFloat),
        t: CGFloat
    ) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let u = min(1, max(0, t))
        return (
            a.r + (b.r - a.r) * u,
            a.g + (b.g - a.g) * u,
            a.b + (b.b - a.b) * u
        )
    }

    private static func rgbaComponents(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }
}

/// Dense nebula-gradient bars radiating outward from the genre disk — reads the live spectrum bus.
struct OrbRadialBarEqualizerView: View {
    var canvasDiameter: CGFloat
    /// Radius of the hero genre disk.
    var orbRadius: CGFloat
    var visibleBarCount: Int = OrbRadialBarEqualizerMotion.defaultBarCount
    /// 0…1 openness — discovery ramps while a clip plays; playlist uses 1.
    var listenProgress: CGFloat = 1
    var reactsToMusic: Bool = true
    /// When true, bars stay flat until live PCM levels arrive (no synthetic wiggle).
    var liveAudioOnly: Bool = false
    /// Optional injected spectrum — preferred for discovery so redraws track the audio bus.
    var bandLevels: [CGFloat]? = nil
    var liveAudioGain: CGFloat = 1.85
    /// Lower = more sensitive bar extension (discovery uses ~0.48).
    var liveLevelExponent: CGFloat = 0.68
    var barAmplitudeFloor: CGFloat = 0.08
    /// Outward reach as a fraction of orb radius.
    var barReach: CGFloat = 0.46
    /// Lower = sharper per-bar variation (less cross-band smoothing).
    var neighbourMix: CGFloat = 0.32

    // A single `TimelineView` drives every redraw — live and synthetic — instead of relying on
    // an `@ObservedObject` subscription to `MusicReactiveBus` to trigger extra invalidations on
    // top of the timeline's own tick. The bus is read directly inside the tick, matching
    // `OrbRingEqualizerView`'s pattern, so audio updates never re-render the parent view.
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / OrbRenderBudget.contentFramesPerSecond, paused: false)) { timeline in
            let liveBands = resolvedBandLevels
            let usesLiveAudio = (liveBands?.count ?? 0) >= OrbEqualizerMotion.barCount
            spectrumCanvas(
                phase: usesLiveAudio ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                liveBands: liveBands,
                usesLiveAudio: usesLiveAudio
            )
        }
        .frame(width: canvasDiameter, height: canvasDiameter)
    }

    private func spectrumCanvas(phase: Double, liveBands: [CGFloat]?, usesLiveAudio: Bool) -> some View {
        let frac = min(1, max(0, listenProgress))
        let bars = max(48, visibleBarCount)

        return Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let innerRadius = orbRadius * 1.008
            let minOutset = orbRadius * 0.025
            let maxOutset = orbRadius * barReach
            let circumference = 2 * .pi * innerRadius
            let barWidth = max(1.1, circumference / CGFloat(bars) * 0.46)

            for i in 0 ..< bars {
                let angle = (Double(i) / Double(bars)) * .pi * 2 - .pi / 2
                let cosA = cos(angle)
                let sinA = sin(angle)

                let amp: CGFloat
                if usesLiveAudio, let levels = liveBands {
                    amp = max(
                        barAmplitudeFloor,
                        OrbRadialBarEqualizerMotion.interpolatedLevel(
                            barIndex: i,
                            barCount: bars,
                            levels: levels,
                            phase: phase,
                            liveAudioGain: liveAudioGain,
                            applyMotionRipple: false,
                            levelExponent: liveLevelExponent,
                            neighbourMix: neighbourMix
                        )
                    ) * frac
                } else if liveAudioOnly {
                    amp = 0.06 * frac
                } else {
                    let spectrumIndex = (i * OrbEqualizerMotion.barCount) / bars
                    amp = OrbEqualizerMotion.barAmplified(
                        index: spectrumIndex,
                        phase: phase + Double(i) * 0.04,
                        listenProgress: frac
                    )
                }

                let barLength = minOutset + (maxOutset - minOutset) * amp
                let start = CGPoint(
                    x: center.x + CGFloat(cosA * innerRadius),
                    y: center.y + CGFloat(sinA * innerRadius)
                )
                let end = CGPoint(
                    x: center.x + CGFloat(cosA * (innerRadius + barLength)),
                    y: center.y + CGFloat(sinA * (innerRadius + barLength))
                )

                var barPath = Path()
                barPath.move(to: start)
                barPath.addLine(to: end)

                let barColor = OrbRadialBarEqualizerMotion.spectrumColor(angle: angle, amplitude: amp)
                let barOpacity = 0.22 + Double(amp) * 0.28
                context.stroke(
                    barPath,
                    with: .color(barColor.opacity(barOpacity)),
                    style: StrokeStyle(lineWidth: barWidth + 1.4, lineCap: .butt)
                )
                context.stroke(
                    barPath,
                    with: .color(barColor.opacity(0.72 + Double(frac) * 0.28)),
                    style: StrokeStyle(lineWidth: barWidth, lineCap: .butt)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var resolvedBandLevels: [CGFloat]? {
        if let bandLevels, bandLevels.count >= OrbEqualizerMotion.barCount {
            return bandLevels
        }
        guard reactsToMusic else { return nil }
        let snapshot = MusicReactiveBus.shared.snapshot
        guard snapshot.isActive else { return nil }
        return snapshot.bands
    }
}

extension OrbRadialBarEqualizerView {
    /// Shared display tuning for live-music radial bars (discovery + resident hero).
    enum LiveMusicTuning {
        static let liveAudioGain: CGFloat = 2.75
        static let liveLevelExponent: CGFloat = 0.46
        static let barAmplitudeFloor: CGFloat = 0.035
        static let barReach: CGFloat = 0.54
        static let neighbourMix: CGFloat = 0.1
    }

    static func outwardPad(for diskDiameter: CGFloat) -> CGFloat {
        diskDiameter * 0.30
    }

    static func canvasDiameter(for diskDiameter: CGFloat) -> CGFloat {
        diskDiameter + outwardPad(for: diskDiameter) * 2
    }

    static func orbRadius(for diskDiameter: CGFloat) -> CGFloat {
        diskDiameter * 0.5
    }
}
