import AVFoundation
import SwiftUI

// MARK: - Audible track selection

struct ResidentPlaybackTrack {
    let title: String
    let audioURL: URL
}

/// The resident playlist previously changed its on-screen title and visual while continuing to play
/// the same ambient file. This catalog is now the single source of truth for both the audible track
/// and its visual, so genre changes and swipes cannot drift out of sync.
///
/// ## POC track → genre map (bundled `App/Resources/Music`)
/// Identified from discovery mood tags, royalty-free fallback names, titles, and audio character:
/// | Track | Genre | Designer icon |
/// |---|---|---|
/// | Velvet Afterhours | Jazz | Saxophone |
/// | Velvet Cadenza | Classical | Piano |
/// | Echoes of Yesterday | Pop | Solo microphone |
/// | Velvet Highway | Rock | Jukebox |
/// | Pine Smoke Drift | Country | Violin |
/// | Pine Smoke Drift (1) | Gospel | Opera singer *(interim — closest remaining stem)* |
/// | Drift Between Rooms | Soul | Woman + mic |
enum ResidentPlaybackTrackCatalog {
    /// Ordered audible track titles for a genre — the single source of truth the resident surface
    /// uses for playback, "like", and "skip / remove from playlist".
    static func titles(for genre: ResidentMusicGenre) -> [String] {
        switch genre {
        case .jazz:
            return ["Velvet Afterhours"]
        case .classical:
            return ["Velvet Cadenza"]
        case .pop:
            return ["Echoes of Yesterday"]
        case .rock:
            return ["Velvet Highway"]
        case .gospel:
            return ["Pine Smoke Drift (1)"]
        case .country:
            return ["Pine Smoke Drift"]
        case .soul:
            return ["Drift Between Rooms"]
        }
    }

    /// Canonical home genre for a bundled title (first match wins).
    static func primaryGenre(for title: String) -> ResidentMusicGenre? {
        ResidentMusicGenre.allCases.first { titles(for: $0).contains(title) }
    }

    /// Number of distinct audible tracks available for a genre.
    static func count(for genre: ResidentMusicGenre) -> Int {
        titles(for: genre).count
    }

    /// Unique audible titles across all genres — used for supervisor “suggested liked songs” picks.
    static var allUniqueTitles: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for genre in ResidentMusicGenre.allCases {
            for title in titles(for: genre) where seen.insert(title).inserted {
                ordered.append(title)
            }
        }
        return ordered.sorted()
    }

    /// Genres that can play a given catalog title (for staff captions).
    static func genres(containing title: String) -> [ResidentMusicGenre] {
        ResidentMusicGenre.allCases.filter { titles(for: $0).contains(title) }
    }

    static func track(
        for genre: ResidentMusicGenre,
        trackIndex: Int
    ) -> ResidentPlaybackTrack {
        let titles = titles(for: genre)
        let title = titles[((trackIndex % titles.count) + titles.count) % titles.count]
        return track(titled: title, genre: genre)
    }

    /// Resolve an audible track by title (used when the session queue is reordered by likes / skips).
    static func track(titled title: String, genre: ResidentMusicGenre) -> ResidentPlaybackTrack {
        ResidentPlaybackTrack(
            title: title,
            audioURL: BundledAudio.urlOrRemote(
                title,
                fallback: AmbientAudioSession.quickStartStreamURL
            )
        )
    }
}

// MARK: - Track / genre backdrop (full MP4 clips inside the resident panel)

enum ResidentPlaylistVisualCatalog {
    /// Mood that best fits the track — title keywords win, genre is the fallback.
    static func mood(for genre: ResidentMusicGenre, trackTitle: String) -> MusicVisualMood {
        MusicVisualMood.resolve(title: trackTitle, genre: genre)
    }

    /// Clip that best matches the track's mood, rotated deterministically across the mood's pool so
    /// different tracks in the same mood still get some variety — but the same track always resolves
    /// to the same clip (stable hash, not the launch-randomized `String.hashValue`).
    static func clip(
        for genre: ResidentMusicGenre,
        trackTitle: String,
        trackIndex: Int
    ) -> ArchiveEraClip {
        let pool = mood(for: genre, trackTitle: trackTitle).clipPool
        guard pool.isEmpty == false else { return .partyJohnnieRay }
        let idx = (trackIndex + StableHash.of(trackTitle)) % pool.count
        return pool[idx]
    }

    /// Scene still URL for a resident track — same resolve path the backdrop paints.
    static func sceneImageURL(
        for genre: ResidentMusicGenre,
        trackTitle: String,
        trackIndex: Int
    ) -> URL? {
        mood(for: genre, trackTitle: trackTitle)
            .sceneImageURL(variant: trackIndex + StableHash.of(trackTitle))
    }
}

/// Full-bleed muted clip — only mounted while a playlist is playing.
struct ResidentPlaylistBackdropView: View {
    let genre: ResidentMusicGenre
    let trackTitle: String
    let trackIndex: Int

    @StateObject private var videoLooper = DiscoverySnippetVideoLooper()
    @State private var playlistMediaReady = false

    private var clip: ArchiveEraClip {
        ResidentPlaylistVisualCatalog.clip(for: genre, trackTitle: trackTitle, trackIndex: trackIndex)
    }

    private var mood: MusicVisualMood {
        ResidentPlaylistVisualCatalog.mood(for: genre, trackTitle: trackTitle)
    }

    var body: some View {
        ZStack {
            DiscoverySnippetMediaFill(
                visual: discoveryVisualAdapter,
                player: videoLooper.player,
                isMediaReady: $playlistMediaReady
            )
                .scaleEffect(1.02)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Mood colour grade — makes each song/genre read distinctly while keeping footage visible.
            LinearGradient(
                colors: mood.tintColors.map { $0.opacity(0.30) },
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.softLight)
            .opacity(playlistMediaReady ? 1 : 0)

            LinearGradient(
                colors: [
                    BrandTheme.skyBackgroundTop.opacity(0.14),
                    Color.black.opacity(0.05),
                    BrandTheme.skyBackgroundDeep.opacity(0.20),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(playlistMediaReady ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        // No `.id(...)` remount — keep the media fill alive so the previous still stays visible
        // until the next cached/decoded scene image is ready (crossfade in DiscoveryEraPosterImage).
        .onAppear {
            restartVideo()
            prefetchNeighborSceneImages()
        }
        .onChange(of: trackIndex) { _, _ in
            restartVideo()
            prefetchNeighborSceneImages()
        }
        .onChange(of: trackTitle) { _, _ in
            restartVideo()
            prefetchNeighborSceneImages()
        }
        .onDisappear { videoLooper.stop() }
    }

    private func prefetchNeighborSceneImages() {
        if let url = sceneImageURL {
            SceneImageCache.prefetch(url)
        }
    }

    private var sceneImageURL: URL? {
        mood.sceneImageURL(variant: trackIndex + StableHash.of(trackTitle))
    }

    private var discoveryVisualAdapter: DiscoverySnippetEraVisual {
        DiscoverySnippetEraVisual(
            snippetIndex: trackIndex,
            eraYear: 1955,
            eraEvent: trackTitle,
            clip: clip,
            imagePosterOverride: sceneImageURL,
            suppressVideo: sceneImageURL != nil
        )
    }

    private func restartVideo() {
        let urls = discoveryVisualAdapter.videoURLs
        guard urls.isEmpty == false else {
            videoLooper.stop()
            return
        }
        videoLooper.play(urls: urls)
    }
}

/// Clips playlist media to the same circular nebula orb as discovery.
struct ResidentPlaylistPanelBackdropView: View {
    let genre: ResidentMusicGenre
    let trackTitle: String
    let trackIndex: Int
    let orbSize: CGSize
    var mediaFillScale: CGFloat = 0.90
    /// 0 = compact orb; 1 = full-page. Drives the circle→page shape morph.
    var pageExpansion: CGFloat = 0

    var body: some View {
        OrbInteriorMediaPanel(
            orbSize: orbSize,
            mediaFillScale: mediaFillScale,
            showArcFrame: false,
            pageExpansion: pageExpansion
        ) {
            ResidentPlaylistBackdropView(
                genre: genre,
                trackTitle: trackTitle,
                trackIndex: trackIndex
            )
        }
    }
}
