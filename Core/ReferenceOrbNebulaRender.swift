import SwiftUI

// MARK: - Reference orb interior (matches 27c8481b reference clip — volumetric nebula, not latitude bands)

/// Procedural interior tuned to the reference video: cyan/teal left, peach/salmon right,
/// domain-warped cloud density, concentric topographic ripples, rim sparkles.
struct ReferenceOrbNebulaInterior: View {
    var diameter: CGFloat
    var phase: Double
    var glowPulse: Double
    var fillOpacity: CGFloat = 1

    private var useLiteInterior: Bool {
        OrbRenderBudget.usesLiteNebulaInterior(diameter, fillOpacity)
    }

    var body: some View {
        ZStack {
            referencePlanetBase
            referenceCoreRadiance

            if useLiteInterior {
                referenceLimbDarkening
            } else {
                ReferenceOrbNebulaVolumeField(
                    diameter: diameter,
                    phase: phase,
                    glowPulse: glowPulse
                )

                ReferenceOrbInteriorTopography(
                    diameter: diameter,
                    phase: phase,
                    glowPulse: glowPulse
                )

                ReferenceOrbSoftGlowPatches(
                    diameter: diameter,
                    phase: phase,
                    glowPulse: glowPulse
                )

                referenceLimbDarkening

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.32 * glowPulse),
                                BrandTheme.nebulaBeltHighlight.opacity(0.20 * glowPulse),
                                .clear,
                            ],
                            center: UnitPoint(x: 0.36, y: 0.38),
                            startRadius: 0,
                            endRadius: diameter * 0.28
                        )
                    )
                    .blur(radius: diameter * 0.038)
                    .blendMode(.plusLighter)

                ReferenceOrbRimSparkles(
                    diameter: diameter,
                    phase: phase,
                    glowPulse: glowPulse
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .drawingGroup(opaque: false, colorMode: .nonLinear)
    }

    private var referenceCoreRadiance: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(0.18 * glowPulse),
                        BrandTheme.nebulaCyan.opacity(0.24 * glowPulse),
                        BrandTheme.nebulaLavender.opacity(0.10),
                        .clear,
                    ],
                    center: UnitPoint(x: 0.42, y: 0.40),
                    startRadius: 0,
                    endRadius: diameter * 0.36
                )
            )
            .blur(radius: diameter * 0.042)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var referencePlanetBase: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.nebulaDeep.opacity(0.82),
                            BrandTheme.nebulaBeltShadow.opacity(0.72),
                            BrandTheme.nebulaPurple.opacity(0.52),
                            BrandTheme.nebulaDeep.opacity(0.78),
                        ],
                        center: UnitPoint(x: 0.48, y: 0.50),
                        startRadius: 0,
                        endRadius: diameter * 0.52
                    )
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.nebulaCyan.opacity(0.72 * glowPulse),
                            BrandTheme.nebulaTeal.opacity(0.42),
                            BrandTheme.nebulaBeltHighlight.opacity(0.12),
                            .clear,
                        ],
                        center: UnitPoint(x: 0.30, y: 0.40),
                        startRadius: 0,
                        endRadius: diameter * 0.50
                    )
                )
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.nebulaPeach.opacity(0.66 * glowPulse),
                            BrandTheme.nebulaSalmon.opacity(0.44),
                            BrandTheme.nebulaMagenta.opacity(0.16),
                            .clear,
                        ],
                        center: UnitPoint(x: 0.70, y: 0.42),
                        startRadius: 0,
                        endRadius: diameter * 0.48
                    )
                )
                .blendMode(.plusLighter)
        }
    }

    private var referenceLimbDarkening: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .clear,
                        .clear,
                        BrandTheme.nebulaDeep.opacity(0.10),
                        BrandTheme.nebulaDeep.opacity(0.26),
                        BrandTheme.nebulaDeep.opacity(0.42),
                    ],
                    center: .center,
                    startRadius: diameter * 0.22,
                    endRadius: diameter * 0.52
                )
            )
            .overlay {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                BrandTheme.nebulaCyan.opacity(0.38 * glowPulse),
                                BrandTheme.nebulaLavender.opacity(0.22),
                                BrandTheme.nebulaPeach.opacity(0.30 * glowPulse),
                                .white.opacity(0.18 * glowPulse),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.2, diameter * 0.004)
                    )
                    .blur(radius: max(0.8, diameter * 0.002))
            }
    }
}

// MARK: - Domain-warped volumetric nebula field

private struct ReferenceOrbNebulaVolumeField: View {
    var diameter: CGFloat
    var phase: Double
    var glowPulse: Double

    /// Per-cell sampling geometry is constant for a given canvas size — cache it so each frame
    /// only runs the (time-dependent) noise + fill, not the grid math and in-circle culling.
    private struct Cell {
        let nx: Double
        let ny: Double
        let splat: CGRect
    }

    private struct GridKey: Equatable {
        let w: CGFloat
        let h: CGFloat
        let cols: Int
    }
    private static var gridKey: GridKey?
    private static var gridCells: [Cell] = []

    private static func cells(for size: CGSize) -> [Cell] {
        let cols = OrbRenderBudget.nebulaGridColumns(for: size.width)
        let key = GridKey(w: size.width, h: size.height, cols: cols)
        if key == gridKey { return gridCells }

        let rows = cols
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(rows)
        let splatRadius = max(cellW, cellH) * 0.64

        var built: [Cell] = []
        built.reserveCapacity(cols * rows)
        for row in 0 ..< rows {
            for col in 0 ..< cols {
                let ux = (CGFloat(col) + 0.5) / CGFloat(cols)
                let uy = (CGFloat(row) + 0.5) / CGFloat(rows)
                let nx = Double((ux - 0.5) * 2)
                let ny = Double((uy - 0.5) * 2)
                if nx * nx + ny * ny > 1 { continue } // cull corners once, not every frame
                let cx = (CGFloat(col) + 0.5) * cellW
                let cy = (CGFloat(row) + 0.5) * cellH
                built.append(
                    Cell(
                        nx: nx,
                        ny: ny,
                        splat: CGRect(
                            x: cx - splatRadius,
                            y: cy - splatRadius,
                            width: splatRadius * 2,
                            height: splatRadius * 2
                        )
                    )
                )
            }
        }

        gridKey = key
        gridCells = built
        return built
    }

    var body: some View {
        Canvas { context, size in
            let time = phase * 0.22
            let secondaryTime = time * 0.72

            for cell in Self.cells(for: size) {
                let primary = ReferenceOrbNoise.warpedCloudDensity(
                    x: cell.nx * 1.15,
                    y: cell.ny * 1.15,
                    time: time,
                    seed: 0,
                    quality: .standard
                )
                let secondary = ReferenceOrbNoise.warpedCloudDensity(
                    x: cell.nx * 1.15,
                    y: cell.ny * 1.15,
                    time: secondaryTime,
                    seed: 41.7,
                    quality: .standard
                )
                let density = min(1, primary + secondary * 0.48)
                let (color, alpha) = ReferenceOrbPalette.nebulaSample(
                    nx: cell.nx,
                    ny: cell.ny,
                    density: density,
                    glowPulse: glowPulse
                )
                if alpha < 0.035 { continue }

                context.fill(Path(ellipseIn: cell.splat), with: .color(color.opacity(alpha * 0.78)))
            }
        }
        .compositingGroup()
        .blur(radius: OrbRenderBudget.nebulaVolumeBlurRadius(for: diameter))
        .allowsHitTesting(false)
    }
}

// MARK: - Concentric topographic ripples (reference video surface lines)

private struct ReferenceOrbInteriorTopography: View {
    var diameter: CGFloat
    var phase: Double
    var glowPulse: Double

    var body: some View {
        Canvas { context, size in
            let cx = size.width * 0.5
            let cy = size.height * 0.5
            let maxR = min(size.width, size.height) * 0.475
            let shimmer = 0.70 + 0.30 * glowPulse

            for ring in 1 ... 14 {
                let t = Double(ring) / 14.0
                let wobble = sin(phase * 0.55 + t * 11.2) * maxR * 0.012
                let radius = maxR * (0.42 + t * 0.56) + wobble
                let ringRect = CGRect(
                    x: cx - radius,
                    y: cy - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let strokeOpacity = (0.15 - t * 0.05) * shimmer
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(BrandTheme.nebulaCyan.opacity(strokeOpacity)),
                    lineWidth: max(0.35, diameter * 0.0012)
                )
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(.white.opacity(strokeOpacity * 0.35)),
                    lineWidth: max(0.55, diameter * 0.0018)
                )

                if ring.isMultiple(of: 4) {
                    let inset = radius - max(1.2, diameter * 0.0035)
                    if inset > radius * 0.55 {
                        let inner = CGRect(
                            x: cx - inset,
                            y: cy - inset,
                            width: inset * 2,
                            height: inset * 2
                        )
                        context.stroke(
                            Path(ellipseIn: inner),
                            with: .color(BrandTheme.nebulaLavender.opacity(strokeOpacity * 0.45)),
                            lineWidth: 0.28
                        )
                    }
                }
            }
        }
        .blur(radius: max(0.35, diameter * 0.0018))
        .allowsHitTesting(false)
    }
}

// MARK: - Soft drifting glow patches (subtle depth, not storm cells)

private struct ReferenceOrbSoftGlowPatches: View {
    var diameter: CGFloat
    var phase: Double
    var glowPulse: Double

    private struct Patch {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let speed: Double
        let seed: Double
        let tone: Int
    }

    private static let patches: [Patch] = [
        Patch(x: 0.28, y: 0.34, size: 0.38, speed: 0.42, seed: 1.2, tone: 0),
        Patch(x: 0.68, y: 0.40, size: 0.42, speed: 0.38, seed: 2.8, tone: 1),
        Patch(x: 0.52, y: 0.58, size: 0.28, speed: 0.51, seed: 4.1, tone: 2),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.patches.enumerated()), id: \.offset) { _, patch in
                let t = phase * patch.speed + patch.seed
                let driftX = CGFloat(cos(t) * 0.04) * diameter
                let driftY = CGFloat(sin(t * 1.14) * 0.035) * diameter
                let breathe = 0.92 + 0.08 * sin(t * 1.6)

                Circle()
                    .fill(patchGradient(tone: patch.tone))
                    .frame(width: diameter * patch.size * breathe, height: diameter * patch.size * breathe)
                    .offset(
                        x: (patch.x - 0.5) * diameter + driftX,
                        y: (patch.y - 0.5) * diameter + driftY
                    )
                    .blur(radius: diameter * 0.055)
            }
        }
        .allowsHitTesting(false)
    }

    private func patchGradient(tone: Int) -> RadialGradient {
        switch tone {
        case 0:
            return RadialGradient(
                colors: [
                    BrandTheme.nebulaCyan.opacity(0.48 * glowPulse),
                    BrandTheme.nebulaTeal.opacity(0.20),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.22
            )
        case 1:
            return RadialGradient(
                colors: [
                    BrandTheme.nebulaPeach.opacity(0.46 * glowPulse),
                    BrandTheme.nebulaSalmon.opacity(0.18),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.22
            )
        default:
            return RadialGradient(
                colors: [
                    BrandTheme.nebulaLavender.opacity(0.28 * glowPulse),
                    BrandTheme.nebulaPurple.opacity(0.10),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: diameter * 0.20
            )
        }
    }
}

// MARK: - Perimeter sparkles (reference clip rim points)

private struct ReferenceOrbRimSparkles: View {
    var diameter: CGFloat
    var phase: Double
    var glowPulse: Double

    private struct Dot {
        let angle: Double
        let radius: CGFloat
        let size: CGFloat
        let twinkle: Double
        let tone: Int
    }

    private static let dots: [Dot] = {
        var gen = ReferenceOrbSplitMix64(seed: 0xB075_7416)
        return (0 ..< 28).map { index in
            Dot(
                angle: Double.random(in: 0 ... (.pi * 2), using: &gen),
                radius: CGFloat.random(in: 0.36 ... 0.49, using: &gen),
                size: CGFloat.random(in: 1.0 ... 3.6, using: &gen),
                twinkle: Double.random(in: 1.4 ... 5.0, using: &gen) + Double(index) * 0.08,
                tone: Int.random(in: 0 ... 2, using: &gen)
            )
        }
    }()

    var body: some View {
        Canvas { context, size in
            let cx = size.width * 0.5
            let cy = size.height * 0.5

            for dot in Self.dots {
                let tw = (0.34 + 0.66 * pow(sin(phase * dot.twinkle), 2)) * glowPulse
                let drift = sin(phase * dot.twinkle * 0.35 + dot.angle) * 2.5
                let px = cx + CGFloat(cos(dot.angle) * Double(dot.radius)) * size.width * 0.5 + drift
                let py = cy + CGFloat(sin(dot.angle) * Double(dot.radius)) * size.height * 0.5
                let r = dot.size
                let rect = CGRect(x: px - r / 2, y: py - r / 2, width: r, height: r)
                let color: Color = switch dot.tone {
                case 0: BrandTheme.nebulaCyan
                case 1: BrandTheme.nebulaPeach
                default: .white
                }

                if r > 1.8 {
                    let halo = rect.insetBy(dx: -r * 0.75, dy: -r * 0.75)
                    context.fill(Path(ellipseIn: halo), with: .color(color.opacity(tw * 0.22)))
                }
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(tw)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Noise + palette helpers

private enum ReferenceOrbNoise {
    enum Quality { case standard, lite }

    static func sample(_ x: Double, _ y: Double, seed: Double) -> Double {
        let s = sin(x * 12.9898 + y * 78.233 + seed * 41.17) * 43_758.5453
        return s - floor(s)
    }

    static func fbm(_ x: Double, _ y: Double, seed: Double, octaves: Int = 3) -> Double {
        var amplitude = 0.5
        var frequency = 1.0
        var total = 0.0
        var norm = 0.0
        for index in 0 ..< octaves {
            total += amplitude * sample(x * frequency, y * frequency, seed: seed + Double(index) * 19.7)
            norm += amplitude
            amplitude *= 0.51
            frequency *= 2.17
        }
        return total / max(norm, 0.0001)
    }

    static func warpedCloudDensity(
        x: Double,
        y: Double,
        time: Double,
        seed: Double,
        quality: Quality = .standard
    ) -> Double {
        let qx = fbm(x * 1.55 + time * 0.07, y * 1.55 + seed, seed: 11.2 + seed, octaves: 2)
        let qy = fbm(x * 1.55 + seed + 4.8, y * 1.55 - time * 0.05, seed: 23.8 + seed, octaves: 2)
        let wx = x + (qx - 0.5) * 0.68
        let wy = y + (qy - 0.5) * 0.68
        let base = fbm(wx * 2.05 + time * 0.10, wy * 2.05 - time * 0.08, seed: 3.4 + seed, octaves: 3)
        guard quality == .standard else { return base }
        let detail = fbm(wx * 3.6 - time * 0.11, wy * 3.3 + time * 0.09, seed: 17.9 + seed, octaves: 2)
        return base * 0.78 + detail * 0.22
    }
}

private enum ReferenceOrbPalette {
    // This runs per grid cell (~2,000) every frame at 60fps for the persistent orb shell that's
    // present on every screen — the old `mix()` converted two `Color`s via `UIColor` on every
    // call (3 calls/cell here), i.e. ~700k `UIColor` conversions/sec running continuously across
    // the whole app. `nebulaDeep` is the only palette entry that needs a one-time UIColor
    // extraction (theme colors don't expose their raw components); everything else is already a
    // literal (r, g, b), so blending works entirely in plain tuples with a `Color` built once at
    // the end.
    private static let deepRGB: (r: Double, g: Double, b: Double) = rgbComponents(BrandTheme.nebulaDeep)

    static func nebulaSample(nx: Double, ny: Double, density: Double, glowPulse: Double) -> (Color, Double) {
        let lr = smoothstep(0.22, 0.78, (nx + 1) * 0.5 + (density - 0.5) * 0.38)
        let lift = density * (0.82 + 0.32 * glowPulse)

        let cyanMix = (r: 0.30 + lift * 0.12, g: 0.78 + lift * 0.10, b: 0.92)
        let tealMix = (r: 0.24, g: 0.68, b: 0.82)
        let lavenderMix = (r: 0.62, g: 0.52, b: 0.90)
        let peachMix = (r: 0.98, g: 0.64 + lift * 0.06, b: 0.50)
        let salmonMix = (r: 0.92, g: 0.54, b: 0.58)

        let leftTone = mix(cyanMix, tealMix, t: density * 0.55)
        let rightTone = mix(peachMix, salmonMix, t: density * 0.48)
        let bridge = mix(lavenderMix, deepRGB, t: 0.35 + density * 0.25)
        let blended = mix(mix(leftTone, bridge, t: lr * 0.42), rightTone, t: lr)
        let color = Color(red: blended.r, green: blended.g, blue: blended.b)

        let rim = 1 - pow(nx * nx + ny * ny, 0.94)
        let alpha = pow(max(0, density - 0.05), 0.98) * rim * (0.50 + 0.62 * glowPulse)
        return (color, alpha)
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - edge0) / max(0.0001, edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    private static func mix(
        _ a: (r: Double, g: Double, b: Double),
        _ b: (r: Double, g: Double, b: Double),
        t: Double
    ) -> (r: Double, g: Double, b: Double) {
        let u = min(1, max(0, t))
        return (
            a.r + (b.r - a.r) * u,
            a.g + (b.g - a.g) * u,
            a.b + (b.b - a.b) * u
        )
    }

    private static func rgbComponents(_ color: Color) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}

private struct ReferenceOrbSplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xBADC0FFE : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return z
    }
}
