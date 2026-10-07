import AVFoundation
// Usage: fps <video> [skipSeconds] — delivered fps and hitches (frame gaps) of a screen recording
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let skip = a.count > 2 ? Double(a[2])! : 0
let r = try! AVAssetReader(asset: asset); let o = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video)[0], outputSettings: nil)
r.add(o); r.startReading(); var pts: [Double] = []
while let sb = o.copyNextSampleBuffer() { if CMSampleBufferGetNumSamples(sb) > 0 { pts.append(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sb))) } }
pts.sort(); pts = pts.filter { $0 >= skip }
guard pts.count > 2 else { print("too few frames"); exit(0) }
let dur = pts.last! - pts.first!
var gaps: [Double] = []
for i in 1..<pts.count { gaps.append(pts[i] - pts[i-1]) }
let sorted = gaps.sorted()
func pct(_ p: Double) -> Double { sorted[min(sorted.count-1, Int(Double(sorted.count) * p))] }
let h50 = gaps.filter { $0 > 0.05 }.count, h100 = gaps.filter { $0 > 0.1 }.count, h250 = gaps.filter { $0 > 0.25 }.count
print(String(format: "frames %d over %.1fs = %.1f fps | median gap %.0fms p95 %.0fms max %.0fms | gaps>50ms %d >100ms %d >250ms %d", pts.count, dur, Double(pts.count)/dur, pct(0.5)*1000, pct(0.95)*1000, sorted.last!*1000, h50, h100, h250))
