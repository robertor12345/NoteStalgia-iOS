import MetalKit
import SwiftUI
import UIKit

// The orb on the GPU.
//
// `App/Resources/Shaders/OrbFlow.msl` draws the whole orb — flowing silk, rim light, corona, heartbeat ripple — in one
// pass per pixel. This file owns everything around it:
//
// * `OrbMetalPipeline` compiles the shader once, off the main thread, and falls back to the CPU orb when Metal is
//   missing or the compile fails (`-NoteStalgiaOrbRenderer classic` forces that for back-to-back comparison).
// * `OrbMetalCanvas` is the live orb: an `MTKView` on its own display link. The breathing, the glow and the swirl are
//   computed in its draw loop from the same `OrbHeartbeat` the CPU orb uses, so SwiftUI is never asked to re-evaluate
//   anything per frame — the main thread only encodes one draw call. It pauses with the keyboard, while a list scrolls
//   and in the background, exactly where the CPU orb did.
// * Small orbs (under `snapshotMaxDiameter`) are rendered once into an image and cached: a screen of resident
//   portraits would otherwise need a GPU view per row.

/// Mirror of `OrbUniforms` in OrbFlow.msl — 8 + 10 × 4 = 48 bytes. Keep the order.
struct OrbMetalUniforms {
    var size: SIMD2<Float>
    var time: Float
    var pulse: Float
    var glow: Float
    var energy: Float
    var brightness: Float
    var radius: Float
    var detail: Float
    var seed: Float
    var beat: Float
    var fill: Float
}

/// The orb's animation time. It follows the wall clock while an orb is drawing and stands still while none is, so an
/// orb that pauses (a list scrolling, the keyboard up, the app inactive) carries on from the frame it stopped on.
/// Reading the wall clock instead made every resume a jump: after a two second pause the swirl and the breath were a
/// third of a cycle away from the last frame on screen, and the orb visibly snapped. One step is never longer than
/// `maxStep`, which is also what hides an ordinary hitch.
@MainActor
final class OrbClock {
    static let shared = OrbClock()
    /// The longest a single read may advance the clock.
    static let maxStep: CFTimeInterval = 0.05

    private var lastWall: CFTimeInterval?
    private var seconds: Double = 0

    /// Animation seconds since the first orb drew. Every orb on screen reads the same clock, so they breathe together.
    func now(wall: CFTimeInterval = CACurrentMediaTime()) -> Double {
        if let lastWall {
            seconds += min(max(wall - lastWall, 0), Self.maxStep)
        }
        lastWall = wall
        return seconds
    }
}

@MainActor
final class OrbMetalPipeline: ObservableObject {
    enum Phase { case idle, preparing, ready, unavailable }

    static let shared = OrbMetalPipeline()
    /// `-NoteStalgiaOrbRenderer classic` keeps the CPU orb (for A/B measurement).
    static let forcedClassic = UserDefaults.standard.string(forKey: "NoteStalgiaOrbRenderer") == "classic"
    /// The CPU orb stands still while a list scrolls or the keyboard is up, because redrawing it competes with that work
    /// on the main thread. The GPU orb costs a fraction of a millisecond, so by default it keeps breathing behind the
    /// page; `-NoteStalgiaOrbPauseOnInteraction YES` brings the old behaviour back for comparison. (Backgrounding still
    /// stops it, and either way it carries on from where it stopped — see `OrbClock`.)
    static let pausesForInteraction = UserDefaults.standard.bool(forKey: "NoteStalgiaOrbPauseOnInteraction")
    /// Orbs smaller than this are drawn once and cached instead of running a live GPU view.
    static let snapshotMaxDiameter: CGFloat = 160
    /// The canvas is this many times the orb's diameter, so the corona and the ripple have room.
    static let canvasScale: CGFloat = 1.6

    /// One clock for every orb that is not given its own anchor, so rebuilding a view never restarts the breath.
    static let clockAnchor = Date()

    @Published private(set) var phase: Phase = .idle
    private(set) var device: MTLDevice?
    private(set) var queue: MTLCommandQueue?
    private(set) var pipeline: MTLRenderPipelineState?
    /// The music equaliser's wave bursts (`waveFragment`). Optional: without it the equaliser keeps its bars.
    private(set) var wavePipeline: MTLRenderPipelineState?
    /// The tap pulse sprite (`tapFragment`).
    private(set) var tapPipeline: MTLRenderPipelineState?

    private init() {}

    /// Metal is, or is about to be, the renderer — the CPU orb is only used when this is false.
    var usesMetal: Bool { !Self.forcedClassic && phase != .unavailable }
    var isReady: Bool { phase == .ready }
    /// The equaliser can draw waves rather than bars.
    var usesWaves: Bool { phase == .ready && wavePipeline != nil }

    /// Compiles the shader on a background queue. Cheap to call more than once.
    func prepare() {
        guard phase == .idle else { return }
        guard !Self.forcedClassic, let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let source = Self.loadSource() else {
            phase = .unavailable
            return
        }
        phase = .preparing
        DispatchQueue.global(qos: .userInitiated).async {
            let started = CFAbsoluteTimeGetCurrent()
            var built: MTLRenderPipelineState?
            var builtWaves: MTLRenderPipelineState?
            var builtTap: MTLRenderPipelineState?
            do {
                let library = try device.makeLibrary(source: source, options: nil)
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: "orbVertex")
                descriptor.fragmentFunction = library.makeFunction(name: "orbFragment")
                descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                built = try device.makeRenderPipelineState(descriptor: descriptor)
                if let waves = library.makeFunction(name: "waveFragment") {
                    descriptor.fragmentFunction = waves
                    builtWaves = try? device.makeRenderPipelineState(descriptor: descriptor)
                }
                if let tap = library.makeFunction(name: "tapFragment") {
                    descriptor.fragmentFunction = tap
                    builtTap = try? device.makeRenderPipelineState(descriptor: descriptor)
                }
            } catch {
                NSLog("OrbMetalPipeline: shader compile failed — falling back to the CPU orb. \(error)")
            }
            let milliseconds = (CFAbsoluteTimeGetCurrent() - started) * 1000
            DispatchQueue.main.async {
                let pipeline = OrbMetalPipeline.shared
                guard let built else {
                    pipeline.phase = .unavailable
                    return
                }
                pipeline.device = device
                pipeline.queue = queue
                pipeline.pipeline = built
                pipeline.wavePipeline = builtWaves
                pipeline.tapPipeline = builtTap
                pipeline.phase = .ready
                DemoAudioLog.record("orb.metal.ready", ["compileMs": (milliseconds * 10).rounded() / 10])
            }
        }
    }

    /// `-NoteStalgiaOrbShaderPath /path/OrbFlow.msl` loads the shader from disk (live iteration in the simulator).
    private static func loadSource() -> String? {
        if let path = UserDefaults.standard.string(forKey: "NoteStalgiaOrbShaderPath"),
           let text = try? String(contentsOfFile: path, encoding: .utf8) {
            return text
        }
        for subdirectory in ["Resources/Shaders", "Shaders", "Resources", nil] as [String?] {
            if let url = Bundle.main.url(forResource: "OrbFlow", withExtension: "msl", subdirectory: subdirectory),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
}

// MARK: - Live orb

/// What drives the orb's breathing.
struct OrbMetalDrive: Equatable {
    /// `true`: the draw loop derives pulse and glow from the 6 s heartbeat (and live music). `false`: the parent's values.
    var heartbeat: Bool
    var pulse: Double = 0.5
    var glow: Double = 0.72

    static let heartbeat = OrbMetalDrive(heartbeat: true)
    static func fixed(pulse: Double, glow: Double) -> OrbMetalDrive { OrbMetalDrive(heartbeat: false, pulse: pulse, glow: glow) }
}

struct OrbMetalParameters: Equatable {
    /// The orb's diameter at rest, in points (before the breathing scale).
    var restingDiameter: CGFloat
    /// Side of the square canvas, in points.
    var canvas: CGFloat
    var drive: OrbMetalDrive
    var anchor: Date
    var speed: Double = 1
    var brightness: CGFloat = 1
    var fill: CGFloat = 1
    var glowBoost: CGFloat = 1
    var seed: Double = 0
    var detailed: Bool = true
    /// Reduce Motion and the demo freeze: draw one frame and hold it.
    var still: Bool = false
    /// Keyboard up, list scrolling, app in the background: stop drawing, keep the last frame.
    var paused: Bool = false
    var framesPerSecond: Int = 60
}

struct OrbMetalCanvas: UIViewRepresentable {
    var parameters: OrbMetalParameters

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
        apply(parameters, to: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.parameters = parameters
        apply(parameters, to: view)
    }

    private func apply(_ p: OrbMetalParameters, to view: MTKView) {
        // The glow is soft: rendering below the screen scale loses nothing and keeps a large orb cheap.
        let maxPixels: CGFloat = 2_200_000
        let scale = min(UIScreen.main.scale, max(1, (maxPixels / max(p.canvas * p.canvas, 1)).squareRoot()))
        if abs(view.contentScaleFactor - scale) > 0.01 { view.contentScaleFactor = scale }
        view.preferredFramesPerSecond = p.framesPerSecond
        if p.still {
            view.enableSetNeedsDisplay = true
            view.isPaused = true
            view.setNeedsDisplay()
        } else {
            view.enableSetNeedsDisplay = false
            view.isPaused = p.paused
        }
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        var parameters: OrbMetalParameters

        // Music-driven pulsing is eased in and out, and the audio values (published 24–48 times a second) are low-passed
        // per frame, so neither a song starting nor the audio's own cadence ever shows as a step in the breathing.
        private var musicWeight = 0.0
        private var musicPulse = 0.5
        private var musicGlow = 0.72
        private var musicEnergy = 0.0
        private var lastDraw: CFTimeInterval = 0

        init(_ parameters: OrbMetalParameters) { self.parameters = parameters }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            let shared = OrbMetalPipeline.shared
            guard let pipeline = shared.pipeline, let queue = shared.queue,
                  let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor,
                  let buffer = queue.makeCommandBuffer(), let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
            var uniforms = makeUniforms(drawableSize: view.drawableSize)
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<OrbMetalUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            buffer.present(drawable)
            if OrbFrameMonitor.isEnabled {
                OrbFrameMonitor.shared.noteShellDraw()
                buffer.addCompletedHandler { completed in
                    let nanos = UInt64(max(0, completed.gpuEndTime - completed.gpuStartTime) * 1_000_000_000)
                    Task { @MainActor in OrbFrameMonitor.shared.noteGPU(nanoseconds: nanos) }
                }
            }
            buffer.commit()
        }

        private func makeUniforms(drawableSize: CGSize) -> OrbMetalUniforms {
            let p = parameters
            let now = CACurrentMediaTime()
            let dt = lastDraw == 0 ? 1.0 / 60.0 : min(0.1, max(0.001, now - lastDraw))
            lastDraw = now

            let elapsed = p.still ? 2.0 : OrbClock.shared.now(wall: now) * p.speed
            var pulse = p.drive.pulse
            var glow = p.drive.glow
            var energy = 0.0
            if p.drive.heartbeat {
                let base = OrbPulseSample.sample(at: elapsed, mode: .calm, reduceMotion: p.still)
                let music = MusicReactiveBus.shared.snapshot
                let active = music.isActive && !p.still
                if active, musicWeight < 0.01 {
                    // Start from where the heartbeat is, so the hand-over has nothing to jump from.
                    musicPulse = base.pulse
                    musicGlow = base.glowPulse
                    musicEnergy = 0
                }
                musicWeight += ((active ? 0.82 : 0) - musicWeight) * (1 - exp(-dt / (active ? 0.30 : 0.60)))
                if active {
                    let follow = 1 - exp(-dt / 0.07)
                    musicPulse += (music.pulse - musicPulse) * follow
                    musicGlow += (music.glow - musicGlow) * follow
                    let mean = music.bands.reduce(0, +) / CGFloat(max(1, music.bands.count))
                    musicEnergy += (Double(min(1, max(0, (mean - 0.15) / 0.55))) - musicEnergy) * follow
                }
                pulse = base.pulse * (1 - musicWeight) + musicPulse * musicWeight
                glow = base.glowPulse * (1 - musicWeight) + musicGlow * musicWeight
                energy = musicEnergy * min(1, musicWeight / 0.82)
            }
            let cycle = OrbHeartbeat.breatheCycleSeconds
            let beat = p.drive.heartbeat && !p.still ? elapsed.truncatingRemainder(dividingBy: cycle) / cycle : 0.4999
            let shellScale = OrbHeartbeat.shellScale(forPulse: pulse)
            return OrbMetalUniforms(
                size: SIMD2(Float(drawableSize.width), Float(drawableSize.height)),
                time: Float(elapsed + p.seed * 37),
                pulse: Float(pulse),
                glow: Float(min(1.1, glow * Double(p.glowBoost))),
                energy: Float(energy),
                brightness: Float(p.brightness),
                radius: Float(p.restingDiameter * shellScale / max(p.canvas, 1)),
                detail: p.detailed ? 1 : 0,
                seed: Float(p.seed),
                beat: Float(beat),
                fill: Float(p.fill)
            )
        }
    }
}

// MARK: - Snapshots for small orbs

@MainActor
enum OrbSnapshotCache {
    private static var cache: [String: UIImage] = [:]

    /// A rendered orb (with its corona) for a small diameter, or nil until the shader is ready.
    static func image(diameter: CGFloat, pulse: Double, glow: Double, brightness: CGFloat, scale: CGFloat) -> UIImage? {
        let shared = OrbMetalPipeline.shared
        guard shared.isReady, let device = shared.device, let queue = shared.queue, let pipeline = shared.pipeline else { return nil }
        let bucket = max(8, (diameter / 2).rounded() * 2)
        let key = "\(Int(bucket))|\(Int((pulse * 10).rounded()))|\(Int((glow * 10).rounded()))|\(Int((brightness * 100).rounded()))|\(Int(scale))"
        if let hit = cache[key] { return hit }

        let canvas = bucket * OrbMetalPipeline.canvasScale
        let pixels = max(32, Int((canvas * scale).rounded()))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: pixels, height: pixels, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor), let buffer = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.colorAttachments[0].storeAction = .store
        var uniforms = OrbMetalUniforms(
            size: SIMD2(Float(pixels), Float(pixels)), time: 14.5, pulse: Float(pulse), glow: Float(glow), energy: 0.05,
            brightness: Float(brightness), radius: Float(bucket * OrbHeartbeat.shellScale(forPulse: pulse) / canvas),
            detail: bucket >= 90 ? 1 : 0, seed: 0.3, beat: 0.4999, fill: 1
        )
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<OrbMetalUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: pixels * pixels * 4)
        texture.getBytes(&bytes, bytesPerRow: pixels * 4, from: MTLRegionMake2D(0, 0, pixels, pixels), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cg = CGImage(
                width: pixels, height: pixels, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: pixels * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        let image = UIImage(cgImage: cg, scale: scale, orientation: .up)
        cache[key] = image
        return image
    }
}

// MARK: - The tap pulse sprite

/// The screen-tap pulse, rendered once by the GPU from the same shader as the equaliser's wave bursts. `nil` until the
/// shader is ready; the tap pulse draws its CPU artwork until then.
@MainActor
enum OrbTapSprite {
    private static var cache: [Int: UIImage] = [:]

    static func image(canvas: CGFloat, scale: CGFloat) -> UIImage? {
        let shared = OrbMetalPipeline.shared
        guard shared.isReady, let device = shared.device, let queue = shared.queue, let pipeline = shared.tapPipeline else { return nil }
        let pixels = max(32, Int((canvas * scale).rounded()))
        if let hit = cache[pixels] { return hit }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: pixels, height: pixels, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor), let buffer = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setRenderPipelineState(pipeline)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()

        var bytes = [UInt8](repeating: 0, count: pixels * pixels * 4)
        texture.getBytes(&bytes, bytesPerRow: pixels * 4, from: MTLRegionMake2D(0, 0, pixels, pixels), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cg = CGImage(
                width: pixels, height: pixels, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: pixels * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }
        let image = UIImage(cgImage: cg, scale: scale, orientation: .up)
        cache[pixels] = image
        return image
    }
}

// MARK: - SwiftUI composite

/// The orb as the rest of the app sees it: layout is unchanged (`visualHeadroom` times the diameter); the canvas, which is
/// larger, overflows it on purpose so the corona is not clipped.
struct NoteStalgiaMetalOrb: View {
    var baseDiameter: CGFloat
    var drive: OrbMetalDrive
    var anchor: Date
    var brightness: CGFloat = 1
    var fill: CGFloat = 1
    var glowBoost: CGFloat = 1
    var seed: Double = 0
    /// Held from outside (keyboard up, list scrolling).
    var externallyPaused: Bool = false

    @ObservedObject private var pipeline = OrbMetalPipeline.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    @State private var turn: Double = 0

    private static let smallOrbCeiling: CGFloat = 0.56

    private var canvas: CGFloat { baseDiameter * OrbMetalPipeline.canvasScale * OrbHeartbeat.maxShellScale }

    var body: some View {
        Group {
            if baseDiameter < OrbMetalPipeline.snapshotMaxDiameter {
                smallOrb
            } else {
                liveOrb
            }
        }
        .frame(width: baseDiameter * OrbHeartbeat.visualHeadroom, height: baseDiameter * OrbHeartbeat.visualHeadroom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var liveOrb: some View {
        OrbMetalCanvas(parameters: OrbMetalParameters(
            restingDiameter: baseDiameter,
            canvas: canvas,
            drive: drive,
            anchor: anchor,
            brightness: brightness,
            fill: fill,
            glowBoost: glowBoost,
            seed: seed,
            detailed: true,
            still: reduceMotion || DemoLaunchOptions.freezeOrb,
            paused: externallyPaused || scenePhase != .active,
            // Follows the display, as the CPU orb did: 120 Hz on ProMotion iPads, 60 elsewhere.
            framesPerSecond: min(120, UIScreen.main.maximumFramesPerSecond)
        ))
        .frame(width: canvas, height: canvas)
        // The first frames wait for the shader: fade the orb in rather than popping.
        .opacity(pipeline.isReady ? 1 : 0)
        .animation(.easeOut(duration: 0.6), value: pipeline.isReady)
    }

    @ViewBuilder
    private var smallOrb: some View {
        let side = baseDiameter * OrbMetalPipeline.canvasScale
        // Small orbs carry labels, icons or portraits (mood bubbles, nav tiles, portrait rings): they use the jewel-tone ceiling
        // so white text on them keeps its contrast; only the big orb on a page that is all orb goes fully pastel.
        if let image = OrbSnapshotCache.image(diameter: baseDiameter, pulse: drive.pulse, glow: drive.glow * Double(glowBoost), brightness: min(brightness, Self.smallOrbCeiling), scale: displayScale) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: side, height: side)
                .opacity(Double(fill))
                // A very slow turn keeps the small orbs alive; it runs in the render server, not on the main thread.
                .rotationEffect(.degrees(reduceMotion ? 0 : turn))
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) { turn = 360 }
                }
        } else {
            Color.clear.frame(width: side, height: side)
        }
    }
}
