import Metal
import XCTest
@testable import NoteStalgia_iOS

/// The orb is drawn by `App/Resources/Shaders/OrbFlow.msl`, compiled at runtime. Nothing at build time checks it, so
/// these tests do: a typo in the shader, or the Swift and Metal uniform structs drifting apart, would otherwise show up
/// as an orb that silently never appears (the app then falls back to the CPU orb).
final class OrbShaderTests: XCTestCase {
    private var shaderURL: URL {
        // Tests/ → repo root → App/Resources/Shaders/OrbFlow.msl
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Resources/Shaders/OrbFlow.msl")
    }

    func testUniformsMatchTheShaderStruct() {
        // 8 (float2) + ten floats, in the order of `OrbUniforms` in OrbFlow.msl.
        XCTAssertEqual(MemoryLayout<OrbMetalUniforms>.stride, 48)
        XCTAssertEqual(MemoryLayout<OrbMetalUniforms>.offset(of: \.time), 8)
        XCTAssertEqual(MemoryLayout<OrbMetalUniforms>.offset(of: \.fill), 44)
    }

    func testTheShaderCompilesAndHasBothFunctions() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device on this host") }
        let source = try String(contentsOf: shaderURL, encoding: .utf8)
        let library = try device.makeLibrary(source: source, options: nil)
        XCTAssertNotNil(library.makeFunction(name: "orbVertex"))
        XCTAssertNotNil(library.makeFunction(name: "orbFragment"))
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "orbVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "orbFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        XCTAssertNoThrow(try device.makeRenderPipelineState(descriptor: descriptor))
        // The equaliser's wave bursts live in the same file.
        XCTAssertNotNil(library.makeFunction(name: "waveFragment"))
        descriptor.fragmentFunction = library.makeFunction(name: "waveFragment")
        XCTAssertNoThrow(try device.makeRenderPipelineState(descriptor: descriptor))
        // And the tap pulse's sprite.
        XCTAssertNotNil(library.makeFunction(name: "tapFragment"))
        descriptor.fragmentFunction = library.makeFunction(name: "tapFragment")
        XCTAssertNoThrow(try device.makeRenderPipelineState(descriptor: descriptor))
    }

    func testWaveUniformsMatchTheShaderStruct() {
        // 8 header floats, 32 bands, 6 ages, 6 powers, 6 × 32 spectra = 244 floats, 976 bytes: `WaveUniforms` in OrbFlow.msl.
        XCTAssertEqual(OrbWaveModel.uniformFloatCount, 244)
        let packed = OrbWaveModel().pack(size: SIMD2(100, 100), time: 3, orbRadius: 0.4, reach: 1, openness: 1, seed: 0.2)
        XCTAssertEqual(packed.count * MemoryLayout<Float>.stride, 976)
        XCTAssertEqual(Array(packed[0 ..< 8]), [100, 100, 3, 0.4, 1, 1, 0, 0.2])
        // No bursts yet: every age is the "unused" -1.
        XCTAssertEqual(Array(packed[40 ..< 46]), Array(repeating: -1, count: 6))
        XCTAssertTrue(try String(contentsOf: shaderURL, encoding: .utf8).contains("float  burstBands[192];"))
    }

    func testWaveBandsRiseQuicklyAndFallSlowly() {
        var model = OrbWaveModel()
        let loud = Array(repeating: Float(1), count: 32)
        model.advance(dt: 1.0 / 60, target: loud, synthetic: false, bursts: false)
        let afterOneFrame = model.bands[10]
        XCTAssertGreaterThan(afterOneFrame, 0.3)
        for _ in 0 ..< 30 { model.advance(dt: 1.0 / 60, target: loud, synthetic: false, bursts: false) }
        let peak = model.bands[10]
        model.advance(dt: 1.0 / 60, target: Array(repeating: 0, count: 32), synthetic: false, bursts: false)
        XCTAssertGreaterThan(model.bands[10], peak * 0.8, "release is slower than attack")
    }

    func testAHitInTheLowBandsSendsOneWavefrontAndRespectsTheCooldown() {
        var model = OrbWaveModel()
        let quiet = Array(repeating: Float(0.05), count: 32)
        for _ in 0 ..< 60 { model.advance(dt: 1.0 / 60, target: quiet, synthetic: false, bursts: true) }
        XCTAssertEqual(model.liveBurstCount, 0)
        let hit = Array(repeating: Float(0.9), count: 32)
        for _ in 0 ..< 6 { model.advance(dt: 1.0 / 60, target: hit, synthetic: false, bursts: true) }
        XCTAssertEqual(model.liveBurstCount, 1, "one hit, one wavefront, however many frames it spans")
        XCTAssertGreaterThanOrEqual(model.burstPower.max() ?? 0, 0.45)
        // The wavefront keeps the spectrum it was born with.
        let slot = model.burstAge.firstIndex { $0 >= 0 }!
        XCTAssertGreaterThan(model.burstBands[slot * 32 + 5], 0.3)
    }

    func testWavefrontsExpireAndNoneAreSentWhenMotionIsReduced() {
        var model = OrbWaveModel()
        let hit = Array(repeating: Float(0.9), count: 32)
        for _ in 0 ..< 10 { model.advance(dt: 1.0 / 60, target: Array(repeating: 0.05, count: 32), synthetic: false, bursts: true) }
        for _ in 0 ..< 5 { model.advance(dt: 1.0 / 60, target: hit, synthetic: false, bursts: true) }
        XCTAssertEqual(model.liveBurstCount, 1)
        for _ in 0 ..< 120 { model.advance(dt: 1.0 / 60, target: Array(repeating: 0.05, count: 32), synthetic: false, bursts: true) }
        XCTAssertEqual(model.liveBurstCount, 0, "gone after its \(OrbWaveModel.burstLife) s life")

        var still = OrbWaveModel()
        for _ in 0 ..< 10 { still.advance(dt: 1.0 / 60, target: Array(repeating: 0.05, count: 32), synthetic: false, bursts: false) }
        for _ in 0 ..< 30 { still.advance(dt: 1.0 / 60, target: hit, synthetic: false, bursts: false) }
        XCTAssertEqual(still.liveBurstCount, 0)
    }

    @MainActor
    func testTheClockCarriesOnFromWhereAPauseLeftIt() {
        let clock = OrbClock()
        XCTAssertEqual(clock.now(wall: 100), 0, accuracy: 1e-9)
        XCTAssertEqual(clock.now(wall: 100.0167), 0.0167, accuracy: 1e-9)
        // Three seconds with nothing drawing (a list scrolling, the keyboard up): the orb resumes within one step of the
        // frame it stopped on, not three seconds further round its breath.
        let before = clock.now(wall: 100.0334)
        let after = clock.now(wall: 103.0334)
        XCTAssertLessThanOrEqual(after - before, OrbClock.maxStep + 1e-9)
        // And an ordinary 60 fps frame afterwards is just a frame.
        XCTAssertEqual(clock.now(wall: 103.0501) - after, 0.0167, accuracy: 1e-6)
        // Time never runs backwards.
        XCTAssertGreaterThanOrEqual(clock.now(wall: 90), clock.now(wall: 90))
    }

    func testTheBreathingKeepsTheOrbInsideItsCanvas() {
        // The corona needs room: at the largest breath the orb must still leave the canvas margin it was designed with.
        let largest = OrbHeartbeat.shellScale(forPulse: 1) * OrbHeartbeat.maxShellScale / OrbHeartbeat.maxShellScale
        let canvas = OrbMetalPipeline.canvasScale * OrbHeartbeat.maxShellScale
        XCTAssertLessThanOrEqual(largest / canvas, 0.66)
    }
}
