import Foundation

/// A playable song reference. Until now every signal keyed on a title that doubled as the bundled
/// filename; refs carry a stable id (`bundled:<title>` or `itunes:<trackId>`) and, for catalogue
/// tracks, the 30-second preview on Apple's CDN that the player streams directly.
struct ResidentTrackRef: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var artist: String?
    var genre: ResidentMusicGenre
    var previewURL: URL?
    var artworkURL: URL?
    var trackViewURL: URL?
    var eraYear: Int?

    var isBundled: Bool { id.hasPrefix("bundled:") }

    /// What the player opens: the preview for catalogue tracks, the bundled stem otherwise.
    var audioURL: URL {
        if let previewURL, !isBundled { return previewURL }
        return BundledAudio.urlOrRemote(title, fallback: AmbientAudioSession.quickStartStreamURL)
    }

    /// Apple's artwork URLs end in `/600x600bb.jpg`; the CDN serves other square sizes from the same
    /// path. 1200 for the full-page backdrop and the discovery orb on an iPad, 200 for thumbnails.
    func artworkURL(side: Int) -> URL? {
        guard let artworkURL else { return nil }
        let rewritten = artworkURL.absoluteString.replacingOccurrences(
            of: #"/\d{2,4}x\d{2,4}bb\."#, with: "/\(side)x\(side)bb.", options: .regularExpression
        )
        return URL(string: rewritten) ?? artworkURL
    }

    /// Staff-facing caption: "Vera Lynn · 1939".
    var caption: String {
        [artist, eraYear.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    static func bundled(title: String, genre: ResidentMusicGenre) -> ResidentTrackRef {
        ResidentTrackRef(id: "bundled:\(title)", title: title, artist: nil, genre: genre, previewURL: nil, artworkURL: nil, trackViewURL: nil, eraYear: nil)
    }

    /// The seven stems, one per genre — the offline queue and the fallback for an empty catalogue.
    static func bundledQueue(for genre: ResidentMusicGenre) -> [ResidentTrackRef] {
        ResidentPlaybackTrackCatalog.titles(for: genre).map { bundled(title: $0, genre: genre) }
    }
}

// MARK: - Wire shapes from the backend (contracts/openapi.yaml)

struct APITrack: Decodable {
    var id: String
    var title: String
    var artist: String
    var album: String?
    var genre: ResidentMusicGenre?
    var eraYear: Int?
    var previewUrl: URL
    var artworkUrl: URL?
    var trackViewUrl: URL?
    var durationMs: Int?

    func ref(fallbackGenre: ResidentMusicGenre? = nil) -> ResidentTrackRef? {
        guard let genre = genre ?? fallbackGenre else { return nil }
        return ResidentTrackRef(id: id, title: title, artist: artist, genre: genre, previewURL: previewUrl, artworkURL: artworkUrl, trackViewURL: trackViewUrl, eraYear: eraYear)
    }
}

struct APIPlannedSnippet: Decodable {
    var slot: Int
    var trackId: String
    var genre: ResidentMusicGenre
    var title: String
    var artist: String
    var eraYear: Int?
    var previewUrl: URL?
    var artworkUrl: URL?
    var trackViewUrl: URL?
    var why: String

    var ref: ResidentTrackRef {
        ResidentTrackRef(id: trackId, title: title, artist: artist, genre: genre, previewURL: previewUrl, artworkURL: artworkUrl, trackViewURL: trackViewUrl, eraYear: eraYear)
    }
}

struct APIGenreQueue: Decodable {
    var genre: ResidentMusicGenre
    var tracks: [APITrack]
    var reasons: [String: String]?

    var refs: [ResidentTrackRef] { tracks.compactMap { $0.ref(fallbackGenre: genre) } }
}

struct DiscoveryPlan: Equatable {
    var planId: String
    var snippets: [ResidentTrackRef]
    var whys: [String]
}

struct DiscoveryOutcome: Decodable {
    struct Taste: Decodable {
        var favourite: ResidentMusicGenre
    }

    var taste: Taste
    var profilePlaylists: [APIGenreQueue]
    var surfaceQueues: [APIGenreQueue]
}

/// One listening-telemetry batch per session (`POST /residents/{id}/signals`).
struct SignalBatch: Codable {
    struct Event: Codable {
        var kind: String
        var at: Date
        var trackId: String?
        var genre: ResidentMusicGenre?
        var value: Double?
        var sentiment: String?
        var frustrated: Bool?
    }

    var batchId: UUID
    var sessionId: UUID?
    var deviceId: String
    var at: Date
    var events: [Event]
}
