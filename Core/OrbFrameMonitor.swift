import QuartzCore
import UIKit

/// Diagnostics for the persistent orb (demo tooling, off by default).
///
/// `-NoteStalgiaDemoFrameLog YES` (with `-NoteStalgiaDemoAudioLog YES`) logs an `orb.frames` event
/// every two seconds: display-link ticks delivered to the main thread per second (how often the
/// main run loop was free when the display refreshed), hitches (ticks that arrived more than 1.5
/// frames after the previous one), orb shell timeline draws per second, and the CPU time of the
/// nebula field's Canvas closure (average / max per frame). Every call site is a single cached
/// `Bool` check when the flag is off.
@MainActor
final class OrbFrameMonitor: NSObject {
    static let shared = OrbFrameMonitor()
    static let isEnabled = UserDefaults.standard.bool(forKey: "NoteStalgiaDemoFrameLog")

    private var link: CADisplayLink?
    private var ticks = 0
    private var hitches = 0
    private var shellDraws = 0
    private var canvasFrames = 0
    private var canvasNanos: UInt64 = 0
    private var canvasMaxNanos: UInt64 = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var windowStart: CFTimeInterval = 0

    func start() {
        guard Self.isEnabled, link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func noteShellDraw() {
        shellDraws += 1
    }

    /// Usable inside a `ViewBuilder` (`let _ = …`): a single cached `Bool` check when the flag is off.
    static func noteShellDrawIfEnabled() {
        guard isEnabled else { return }
        shared.noteShellDraw()
    }

    func noteCanvas(nanoseconds: UInt64) {
        canvasFrames += 1
        canvasNanos += nanoseconds
        canvasMaxNanos = max(canvasMaxNanos, nanoseconds)
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        if windowStart == 0 {
            windowStart = now
            lastTimestamp = now
            return
        }
        ticks += 1
        let interval = now - lastTimestamp
        if interval > link.duration * 1.5 {
            hitches += 1
        }
        lastTimestamp = now

        let elapsed = now - windowStart
        guard elapsed >= 2 else { return }
        let canvasAvgMs = canvasFrames > 0 ? Double(canvasNanos) / Double(canvasFrames) / 1_000_000 : 0
        DemoAudioLog.record("orb.frames", [
            "displayFps": (Double(ticks) / elapsed * 10).rounded() / 10,
            "hitches": hitches,
            "shellDrawsPerSecond": (Double(shellDraws) / elapsed * 10).rounded() / 10,
            "canvasAvgMs": (canvasAvgMs * 100).rounded() / 100,
            "canvasMaxMs": (Double(canvasMaxNanos) / 1_000_000 * 100).rounded() / 100,
            "maxDisplayFps": UIScreen.main.maximumFramesPerSecond,
        ])
        ticks = 0
        hitches = 0
        shellDraws = 0
        canvasFrames = 0
        canvasNanos = 0
        canvasMaxNanos = 0
        windowStart = now
    }
}
