import AVFoundation
import Combine

/// Streams **looping ambient music** with a single `AVPlayer` (manual loop on end-of-item).
///
/// A single player (instead of `AVPlayerLooper`) gives reliable status observation, so cache /
/// network failures actually trigger the fallback chain instead of failing silently.
@MainActor
final class AmbientAudioSession: ObservableObject {
    /// Primary looping calm track (bundled). Also used for resident genre playback.
    static let quickStartStreamURL = BundledAudio.urlOrRemote(
        "Drift Between Rooms",
        fallback: URL(string: "https://opengameart.org/sites/default/files/song_2.mp3")!
    )

    /// Photo-anchored session loop (bundled).
    static let photoAnchorStreamURL = BundledAudio.urlOrRemote(
        "Pine Smoke Drift",
        fallback: URL(string: "https://opengameart.org/sites/default/files/lvl_5_the_oasis_or_resting_place.mp3")!
    )

    private static let streamVolume: Float = 0.38

    var volumeMultiplier: Float = 1

    /// Spectrum analysis tuning — discovery uses a faster, hotter profile.
    var musicReactiveProfile: MusicReactiveProfile = .standard {
        didSet { reactiveAnalyzer.profile = musicReactiveProfile }
    }

    private var sourceRemoteURL = AmbientAudioSession.quickStartStreamURL
    private var playbackFallbackURL: URL?
    private var triedStreamFallback = false
    private var triedCacheBypass = false

    @Published var isMuted = false {
        didSet { applyMute() }
    }

    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var loopObserver: NSObjectProtocol?
    private var playbackGeneration: UInt = 0
    private let reactiveAnalyzer = MusicReactiveAnalyzer()

    init() {
        reactiveAnalyzer.setUpdateHandler { snapshot in
            // Push to the isolated bus only — never the navigation state.
            MusicReactiveBus.shared.publish(snapshot)
        }
    }

    deinit {
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
        }
    }

    func startFresh(photoAnchored: Bool = false) {
        stop()
        triedStreamFallback = false
        triedCacheBypass = false
        if photoAnchored {
            sourceRemoteURL = Self.photoAnchorStreamURL
            playbackFallbackURL = Self.quickStartStreamURL
        } else {
            sourceRemoteURL = Self.quickStartStreamURL
            playbackFallbackURL = nil
        }
        StreamAudioCache.prefetch(sourceRemoteURL)
        if let fallback = playbackFallbackURL {
            StreamAudioCache.prefetch(fallback)
        }
        AppAudioSession.activate()
        beginPlayback()
    }

    func startFresh(streamURL: URL) {
        stop()
        triedStreamFallback = false
        triedCacheBypass = false
        sourceRemoteURL = streamURL
        playbackFallbackURL = Self.quickStartStreamURL
        StreamAudioCache.prefetch(streamURL)
        StreamAudioCache.prefetch(Self.quickStartStreamURL)
        AppAudioSession.activate()
        beginPlayback()
    }

    func pausePlayback() {
        player?.pause()
    }

    func resumePlayback() {
        player?.play()
    }

    func stop() {
        playbackGeneration &+= 1
        tearDownPlaybackOnly()
        reactiveAnalyzer.detach()
        MusicReactiveBus.shared.clear()
        // Session stays active (managed by AppAudioSession) so UI chimes keep working.
    }

    private func beginPlayback() {
        let remote = sourceRemoteURL
        let playbackURL = StreamAudioCache.playbackURL(for: remote)
        startPlayer(with: playbackURL, remoteSource: remote, generation: playbackGeneration)
    }

    private func startPlayer(with url: URL, remoteSource: URL, generation: UInt) {
        guard generation == playbackGeneration else { return }
        tearDownObservers()

        let item = AVPlayerItem(asset: AVURLAsset(url: url))
        item.preferredForwardBufferDuration = url.isFileURL ? 0 : 2
        currentItem = item

        let avPlayer = player ?? AVPlayer()
        avPlayer.replaceCurrentItem(with: item)
        avPlayer.volume = effectiveVolume
        avPlayer.actionAtItemEnd = .none
        player = avPlayer

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observed, _ in
            Task { @MainActor in
                self?.handleStatus(observed, remoteSource: remoteSource, playedURL: url, generation: generation)
            }
        }

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loopToStart(expecting: generation)
            }
        }

        avPlayer.play()
    }

    private func loopToStart(expecting generation: UInt) {
        guard generation == playbackGeneration, let player else { return }
        player.seek(to: .zero) { [weak player] _ in
            player?.play()
        }
    }

    private func handleStatus(
        _ item: AVPlayerItem,
        remoteSource: URL,
        playedURL: URL,
        generation: UInt
    ) {
        guard generation == playbackGeneration else { return }

        switch item.status {
        case .readyToPlay:
            Task { @MainActor in
                guard generation == playbackGeneration else { return }
                if item.audioMix == nil {
                    _ = await reactiveAnalyzer.applyMixWhenReady(to: item)
                }
                guard generation == playbackGeneration else { return }
                player?.play()
            }
        case .failed:
            tearDownObservers()
            if playedURL.isFileURL, !triedCacheBypass {
                // Corrupt/unreadable cache file — purge and stream the original.
                triedCacheBypass = true
                StreamAudioCache.invalidate(remoteSource)
                startPlayer(with: remoteSource, remoteSource: remoteSource, generation: generation)
                return
            }
            retryWithFallbackIfNeeded()
        default:
            break
        }
    }

    private func retryWithFallbackIfNeeded() {
        guard let fallback = playbackFallbackURL, !triedStreamFallback else { return }
        triedStreamFallback = true
        triedCacheBypass = false
        sourceRemoteURL = fallback
        playbackFallbackURL = nil
        StreamAudioCache.prefetch(fallback)
        beginPlayback()
    }

    private func tearDownObservers() {
        statusObservation?.invalidate()
        statusObservation = nil
        if let loopObserver {
            NotificationCenter.default.removeObserver(loopObserver)
            self.loopObserver = nil
        }
    }

    private func tearDownPlaybackOnly() {
        tearDownObservers()
        reactiveAnalyzer.detach(clearPublished: false)
        currentItem?.audioMix = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        currentItem = nil
    }

    private var effectiveVolume: Float {
        isMuted ? 0 : Self.streamVolume * volumeMultiplier
    }

    private func applyMute() {
        player?.volume = effectiveVolume
    }
}
