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
enum ResidentPlaybackTrackCatalog {
    static func track(
        for genre: ResidentMusicGenre,
        trackIndex: Int
    ) -> ResidentPlaybackTrack {
        let titles: [String]
        switch genre {
        case .jazz:
            titles = ["Velvet Afterhours", "Echoes of Yesterday"]
        case .classical:
            titles = ["Velvet Cadenza", "Drift Between Rooms"]
        case .pop:
            titles = ["Velvet Highway", "Echoes of Yesterday"]
        case .rock:
            titles = ["Velvet Highway", "Pine Smoke Drift"]
        case .gospel:
            titles = ["Echoes of Yesterday", "Velvet Cadenza"]
        case .country:
            titles = ["Pine Smoke Drift", "Velvet Highway"]
        case .soul:
            titles = ["Velvet Afterhours", "Drift Between Rooms"]
        }

        let title = titles[trackIndex % titles.count]
        return ResidentPlaybackTrack(
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
        .id("\(genre.rawValue)-\(trackIndex)-\(trackTitle)-\(clip.archiveItemID)")
        .onAppear { restartVideo() }
        .onChange(of: trackIndex) { _, _ in
            playlistMediaReady = false
            restartVideo()
        }
        .onChange(of: trackTitle) { _, _ in
            playlistMediaReady = false
            restartVideo()
        }
        .onDisappear { videoLooper.stop() }
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
