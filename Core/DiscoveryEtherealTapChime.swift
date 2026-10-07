import AVFoundation

/// Soft, fleeting bell-like swell for taps (synthesised — no bundled assets).
enum DiscoveryEtherealTapChime {
    /// ~0.4s decay at low level; honours main-actor AudioEngine use from SwiftUI taps.
    @MainActor
    static func playLight() {
        ChimeEngine.shared.play(.light)
    }

    @MainActor
    static func playSuccess() {
        ChimeEngine.shared.play(.success)
    }

    /// Quietest variant — generic button presses across the app.
    @MainActor
    static func playButton() {
        ChimeEngine.shared.play(.button)
    }

    /// Start the audio engine and pre-render every chime buffer ahead of first use, so the first
    /// tap doesn't pay for `AVAudioEngine.start()` + synthesis on the main thread.
    @MainActor
    static func prewarm() {
        ChimeEngine.shared.prewarm()
    }
}

// MARK: - Engine

@MainActor
private final class ChimeEngine {
    static let shared = ChimeEngine()

    enum Variant: CaseIterable { case button, light, success }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

    private var graphReady = false
    private var buffers: [Variant: AVAudioPCMBuffer] = [:]
    /// The engine keeps the audio hardware and a realtime render thread alive while running.
    /// Nothing chimes on an idle screen, so pause it after a quiet spell; `ensureRunning()`
    /// restarts a prepared graph in a few milliseconds on the next tap.
    private var idlePauseTask: Task<Void, Never>?
    private static let idlePauseDelay: TimeInterval = 20

    private init() {}

    func prewarm() {
        guard AppAudioSession.activate() else { return }
        _ = ensureRunning()
        for variant in Variant.allCases {
            _ = buffer(for: variant)
        }
    }

    func play(_ variant: Variant) {
        guard AppAudioSession.activate() else { return }
        guard ensureRunning() else { return }
        guard let buffer = buffer(for: variant) else { return }

        // `.interrupts` keeps rapid taps crisp without stacking overlapping tails.
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        DemoAudioLog.record("chime", ["variant": "\(variant)"])
        if !player.isPlaying {
            player.play()
        }
        scheduleIdlePause()
    }

    private func scheduleIdlePause() {
        idlePauseTask?.cancel()
        idlePauseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.idlePauseDelay))
            guard !Task.isCancelled, let self, self.engine.isRunning else { return }
            self.player.stop()
            self.engine.pause()
        }
    }

    private func ensureRunning() -> Bool {
        if !graphReady {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 1.0
            engine.prepare()
            graphReady = true
        }

        if engine.isRunning { return true }

        do {
            try engine.start()
            return true
        } catch {
            // Recover from a stale graph (e.g. after a route/interruption change).
            engine.stop()
            engine.reset()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 1.0
            engine.prepare()
            do {
                try engine.start()
                return true
            } catch {
                return false
            }
        }
    }

    private func buffer(for variant: Variant) -> AVAudioPCMBuffer? {
        if let cached = buffers[variant] { return cached }
        guard let rendered = Self.render(variant, format: format) else { return nil }
        buffers[variant] = rendered
        return rendered
    }

    /// Deterministic synth — rendered once per variant, then reused on every tap.
    private static func render(_ variant: Variant, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate

        let duration: TimeInterval
        let f1: Double
        let f2: Double
        let f3: Double
        let volume: Double
        let decayRate: Double
        let attackSeconds: Double
        let swirlAmount: Double

        switch variant {
        case .button:
            duration = 0.34
            (f1, f2, f3) = (294.0, 294.0 * 1.498, 294.0 * 2.01)
            (volume, decayRate, attackSeconds, swirlAmount) = (0.16, 5.0, 0.020, 0.04)
        case .light:
            duration = 0.46
            (f1, f2, f3) = (330.0, 330.0 * 1.498, 330.0 * 2.015)
            (volume, decayRate, attackSeconds, swirlAmount) = (0.20, 4.6, 0.026, 0.07)
        case .success:
            duration = 0.74
            (f1, f2, f3) = (392.0, 392.0 * 1.335, 392.0 * 2.0)
            (volume, decayRate, attackSeconds, swirlAmount) = (0.26, 3.35, 0.040, 0.06)
        }

        let frameCount = AVAudioFrameCount(sr * duration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channels = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = frameCount
        let channelCount = Int(format.channelCount)

        for i in 0 ..< Int(frameCount) {
            let t = Double(i) / sr
            let attack = min(1, t / attackSeconds)
            let decay = exp(-t * decayRate)
            let env = attack * decay
            let swirl = sin(2 * Double.pi * 9.7 * t) * swirlAmount
            let body =
                sin(2 * Double.pi * f1 * t) * 0.74
                    + sin(2 * Double.pi * f2 * t) * 0.42
                    + sin(2 * Double.pi * f3 * t) * 0.14
            let sample = Float(body * env * (1 + swirl) * volume)
            for ch in 0 ..< channelCount {
                channels[ch][i] = sample
            }
        }

        return buffer
    }
}
