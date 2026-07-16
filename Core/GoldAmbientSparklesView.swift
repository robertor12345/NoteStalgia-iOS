import SwiftUI

/// Soft ambient particles — light blue, sage green, and peach pastel drift with subtle twinkle.
struct GoldAmbientSparklesView: View {
    var intensity: CGFloat = 1
    /// Pause the draw loop from outside (e.g. while the keyboard is up) so continuous particle
    /// animation doesn't compete with text input for the main thread.
    var externallyPaused: Bool = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Particle: Identifiable {
        let id: Int
        let xFrac: CGFloat
        let yFrac: CGFloat
        let radius: CGFloat
        let driftAmplitude: CGFloat
        let driftSpeed: Double
        let driftSpeedY: Double
        let phase: CGFloat
        let twinkleSpeed: Double
        let baseOpacity: CGFloat
        /// Second-frequency multiplier (irrational-ish drift).
        let wobbleFreq: Double
        let wobblePhase: CGFloat
        let jitterAmp: CGFloat
        let curl: Double
        // Palette is fixed per particle (by id % 3) — precomputed so the draw loop never rebuilds colors.
        let coreTint: Color
        let glowInner: Color
        let glowOuter: Color
        /// Larger / brighter particles get a radial glow; others use a cheap soft disc.
        let usesRichGlow: Bool
    }

    private let particles: [Particle]

    init(particleCount: Int = BrandTheme.ambientSparkleParticleCount, intensity: CGFloat = BrandTheme.ambientSparkleIntensity, externallyPaused: Bool = false) {
        self.intensity = intensity
        self.externallyPaused = externallyPaused
        particles = Self.particles(count: particleCount)
    }

    // Particles are deterministic (fixed seed), so build them once per count and reuse — avoids
    // regenerating hundreds of particles + colors every time an observing parent view re-renders
    // (e.g. on every keystroke while a sparkle layer is on screen).
    private static var particleCache: [Int: [Particle]] = [:]

    private static func particles(count: Int) -> [Particle] {
        if let cached = particleCache[count] { return cached }
        var gen = SplitMix64(seed: 0xF10C_B0C5)
        let built: [Particle] = (0..<count).map { i in
            let mod = i % 3
            let radius = CGFloat.random(in: 0.9...5.2, using: &gen)
            let baseOpacity = CGFloat.random(in: 0.42...0.98, using: &gen)
            let coreTint: Color = mod == 0 ? .white : (mod == 1 ? BrandTheme.nebulaCyan : BrandTheme.nebulaPink)
            let glowInner: Color = mod == 0 ? BrandTheme.nebulaCyan : (mod == 1 ? BrandTheme.nebulaLavender : BrandTheme.nebulaPink)
            let glowOuter: Color = mod == 0 ? BrandTheme.nebulaTeal : (mod == 1 ? BrandTheme.nebulaPurple : BrandTheme.nebulaMagenta)
            return Particle(
                id: i,
                xFrac: CGFloat.random(in: 0...1, using: &gen),
                yFrac: CGFloat.random(in: 0...1, using: &gen),
                radius: radius,
                driftAmplitude: CGFloat.random(in: 24...118, using: &gen),
                driftSpeed: Double.random(in: 0.09...0.38, using: &gen),
                driftSpeedY: Double.random(in: 0.07...0.34, using: &gen),
                phase: CGFloat.random(in: 0...(CGFloat.pi * 2), using: &gen),
                twinkleSpeed: Double.random(in: 0.65...3.1, using: &gen),
                baseOpacity: baseOpacity,
                wobbleFreq: Double.random(in: 1.47...3.19, using: &gen),
                wobblePhase: CGFloat.random(in: 0...(CGFloat.pi * 2), using: &gen),
                jitterAmp: CGFloat.random(in: 3.5...18, using: &gen),
                curl: Double.random(in: 0.2...0.75, using: &gen),
                coreTint: coreTint,
                glowInner: glowInner,
                glowOuter: glowOuter,
                // ~1/3 of particles keep the expensive radial glow — enough shimmer, far fewer GPU fills.
                usesRichGlow: radius >= 2.6 && baseOpacity >= 0.62 && i % 3 == 0
            )
        }
        particleCache[count] = built
        return built
    }

    var body: some View {
        // Present behind every screen for the app's whole lifetime — pause the draw loop while
        // backgrounded/inactive instead of burning CPU/GPU on particles nobody can see.
        TimelineView(
            .animation(
                minimumInterval: OrbRenderBudget.sparkleFrameInterval(reduceMotion: reduceMotion),
                paused: scenePhase != .active || externallyPaused
            )
        ) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // No full-screen radial “haze” here — only particles — avoids a dome / semicircle tint on pastel UI.
                let w = size.width
                let h = size.height

                for p in particles {
                    let fx = t * p.driftSpeed + Double(p.phase)
                    let fy = t * p.driftSpeedY * 1.13 + Double(p.phase) * 1.37
                    let wobbleX =
                        sin(fx) * Double(p.driftAmplitude)
                        + sin(t * p.driftSpeed * p.wobbleFreq + Double(p.wobblePhase)) * Double(p.driftAmplitude) * p.curl
                        + sin(t * 0.27 + Double(p.id) * 0.91) * Double(p.jitterAmp)
                    let wobbleY =
                        cos(fy) * Double(p.driftAmplitude * 0.82)
                        + cos(t * p.driftSpeedY * p.wobbleFreq * 0.88 + Double(p.wobblePhase) * 1.3) * Double(p.driftAmplitude) * 0.5
                        + sin(t * 0.19 + Double(p.id) * 0.47) * Double(p.jitterAmp * 0.7)
                    let cx = p.xFrac * w + CGFloat(wobbleX)
                    let cy = p.yFrac * h + CGFloat(wobbleY)

                    // Cull off-screen sparks (with glow margin) — denser field would otherwise paint
                    // hundreds of invisible fills each frame.
                    let margin = p.radius * 3.5
                    if cx < -margin || cy < -margin || cx > w + margin || cy > h + margin {
                        continue
                    }

                    let tw = 0.38 + 0.62 * pow(sin(t * p.twinkleSpeed + Double(p.id) * 0.37), 2)
                    let op = p.baseOpacity * CGFloat(tw) * intensity
                    if op < 0.014 { continue }

                    let core = CGRect(
                        x: cx - p.radius * 0.4,
                        y: cy - p.radius * 0.4,
                        width: p.radius * 0.8,
                        height: p.radius * 0.8
                    )
                    context.fill(
                        Path(ellipseIn: core),
                        with: .color(p.coreTint.opacity(min(1, Double(op * 1.08))))
                    )

                    // Soft halo — prefer a cheap solid disc; reserve radial gradients for hero sparks.
                    if op >= 0.08 {
                        let glowR = p.radius * (p.usesRichGlow ? 2.5 : 1.85)
                        let glow = CGRect(
                            x: cx - glowR,
                            y: cy - glowR,
                            width: glowR * 2,
                            height: glowR * 2
                        )
                        if p.usesRichGlow {
                            context.fill(
                                Path(ellipseIn: glow),
                                with: .radialGradient(
                                    Gradient(colors: [
                                        p.glowInner.opacity(Double(min(0.95, op * 0.72))),
                                        p.glowOuter.opacity(Double(op * 0.22)),
                                        .clear,
                                    ]),
                                    center: CGPoint(x: cx, y: cy),
                                    startRadius: 0,
                                    endRadius: p.radius * 3.2
                                )
                            )
                        } else {
                            context.fill(
                                Path(ellipseIn: glow),
                                with: .color(p.glowInner.opacity(Double(op * 0.18)))
                            )
                        }
                    }
                }
            }
            // Flatten the denser particle layer into one Metal texture for cheaper compositing.
            .drawingGroup(opaque: false, colorMode: .linear)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xBADC0FFE : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return z
    }
}
