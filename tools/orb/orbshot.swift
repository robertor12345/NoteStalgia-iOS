// orbshot — renders App/Resources/Shaders/OrbFlow.msl to PNG on the Mac, for developing the orb's look
// without rebuilding the app.
//
//   swiftc -O tools/orb/orbshot.swift -o /tmp/orbshot
//   /tmp/orbshot App/Resources/Shaders/OrbFlow.msl /tmp/orb.png --times 0,1.5,3,4.5,6,7.5 --size 420
//
// Scan mode: `--scan` renders consecutive frames (default 0–13 s at 120 fps, 160 px) and reports the largest
//   frame-to-frame changes, to prove an animation loops without a jump:
//   /tmp/orbshot App/Resources/Shaders/OrbFlow.msl /tmp/scan.png --scan [--scan-from 0 --scan-to 13 --scan-fps 120]
// Wave mode: `--wave` renders the music equaliser (waveFragment) over a stand-in glyph disk with synthetic spectra
//   and bursts, for tuning its look: /tmp/orbshot App/Resources/Shaders/OrbFlow.msl /tmp/wave.png --wave --times 0,0.4,0.8,1.2
// Options: --size <px per frame>  --cols <n>  --times <t1,t2,…>  --bg <hex>  --brightness <f>  --pulse <f>
//          --glow <f>  --energy <f>  --detail <0|1>  --radius <f>  --seed <f>  --fill <f>
// The frames are composited over the background colour and tiled into one PNG. Pass `--time-pulse` to derive
// pulse and glow from the time the way the app's 6 s breath does.

import CoreGraphics
import Foundation
import ImageIO
import Metal

struct Uniforms {
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

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else { fail("usage: orbshot <OrbFlow.msl> <out.png> [options]") }
let shaderPath = args.removeFirst()
let outPath = args.removeFirst()

func option(_ name: String, default value: String) -> String {
    if let i = args.firstIndex(of: "--" + name), i + 1 < args.count { return args[i + 1] }
    return value
}

let frameSize = Int(option("size", default: "420"))!
let times = option("times", default: "0,1.5,3,4.5,6,7.5").split(separator: ",").map { Float($0)! }
let cols = Int(option("cols", default: "\(min(times.count, 3))"))!
let bgHex = option("bg", default: "2c2960")
let brightness = Float(option("brightness", default: "1"))!
let energy = Float(option("energy", default: "0.15"))!
let detail = Float(option("detail", default: "1"))!
let radius = Float(option("radius", default: "0.62"))!
let seed = Float(option("seed", default: "0"))!
let fill = Float(option("fill", default: "1"))!
let fixedPulse = args.contains("--pulse") ? Float(option("pulse", default: "0.5")) : nil
let fixedGlow = args.contains("--glow") ? Float(option("glow", default: "0.8")) : nil

guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { fail("no Metal device") }
guard let source = try? String(contentsOfFile: shaderPath, encoding: .utf8) else { fail("cannot read \(shaderPath)") }
let library: MTLLibrary
do { library = try device.makeLibrary(source: source, options: nil) } catch { fail("shader compile failed:\n\(error)") }

let descriptor = MTLRenderPipelineDescriptor()
descriptor.vertexFunction = library.makeFunction(name: "orbVertex")
descriptor.fragmentFunction = library.makeFunction(name: "orbFragment")
descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { fail("pipeline failed") }

let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: frameSize, height: frameSize, mipmapped: false)
texDesc.usage = [.renderTarget, .shaderRead]
texDesc.storageMode = .shared

func hexColor(_ hex: String) -> (CGFloat, CGFloat, CGFloat) {
    let v = UInt32(hex, radix: 16) ?? 0x2c2960
    return (CGFloat((v >> 16) & 255) / 255, CGFloat((v >> 8) & 255) / 255, CGFloat(v & 255) / 255)
}
let bg = hexColor(bgHex)

if args.contains("--scan") {
    let from = Double(option("scan-from", default: "0"))!, to = Double(option("scan-to", default: "13"))!
    let fps = Double(option("scan-fps", default: "120"))!
    let side = Int(option("size", default: "160"))!
    let scanDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: side, height: side, mipmapped: false)
    scanDesc.usage = [.renderTarget, .shaderRead]
    scanDesc.storageMode = .shared
    guard let scanTexture = device.makeTexture(descriptor: scanDesc) else { fail("texture") }
    var previous = [UInt8](repeating: 0, count: side * side * 4)
    var current = previous
    var diffs: [(Double, Double)] = []
    var t = from
    var first = true
    while t <= to {
        guard let buffer = queue.makeCommandBuffer() else { fail("buffer") }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = scanTexture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.colorAttachments[0].storeAction = .store
        let phase = t.truncatingRemainder(dividingBy: 6) / 6
        let breathe = Float(0.5 - 0.5 * cos(2 * Double.pi * phase))
        // The app moves the radius with the breath too (shell scale 0.965 … 1.055).
        let shell = 0.965 + (1.055 - 0.965) * breathe
        var u = Uniforms(size: SIMD2(Float(side), Float(side)), time: Float(t), pulse: fixedPulse ?? breathe,
                         glow: fixedGlow ?? (0.56 + 0.44 * breathe), energy: energy, brightness: brightness,
                         radius: radius * Float(shell) / 1.055, detail: detail, seed: seed, beat: Float(phase), fill: fill)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { fail("encoder") }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()
        scanTexture.getBytes(&current, bytesPerRow: side * 4, from: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0)
        if !first {
            var total = 0
            for i in stride(from: 0, to: current.count, by: 4) {
                total += abs(Int(current[i]) - Int(previous[i])) + abs(Int(current[i + 1]) - Int(previous[i + 1])) + abs(Int(current[i + 2]) - Int(previous[i + 2]))
            }
            diffs.append((t, Double(total) / Double(side * side * 3)))
        }
        first = false
        swap(&previous, &current)
        t += 1 / fps
    }
    let sorted = diffs.map { $0.1 }.sorted()
    let median = sorted[sorted.count / 2]
    let worst = diffs.sorted { $0.1 > $1.1 }.prefix(6)
    print(String(format: "scanned %d frames (%.1f–%.1f s at %.0f fps): median change %.4f levels/pixel, largest %.4f (%.1f × the median)",
                 diffs.count, from, to, fps, median, worst.first!.1, worst.first!.1 / max(median, 1e-6)))
    for (time, d) in worst { print(String(format: "  t = %.3f s  (beat %.3f)  change %.4f  (%.1f × median)", time, time.truncatingRemainder(dividingBy: 6) / 6, d, d / max(median, 1e-6))) }
    exit(0)
}

if args.contains("--wave") {
    guard let waveFn = library.makeFunction(name: "waveFragment") else { fail("no waveFragment") }
    let wd = MTLRenderPipelineDescriptor()
    wd.vertexFunction = library.makeFunction(name: "orbVertex")
    wd.fragmentFunction = waveFn
    wd.colorAttachments[0].pixelFormat = .bgra8Unorm
    guard let wavePipeline = try? device.makeRenderPipelineState(descriptor: wd) else { fail("wave pipeline") }
    let reach = Float(option("reach", default: "0.54"))!
    let orbR = 1 / (1 + reach + 0.08)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let rowsW = (times.count + cols - 1) / cols
    let wW = cols * frameSize, wH = rowsW * frameSize
    guard let wsheet = CGContext(data: nil, width: wW, height: wH, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { fail("ctx") }
    wsheet.setFillColor(red: bg.0, green: bg.1, blue: bg.2, alpha: 1)
    wsheet.fill(CGRect(x: 0, y: 0, width: wW, height: wH))
    func spectrum(_ t: Double) -> [Float] {
        (0..<32).map { k in
            let bass = exp(-Double(k) / 7.0)
            let beat = pow(max(0, sin(t * 6.5)), 3) * bass
            let body = 0.35 + 0.25 * sin(t * 2.1 + Double(k) * 0.7) + 0.2 * sin(t * 3.7 - Double(k) * 0.4)
            return Float(min(1, max(0.03, 0.18 + 0.42 * beat + 0.30 * max(0, body) * (0.4 + bass))))
        }
    }
    for (index, time) in times.enumerated() {
        let t = Double(time)
        var floats = [Float](repeating: 0, count: 8 + 32 + 6 + 6 + 192)
        floats[0] = Float(frameSize); floats[1] = Float(frameSize); floats[2] = time; floats[3] = orbR; floats[4] = reach
        floats[5] = 1; floats[6] = 0.6; floats[7] = 0
        let bands = spectrum(t)
        for k in 0..<32 { floats[8 + k] = bands[k] }
        // bursts born on earlier beats (every ~0.48 s), the last four still alive
        for b in 0..<6 {
            let born = floor(t / 0.48) * 0.48 - Double(b) * 0.48
            let age = t - born
            floats[8 + 32 + b] = age >= 0 && age < 1.7 && b < 4 ? Float(age) : -1
            floats[8 + 32 + 6 + b] = 0.85
            let snap = spectrum(born + 0.05)
            for k in 0..<32 { floats[8 + 32 + 12 + b * 32 + k] = snap[k] }
        }
        guard let texture = device.makeTexture(descriptor: texDesc), let buffer = queue.makeCommandBuffer() else { fail("texture") }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { fail("encoder") }
        encoder.setRenderPipelineState(wavePipeline)
        floats.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.commit(); buffer.waitUntilCompleted()
        var bytes = [UInt8](repeating: 0, count: frameSize * frameSize * 4)
        texture.getBytes(&bytes, bytesPerRow: frameSize * 4, from: MTLRegionMake2D(0, 0, frameSize, frameSize), mipmapLevel: 0)
        let image = CGImage(width: frameSize, height: frameSize, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frameSize * 4,
                            space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                            provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        let cx = (index % cols) * frameSize, cy = wH - (index / cols + 1) * frameSize
        // a stand-in for the glyph disk the ring hugs
        let r = CGFloat(frameSize) * 0.5 * CGFloat(orbR)
        wsheet.setFillColor(red: 0.55, green: 0.50, blue: 0.86, alpha: 1)
        wsheet.fillEllipse(in: CGRect(x: CGFloat(cx) + CGFloat(frameSize) / 2 - r, y: CGFloat(cy) + CGFloat(frameSize) / 2 - r, width: 2 * r, height: 2 * r))
        wsheet.draw(image, in: CGRect(x: cx, y: cy, width: frameSize, height: frameSize))
    }
    guard let wfinal = wsheet.makeImage(), let wdest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, "public.png" as CFString, 1, nil) else { fail("write") }
    CGImageDestinationAddImage(wdest, wfinal, nil)
    CGImageDestinationFinalize(wdest)
    print("rendered \(times.count) wave frames → \(outPath)")
    exit(0)
}

let rows = (times.count + cols - 1) / cols
let sheetW = cols * frameSize, sheetH = rows * frameSize
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let sheet = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { fail("context") }
sheet.setFillColor(red: bg.0, green: bg.1, blue: bg.2, alpha: 1)
sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))

var totalMs = 0.0
for (index, time) in times.enumerated() {
    guard let texture = device.makeTexture(descriptor: texDesc), let buffer = queue.makeCommandBuffer() else { fail("texture") }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    pass.colorAttachments[0].storeAction = .store
    let phase = Double(time).truncatingRemainder(dividingBy: 6) / 6
    let breathe = Float(0.5 - 0.5 * cos(2 * Double.pi * phase))
    var u = Uniforms(size: SIMD2(Float(frameSize), Float(frameSize)), time: time, pulse: fixedPulse ?? breathe,
                     glow: fixedGlow ?? (0.56 + 0.44 * breathe), energy: energy, brightness: brightness, radius: radius,
                     detail: detail, seed: seed, beat: Float(phase), fill: fill)
    guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { fail("encoder") }
    encoder.setRenderPipelineState(pipeline)
    encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    encoder.endEncoding()
    let start = Date()
    buffer.commit()
    buffer.waitUntilCompleted()
    totalMs += Date().timeIntervalSince(start) * 1000

    var bytes = [UInt8](repeating: 0, count: frameSize * frameSize * 4)
    texture.getBytes(&bytes, bytesPerRow: frameSize * 4, from: MTLRegionMake2D(0, 0, frameSize, frameSize), mipmapLevel: 0)
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    let image = CGImage(width: frameSize, height: frameSize, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: frameSize * 4,
                        space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    let col = index % cols, row = index / cols
    sheet.draw(image, in: CGRect(x: col * frameSize, y: sheetH - (row + 1) * frameSize, width: frameSize, height: frameSize))
}

guard let final = sheet.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, "public.png" as CFString, 1, nil) else { fail("write") }
CGImageDestinationAddImage(destination, final, nil)
CGImageDestinationFinalize(destination)
print(String(format: "rendered %d frames at %dx%d, GPU wall time %.1f ms per frame (includes submit and wait) → %@",
             times.count, frameSize, frameSize, totalMs / Double(times.count), outPath))
