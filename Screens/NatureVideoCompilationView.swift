import AVFoundation
import Combine
import SwiftUI
import UIKit

/// Plays a **royalty-free nature “compilation”** — sequenced HD clips from [Mixkit](https://mixkit.co/license/#videoFree).
/// **Quick Start** and **photo-anchored** sessions use **different clip pools** so visuals vary clearly by entry path.
enum NatureVideoCompilation {
    /// Mood / Quick Start path — forests, lakes, drone nature (shuffle still varies per session id).
    static let mixkitQuickStartClipURLs: [URL] = [
        URL(string: "https://assets.mixkit.co/videos/5038/5038-720.mp4")!,
        URL(string: "https://assets.mixkit.co/videos/2363/2363-720.mp4")!,
        URL(string: "https://assets.mixkit.co/videos/40657/40657-720.mp4")!,
        URL(string: "https://assets.mixkit.co/videos/1164/1164-720.mp4")!,
    ]

    /// Photo anchor path — **animals in nature** (Mixkit free video; different reel from Quick Start).
    /// IDs from [Mixkit Animal](https://mixkit.co/free-stock-video/discover/animal/) + seagulls wildlife shot.
    static let mixkitPhotoAnchorClipURLs: [URL] = [
        URL(string: "https://assets.mixkit.co/videos/4669/4669-720.mp4")!, // macaw parrot on branch
        URL(string: "https://assets.mixkit.co/videos/4649/4649-720.mp4")!, // parrots in nature reserve
        URL(string: "https://assets.mixkit.co/videos/4682/4682-720.mp4")!, // swans on river
        URL(string: "https://assets.mixkit.co/videos/4681/4681-720.mp4")!, // flamingos at lakeshore
    ]

    /// Deterministic shuffle from session id — same id + same path ⇒ same order (replay).
    static func clipPlaylist(seed: UUID, photoAnchored: Bool) -> [URL] {
        var urls = photoAnchored ? mixkitPhotoAnchorClipURLs : mixkitQuickStartClipURLs
        var rng = SeededRandomNumberGenerator(seed: seed)
        urls.shuffle(using: &rng)
        return urls
    }
}

/// Seeded shuffle so replay can reproduce the same sequence (stable across launches for a given `UUID`).
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UUID) {
        var tuple = seed.uuid
        state = withUnsafeMutablePointer(to: &tuple) { ptr in
            ptr.withMemoryRebound(to: UInt64.self, capacity: 2) { p in
                p[0] ^ p[1]
            }
        }
        if state == 0 { state = 0x9E37_79B9_7F4A_7C15 }
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}

final class NatureCompilationSession: ObservableObject {
    private(set) var queuePlayer = AVQueuePlayer()
    var player: AVPlayer { queuePlayer }

    /// `true` once the first remote clip is actually rendering frames. Drives the loading poster so
    /// the user never stares at a black player layer while the 720p clip buffers.
    @Published private(set) var isReady = false

    private let clipURLs: [URL]
    private var endObserver: NSObjectProtocol?
    private var timeControlObserver: NSKeyValueObservation?

    init(clipURLs: [URL]) {
        self.clipURLs = clipURLs.isEmpty ? NatureVideoCompilation.mixkitQuickStartClipURLs : clipURLs
        observePlaybackStart()
    }

    private func observePlaybackStart() {
        timeControlObserver = queuePlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self, player.timeControlStatus == .playing else { return }
            DispatchQueue.main.async {
                if !self.isReady { self.isReady = true }
            }
        }
    }

    func prepareAndPlay() {
        clearQueue()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .advance
        enqueueRound()
        queuePlayer.play()
    }

    func pause() {
        queuePlayer.pause()
    }

    /// Clears the queue without relying on `removeAllItems()` (added in iOS 16.4).
    private func clearQueue() {
        queuePlayer.pause()
        let snapshot = queuePlayer.items()
        for item in snapshot {
            queuePlayer.remove(item)
        }
    }

    private func enqueueRound() {
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        let items = clipURLs.map { AVPlayerItem(url: $0) }
        guard let last = items.last else { return }

        for item in items {
            queuePlayer.insert(item, after: nil)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: last,
            queue: .main
        ) { [weak self] _ in
            self?.onCompilationRoundEnded()
        }
    }

    private func onCompilationRoundEnded() {
        enqueueRound()
        queuePlayer.play()
    }

    deinit {
        if let endObserver = endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        timeControlObserver?.invalidate()
    }
}

struct NatureVideoCompilationView: View {
    let mediaSessionID: UUID
    let photoAnchored: Bool

    @StateObject private var session: NatureCompilationSession

    init(mediaSessionID: UUID, photoAnchored: Bool) {
        self.mediaSessionID = mediaSessionID
        self.photoAnchored = photoAnchored
        let clips = NatureVideoCompilation.clipPlaylist(seed: mediaSessionID, photoAnchored: photoAnchored)
        _session = StateObject(wrappedValue: NatureCompilationSession(clipURLs: clips))
    }

    var body: some View {
        ZStack {
            NatureVideoPlayerRepresentable(player: session.player)
                .ignoresSafeArea()

            if !session.isReady {
                NatureVideoLoadingPoster()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: session.isReady)
        .onAppear {
            session.prepareAndPlay()
        }
        .onDisappear {
            session.pause()
        }
        .id(mediaSessionID)
    }
}

/// Calm poster shown over the player until the first video frame renders — a soft nature gradient
/// with the shared breathing loader, so buffering never reads as a frozen black screen.
private struct NatureVideoLoadingPoster: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.16, blue: 0.20),
                    Color(red: 0.09, green: 0.22, blue: 0.26),
                    Color(red: 0.05, green: 0.12, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                BreathingCalmProgressView(diameter: 64)
                Text("Settling the scene…")
                    .font(BrandTheme.orbLineFont())
                    .orbOverlayText(muted: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing the nature video")
    }
}

private struct NatureVideoPlayerRepresentable: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerHostingView {
        let v = PlayerHostingView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PlayerHostingView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerHostingView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
