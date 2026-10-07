// Renders the annotated walkthrough (video only) from plan.json.
// Usage: render <plan.json> <out.mp4>
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

struct ScreenRect: Decodable { let x, y, w, h, radius: Double }
struct Segment: Decodable {
    let kind: String
    let src: String
    let outStart, outEnd, srcStart, srcEnd: Double
    let xfade: Double?
    let still: String?
}
struct Overlay: Decodable {
    let png: String
    let start, end, fadeIn, fadeOut: Double
    let layer: Int
    /// Optional top-left position (plan coordinates); the PNG is then drawn at its own size
    /// instead of stretched over the whole frame — used for small strips such as subtitles.
    let x, y: Double?
}
struct Plan: Decodable {
    let width, height, fps: Int
    let duration: Double
    let screen: ScreenRect
    let background: String
    let sources: [String: String]
    let segments: [Segment]
    let overlays: [Overlay]
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

func loadPNG(_ path: String) -> CGImage {
    let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}

/// Sequential decoder: frames must be requested at non-decreasing times.
final class SourceReader {
    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private var pending: CMSampleBuffer?
    private var current: CMSampleBuffer?
    private var currentPTS = -1.0
    private var convertedPTS = -2.0
    private var scaled: CGImage?
    private let targetW: Int, targetH: Int

    init(path: String, targetW: Int, targetH: Int) throws {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let track = asset.tracks(withMediaType: .video)[0]
        reader = try AVAssetReader(asset: asset)
        output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()
        self.targetW = targetW
        self.targetH = targetH
    }

    /// Latest frame at or before `t`, pre-scaled to the device screen size.
    func frame(at t: Double) -> CGImage? {
        while true {
            if pending == nil {
                guard let next = output.copyNextSampleBuffer() else { break }
                if CMSampleBufferGetNumSamples(next) == 0 { continue }
                pending = next
            }
            let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(pending!))
            if pts <= t + 1e-4 || current == nil {
                current = pending
                currentPTS = pts
                pending = nil
                if pts > t { break }
            } else {
                break
            }
        }
        guard let current else { return scaled }
        if convertedPTS != currentPTS {
            scaled = scale(current)
            convertedPTS = currentPTS
        }
        return scaled
    }

    private func scale(_ sample: CMSampleBuffer) -> CGImage? {
        guard let pb = CMSampleBufferGetImageBuffer(sample) else { return scaled }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let srcCtx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: CVPixelBufferGetWidth(pb),
            height: CVPixelBufferGetHeight(pb),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ), let full = srcCtx.makeImage() else { return scaled }
        let dst = CGContext(data: nil, width: targetW, height: targetH, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo)!
        dst.interpolationQuality = .high
        dst.draw(full, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
        return dst.makeImage()
    }
}

let args = CommandLine.arguments
let plan = try JSONDecoder().decode(Plan.self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let outURL = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: outURL)

let W = plan.width, H = plan.height
let sw = Int(plan.screen.w), sh = Int(plan.screen.h)
// CoreGraphics is bottom-left origin; plan rects are top-left.
let screenRect = CGRect(x: plan.screen.x, y: Double(H) - plan.screen.y - plan.screen.h, width: plan.screen.w, height: plan.screen.h)
let screenPath = CGPath(roundedRect: screenRect, cornerWidth: plan.screen.radius, cornerHeight: plan.screen.radius, transform: nil)
let fullRect = CGRect(x: 0, y: 0, width: W, height: H)
let background = loadPNG(plan.background)

let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: W,
    AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 4_200_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: plan.fps * 2,
        AVVideoAllowFrameReorderingKey: true,
    ],
    AVVideoColorPropertiesKey: [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: W,
    kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

var readers: [String: SourceReader] = [:]
func reader(_ key: String) -> SourceReader {
    if let r = readers[key] { return r }
    let r = try! SourceReader(path: plan.sources[key]!, targetW: sw, targetH: sh)
    readers[key] = r
    return r
}

var stillCache: [String: CGImage] = [:]
func scaledStill(_ path: String) -> CGImage {
    if let cached = stillCache[path] { return cached }
    let full = loadPNG(path)
    let dst = CGContext(data: nil, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo)!
    dst.interpolationQuality = .high
    dst.draw(full, in: CGRect(x: 0, y: 0, width: sw, height: sh))
    let img = dst.makeImage()!
    stillCache[path] = img
    return img
}

var overlayCache: [String: CGImage] = [:]
let totalFrames = Int((plan.duration * Double(plan.fps)).rounded())
var segIndex = 0
var previousImage: CGImage?
var lastImage: CGImage?
let started = Date()

for i in 0 ..< totalFrames {
    let t = Double(i) / Double(plan.fps)
    while segIndex < plan.segments.count - 1 && t >= plan.segments[segIndex].outEnd {
        segIndex += 1
        previousImage = lastImage
    }
    let seg = plan.segments[segIndex]
    let srcT = seg.kind == "clip" ? min(seg.srcStart + (t - seg.outStart), seg.srcEnd) : seg.srcStart
    let inHold = seg.kind == "clip" && t - seg.outStart >= seg.srcEnd - seg.srcStart
    let image: CGImage?
    if inHold, let still = seg.still {
        image = scaledStill(still)
    } else {
        image = reader(seg.src).frame(at: srcT)
    }

    while !input.isReadyForMoreMediaData { usleep(2000) }
    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbOut)
    let pb = pbOut!
    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: colorSpace, bitmapInfo: bitmapInfo)!
    ctx.interpolationQuality = .high
    ctx.draw(background, in: fullRect)

    ctx.saveGState()
    ctx.addPath(screenPath)
    ctx.clip()
    let xfade = seg.xfade ?? 0
    if xfade > 0, let prev = previousImage, t - seg.outStart < xfade {
        ctx.draw(prev, in: screenRect)
        ctx.setAlpha(CGFloat((t - seg.outStart) / xfade))
    }
    if let image { ctx.draw(image, in: screenRect) }
    ctx.restoreGState()
    lastImage = image

    for ov in plan.overlays where ov.start <= t && t < ov.end {
        var alpha = 1.0
        if ov.fadeIn > 0 { alpha = min(alpha, (t - ov.start) / ov.fadeIn) }
        if ov.fadeOut > 0 { alpha = min(alpha, (ov.end - t) / ov.fadeOut) }
        alpha = max(0, min(1, alpha))
        if alpha <= 0.001 { continue }
        let img: CGImage
        if let cached = overlayCache[ov.png] { img = cached } else {
            img = loadPNG(ov.png)
            overlayCache[ov.png] = img
        }
        ctx.saveGState()
        ctx.setAlpha(CGFloat(alpha))
        if let x = ov.x, let y = ov.y {
            let rect = CGRect(x: x, y: Double(H) - y - Double(img.height), width: Double(img.width), height: Double(img.height))
            ctx.draw(img, in: rect)
        } else {
            ctx.draw(img, in: fullRect)
        }
        ctx.restoreGState()
    }
    // Evict overlays that are finished.
    if i % 30 == 0 {
        let live = Set(plan.overlays.filter { $0.end > t - 1 }.map(\.png))
        overlayCache = overlayCache.filter { live.contains($0.key) }
    }

    CVPixelBufferUnlockBaseAddress(pb, [])
    adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(plan.fps)))
    if i % 600 == 0 {
        let el = Date().timeIntervalSince(started)
        print(String(format: "frame %d/%d  t=%.1fs  elapsed %.0fs", i, totalFrames, t, el))
        fflush(stdout)
    }
}

input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("status", writer.status.rawValue, writer.error?.localizedDescription ?? "ok",
      String(format: "elapsed %.0fs", Date().timeIntervalSince(started)))
