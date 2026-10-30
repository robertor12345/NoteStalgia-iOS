import MetalKit
import SwiftUI
import UIKit

// The music equaliser as light.
//
// While a song plays, the ring of bars round a glyph or a listening orb is replaced by a glowing waveform that hugs the
// rim and sends wavefronts off it on the beat (`waveFragment` in OrbFlow.msl). This file is everything around the
// shader:
//
// * `OrbWaveModel` is the part that has to be right and can be tested: it smooths the 32 spectrum bands (quick to rise,
//   slower to fall), listens for a hit in the low bands, and keeps up to six live bursts — each with its age, its power
//   and a snapshot of the spectrum it was born with, so a wavefront keeps the music's shape as it spreads.
// * `OrbWaveBurstCanvas` is the MTKView that draws it on its own display link, so SwiftUI is never asked to redraw per
//   frame. Where Metal is unavailable the equaliser keeps its bars.

/// Smoothing, onset detection and burst bookkeeping for the wave equaliser. Pure: time and levels go in, uniforms come out.
struct OrbWaveModel {
    static let bandCount = 32
    static let burstSlots = 6
    /// Seconds a wavefront lives; the shader's own `life` is the same number.
    static let burstLife: Float = 1.7
    /// Header 8 + bands 32 + burst ages 6 + powers 6 + spectra 6 × 32.
    static let uniformFloatCount = 8 + bandCount + burstSlots * 2 + burstSlots * bandCount

    /// How quickly a band follows the music up, and back down.
    private static let attack: Float = 0.035
    private static let release: Float = 0.16
    /// A hit: the low bands rise this far above their own recent average, at least this loud, no sooner than the cooldown.
    private static let onsetRise: Float = 0.11
    private static let onsetFloor: Float = 0.25
    private static let cooldown: Float = 0.24
    /// With nothing to listen to (the synthetic motion), a wavefront every so often keeps the picture alive.
    private static let syntheticInterval: Float = 1.8

    private(set) var bands = [Float](repeating: 0, count: bandCount)
    private(set) var burstAge = [Float](repeating: -1, count: burstSlots)
    private(set) var burstPower = [Float](repeating: 0, count: burstSlots)
    private(set) var burstBands = [Float](repeating: 0, count: burstSlots * bandCount)
    private var lowAverage: Float = 0
    private var sinceBurst: Float = 10

    /// Mean level, 0…1.
    var energy: Float { bands.reduce(0, +) / Float(Self.bandCount) }

    var liveBurstCount: Int { burstAge.filter { $0 >= 0 }.count }

    /// Moves the picture `dt` seconds on towards `target` (32 levels, 0…1).
    mutating func advance(dt: Float, target: [Float], synthetic: Bool, bursts enabled: Bool) {
        let up = 1 - exp(-dt / Self.attack)
        let down = 1 - exp(-dt / Self.release)
        for index in 0 ..< Self.bandCount {
            let goal = index < target.count ? min(1, max(0, target[index])) : 0
            bands[index] += (goal - bands[index]) * (goal > bands[index] ? up : down)
        }

        for slot in 0 ..< Self.burstSlots where burstAge[slot] >= 0 {
            burstAge[slot] += dt
            if burstAge[slot] > Self.burstLife { burstAge[slot] = -1 }
        }

        sinceBurst += dt
        let low = bands[0 ..< 6].reduce(0, +) / 6
        let rise = low - lowAverage
        lowAverage += (low - lowAverage) * (1 - exp(-dt / 0.5))
        guard enabled else { return }
        if !synthetic, rise > Self.onsetRise, low > Self.onsetFloor, sinceBurst > Self.cooldown {
            spawn(power: min(1, max(0.45, 0.45 + rise * 2.5)))
        } else if synthetic, sinceBurst > Self.syntheticInterval {
            spawn(power: 0.6)
        }
    }

    private mutating func spawn(power: Float) {
        sinceBurst = 0
        // A free slot, or the oldest wavefront (the one closest to gone).
        let slot = burstAge.firstIndex { $0 < 0 } ?? burstAge.indices.max { burstAge[$0] < burstAge[$1] } ?? 0
        burstAge[slot] = 0
        burstPower[slot] = power
        for index in 0 ..< Self.bandCount { burstBands[slot * Self.bandCount + index] = bands[index] }
    }

    /// The shader's `WaveUniforms`, in its order: size, time, orbR, reach, frac, energy, seed, bands, ages, powers, spectra.
    func pack(size: SIMD2<Float>, time: Float, orbRadius: Float, reach: Float, openness: Float, seed: Float) -> [Float] {
        var out = [Float]()
        out.reserveCapacity(Self.uniformFloatCount)
        out += [size.x, size.y, time, orbRadius, reach, openness, energy, seed]
        out += bands
        out += burstAge
        out += burstPower
        out += burstBands
        return out
    }
}

struct OrbWaveParameters: Equatable {
    /// Side of the square canvas, in points.
    var canvas: CGFloat
    /// The glyph's (or orb's) radius, in points.
    var orbRadius: CGFloat
    /// Outward reach as a fraction of the orb radius.
    var reach: CGFloat
    /// 0…1 openness (discovery ramps it while a clip plays).
    var openness: CGFloat
    var reactsToMusic: Bool
    /// Stay flat until live levels arrive, rather than moving on the synthetic motion.
    var liveAudioOnly: Bool
    /// Injected levels, preferred over the bus when given.
    var bandLevels: [CGFloat]?
    var gain: CGFloat
    var exponent: CGFloat
    var floor: CGFloat
    var paused: Bool
    var framesPerSecond: Int = 60
}

struct OrbWaveBurstCanvas: UIViewRepresentable {
    var parameters: OrbWaveParameters

    func makeCoordinator() -> Coordinator { Coordinator(parameters) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: OrbMetalPipeline.shared.device ?? MTLCreateSystemDefaultDevice())
        view.delegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.layer.isOpaque = false
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isUserInteractionEnabled = false
        view.enableSetNeedsDisplay = false
        apply(parameters, to: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.parameters = parameters
        apply(parameters, to: view)
    }

    private func apply(_ p: OrbWaveParameters, to view: MTKView) {
        // A soft glow: below the screen scale loses nothing and keeps a big canvas cheap.
        let maxPixels: CGFloat = 2_200_000
        let scale = min(UIScreen.main.scale, max(1, (maxPixels / max(p.canvas * p.canvas, 1)).squareRoot()))
        if abs(view.contentScaleFactor - scale) > 0.01 { view.contentScaleFactor = scale }
        view.preferredFramesPerSecond = p.framesPerSecond
        view.isPaused = p.paused
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        var parameters: OrbWaveParameters
        private var model = OrbWaveModel()
        private var lastDraw: CFTimeInterval = 0

        init(_ parameters: OrbWaveParameters) { self.parameters = parameters }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            let shared = OrbMetalPipeline.shared
            guard let pipeline = shared.wavePipeline, let queue = shared.queue,
                  let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
                  let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
            let p = parameters
            let now = CACurrentMediaTime()
            // A paused or hitching canvas picks up where it left off rather than lurching: one step is never long.
            let dt = lastDraw == 0 ? 1.0 / 60.0 : min(0.05, max(0.001, now - lastDraw))
            lastDraw = now

            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            let clock = OrbClock.shared.now(wall: now)
            let (target, synthetic) = targetLevels(clock: clock)
            // Reduce Motion keeps the level (it is information) but sends no travelling wavefronts.
            model.advance(dt: Float(dt), target: target, synthetic: synthetic, bursts: !reduceMotion)

            let radius = Float(p.orbRadius / max(p.canvas * 0.5, 1))
            var uniforms = model.pack(
                size: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                time: Float(reduceMotion ? 2 : clock),
                orbRadius: radius,
                reach: Float(p.reach),
                openness: Float(min(1, max(0, p.openness))),
                seed: 0.17
            )
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: uniforms.count * MemoryLayout<Float>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }

        /// What the bands are heading for this frame, and whether it is the synthetic motion rather than the music.
        private func targetLevels(clock: Double) -> ([Float], Bool) {
            let p = parameters
            let open = Float(min(1, max(0, p.openness)))
            func shaped(_ raw: CGFloat) -> Float {
                let level = min(1, pow(max(0, raw), p.exponent) * p.gain)
                return max(Float(p.floor), Float(level)) * open
            }
            if let injected = p.bandLevels, injected.count >= OrbWaveModel.bandCount {
                return (injected.prefix(OrbWaveModel.bandCount).map(shaped), false)
            }
            if p.reactsToMusic {
                let snapshot = MusicReactiveBus.shared.snapshot
                if snapshot.isActive, snapshot.bands.count >= OrbWaveModel.bandCount {
                    return (snapshot.bands.prefix(OrbWaveModel.bandCount).map(shaped), false)
                }
            }
            if p.liveAudioOnly {
                return (Array(repeating: Float(p.floor) * open, count: OrbWaveModel.bandCount), false)
            }
            let synthetic = (0 ..< OrbWaveModel.bandCount).map { index in
                Float(OrbEqualizerMotion.barAmplified(index: index, phase: clock, listenProgress: CGFloat(open)))
            }
            return (synthetic, true)
        }
    }
}

/// The wave equaliser as a view: pauses with the app, sized like the bars it replaces.
struct OrbWaveBurstView: View {
    var parameters: OrbWaveParameters
    @Environment(\.scenePhase) private var scenePhase

    private var effective: OrbWaveParameters {
        var p = parameters
        p.paused = p.paused || scenePhase != .active
        return p
    }

    var body: some View {
        OrbWaveBurstCanvas(parameters: effective)
            .frame(width: parameters.canvas, height: parameters.canvas)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
