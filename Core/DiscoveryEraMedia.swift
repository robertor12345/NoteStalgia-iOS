import AVFoundation
import SwiftUI

// MARK: - Internet Archive clip (full MP4 + large poster / GIF)

struct ArchiveEraClip: Equatable {
    let archiveItemID: String
    /// Highest quality first — prefer full h.264 MP4 over low-bitrate derivatives.
    let videoFileNames: [String]
    /// Large still or GIF from the item (shown until video is ready).
    let posterFileName: String?

    var videoURLs: [URL] {
        videoFileNames.compactMap { ArchiveOrgMediaURL.download(itemID: archiveItemID, fileName: $0) }
    }

    var primaryVideoURL: URL? { videoURLs.first }

    var posterImageURL: URL {
        ArchiveOrgMediaURL.poster(
            itemID: archiveItemID,
            posterFileName: posterFileName,
            videoFileNames: videoFileNames
        )
    }
}

enum ArchiveOrgMediaURL {
    static func download(itemID: String, fileName: String) -> URL? {
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        return URL(string: "https://archive.org/download/\(itemID)/\(encoded)")
    }

    static func poster(itemID: String, posterFileName: String?, videoFileNames: [String]) -> URL {
        if let posterFileName, let url = download(itemID: itemID, fileName: posterFileName) {
            return url
        }
        if let video = videoFileNames.first {
            let stem = (video as NSString).deletingPathExtension
            if let gif = download(itemID: itemID, fileName: "\(stem).gif") {
                return gif
            }
        }
        return URL(string: "https://archive.org/services/img/\(itemID)")!
    }
}

/// Shared public-domain 1950s dance / leisure clips (Archive.org).
enum ArchiveEraClipLibrary {
    static let partyJohnnieRay = ArchiveEraClip(
        archiveItemID: "Party1950s",
        videoFileNames: ["ArthurMurrayPartyJohnnieRay.mp4", "ArthurMurrayPartyJohnnieRay.ogv"],
        posterFileName: "ArthurMurrayPartyJohnnieRay.gif"
    )

    static let bowlingFull = ArchiveEraClip(
        archiveItemID: "LetsGoBo1955",
        videoFileNames: ["LetsGoBo1955.mp4", "LetsGoBo1955_edit.mp4", "LetsGoBo1955_512kb.mp4"],
        posterFileName: "LetsGoBo1955.gif"
    )

    static let royalWedding = ArchiveEraClip(
        archiveItemID: "royalwedding1951film",
        videoFileNames: ["royal wedding (1951  film).mp4"],
        posterFileName: nil
    )

    static let rumbaMamba = ArchiveEraClip(
        archiveItemID: "50934-the-arthur-murray-steps-in-the-rumba-mamba",
        videoFileNames: ["50934+The+Arthur+Murray+Steps+In+The+Rumba+Mamba.mp4"],
        posterFileName: nil
    )

    static let all: [ArchiveEraClip] = [
        partyJohnnieRay, bowlingFull, royalWedding, rumbaMamba,
    ]
}

// MARK: - Era visuals (music decade + public-domain / CC archival media)

struct DiscoverySnippetEraVisual: Equatable {
    let snippetIndex: Int
    let eraYear: Int
    let eraEvent: String
    let clip: ArchiveEraClip
    /// Mood-matched still pulled from the internet. When set it becomes the on-screen picture.
    let imagePosterOverride: URL?
    /// When true the archival video is not played — the still image (with Ken Burns) is the visual.
    let suppressVideo: Bool

    var archiveItemID: String { clip.archiveItemID }
    var videoFileName: String? { suppressVideo ? nil : clip.videoFileNames.first }
    var videoURL: URL? { suppressVideo ? nil : clip.primaryVideoURL }
    var videoURLs: [URL] { suppressVideo ? [] : clip.videoURLs }
    var posterImageURL: URL { imagePosterOverride ?? clip.posterImageURL }

    init(
        snippetIndex: Int,
        eraYear: Int,
        eraEvent: String,
        clip: ArchiveEraClip,
        imagePosterOverride: URL? = nil,
        suppressVideo: Bool = false
    ) {
        self.snippetIndex = snippetIndex
        self.eraYear = eraYear
        self.eraEvent = eraEvent
        self.clip = clip
        self.imagePosterOverride = imagePosterOverride
        self.suppressVideo = suppressVideo
    }
}

enum DiscoveryEraMediaCatalog {
    /// Mood per **physical** discovery snippet, aligned 1:1 with `DiscoveryFlowPOC.snippetAudioStreamURLs`
    /// so the on-screen footage + colour grade fit the song actually being auditioned:
    ///   0 Echoes of Yesterday → nostalgic
    ///   1 Velvet Highway      → open road
    ///   2 Velvet Cadenza      → classical ballroom
    ///   3 Velvet Afterhours   → jazz nightclub
    ///   4 Pine Smoke Drift    → country / Americana
    ///   5 Drift Between Rooms → ambient calm
    static let snippetMoods: [MusicVisualMood] = [
        .nostalgic,
        .openRoad,
        .classicalBallroom,
        .jazzNightclub,
        .countryAmericana,
        .ambientCalm,
    ]

    static let visuals: [DiscoverySnippetEraVisual] = snippetMoods.enumerated().map { index, mood in
        DiscoverySnippetEraVisual(
            snippetIndex: index,
            eraYear: mood.eraYear,
            eraEvent: mood.eraEvent,
            clip: mood.primaryClip,
            imagePosterOverride: mood.sceneImageURL(variant: index),
            suppressVideo: mood.sceneImageURL(variant: index) != nil
        )
    }

    static func mood(for snippetIndex: Int) -> MusicVisualMood {
        guard snippetMoods.isEmpty == false else { return .nostalgic }
        return snippetMoods[snippetIndex % snippetMoods.count]
    }

    static func visual(for snippetIndex: Int) -> DiscoverySnippetEraVisual {
        let bounded = snippetIndex % visuals.count
        return visuals.first { $0.snippetIndex == bounded } ?? visuals[0]
    }
}

// MARK: - Muted looped clip inside the discovery bubble

@MainActor
final class DiscoverySnippetVideoLooper: ObservableObject {
    /// Published so SwiftUI re-binds ``DiscoveryEraVideoFill`` when the queue is replaced.
    @Published private(set) var player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var activeURL: URL?

    func play(url: URL) {
        play(urls: [url])
    }

    func play(urls: [URL]) {
        guard let first = urls.first else {
            stop()
            return
        }
        if activeURL == first, looper != nil {
            if player.rate == 0 { player.play() }
            return
        }
        tearDown()
        activeURL = first

        let item = AVPlayerItem(url: first)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        queue.play()
    }

    func stop() {
        tearDown()
    }

    private func tearDown() {
        looper?.disableLooping()
        looper = nil
        player.pause()
        activeURL = nil
        // Never call `remove(_:)` on looper-managed items — replace the queue player instead.
        player = AVQueuePlayer()
    }
}

struct DiscoverySnippetMediaFill: View {
    let visual: DiscoverySnippetEraVisual
    let player: AVPlayer
    @Binding var isMediaReady: Bool

    @State private var posterReady = false
    @State private var videoReady = false

    private var anyReady: Bool { posterReady || videoReady }

    var body: some View {
        ZStack {
            DiscoveryEraPosterImage(
                url: visual.posterImageURL,
                highResolution: true,
                isLoaded: $posterReady
            )

            if visual.videoURL != nil {
                DiscoveryEraVideoFill(player: player, isReady: $videoReady)
            }
        }
        .opacity(anyReady ? 1 : 0)
        .animation(.easeIn(duration: 0.32), value: anyReady)
        .onChange(of: visual) { _, _ in
            posterReady = false
            videoReady = false
        }
        .onChange(of: anyReady) { _, ready in
            isMediaReady = ready
        }
        .onAppear {
            isMediaReady = anyReady
        }
    }
}

private struct DiscoveryEraPosterImage: View {
    let url: URL
    var highResolution: Bool = false
    @Binding var isLoaded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kenBurnsPhase: CGFloat = 0

    private var fillScale: CGFloat { highResolution ? 1.04 : 1.14 }

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: geo.size.width * fillScale, height: geo.size.height * fillScale)
                        .offset(
                            x: reduceMotion ? 0 : kenBurnsPhase * geo.size.width * 0.03 - geo.size.width * 0.015,
                            y: reduceMotion ? 0 : kenBurnsPhase * geo.size.height * 0.022 - geo.size.height * 0.011
                        )
                        .onAppear {
                            isLoaded = true
                        }
                case .failure:
                    Color.clear
                default:
                    Color.clear
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onChange(of: url) { _, _ in
            isLoaded = false
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                kenBurnsPhase = 1
            }
        }
    }
}

private struct DiscoveryEraVideoFill: UIViewRepresentable {
    let player: AVPlayer
    @Binding var isReady: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isReady: $isReady)
    }

    func makeUIView(context: Context) -> DiscoveryEraVideoUIView {
        let view = DiscoveryEraVideoUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.onReadyForDisplay = {
            context.coordinator.markReady()
        }
        return view
    }

    func updateUIView(_ uiView: DiscoveryEraVideoUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            context.coordinator.resetReady()
            uiView.resetReadyState()
            uiView.playerLayer.player = player
        }
        uiView.onReadyForDisplay = {
            context.coordinator.markReady()
        }
    }

    static func dismantleUIView(_ uiView: DiscoveryEraVideoUIView, coordinator: Coordinator) {
        uiView.playerLayer.player = nil
        coordinator.resetReady()
    }

    final class Coordinator {
        @Binding var isReady: Bool

        init(isReady: Binding<Bool>) {
            _isReady = isReady
        }

        func markReady() {
            DispatchQueue.main.async {
                if !self.isReady {
                    self.isReady = true
                }
            }
        }

        func resetReady() {
            isReady = false
        }
    }
}

private final class DiscoveryEraVideoUIView: UIView {
    var onReadyForDisplay: (() -> Void)?
    private var didReportReady = false

    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
    }

    func resetReadyState() {
        didReportReady = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        if playerLayer.isReadyForDisplay, !didReportReady {
            didReportReady = true
            onReadyForDisplay?()
        }
    }
}

extension ArchiveEraClip {
    static let partyJohnnieRay = ArchiveEraClipLibrary.partyJohnnieRay
    static let bowlingFull = ArchiveEraClipLibrary.bowlingFull
    static let royalWedding = ArchiveEraClipLibrary.royalWedding
    static let rumbaMamba = ArchiveEraClipLibrary.rumbaMamba
}
