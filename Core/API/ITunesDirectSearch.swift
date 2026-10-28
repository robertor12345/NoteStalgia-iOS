import Foundation

/// The device's own call to the iTunes Search API. Apple rate-limits the Worker's shared egress
/// (HTTP 429 seen from the deployed Worker), so when the backend reports its upstream as blocked or
/// throttled the iPad searches itunes.apple.com itself and hands the raw results to
/// `POST /music/tracks/ingest`, which maps genres, stores them for every device and returns
/// catalogue tracks. Demo-only use of Apple previews; results always link back to the store.
enum ITunesDirectSearch {
    /// Raw iTunes result fields the Worker's `trackInputsFrom` reads; passed through unchanged.
    struct RawResult: Codable {
        var wrapperType: String?
        var kind: String?
        var trackId: Int?
        var trackName: String?
        var artistName: String?
        var collectionName: String?
        var primaryGenreName: String?
        var releaseDate: String?
        var previewUrl: String?
        var artworkUrl100: String?
        var trackViewUrl: String?
        var trackTimeMillis: Int?
        var trackExplicitness: String?
        var isStreamable: Bool?
    }

    struct IngestBody: Encodable {
        var results: [RawResult]
        /// Set when the results are an artist expansion run on the Worker's behalf.
        var artist: String? = nil
    }

    private struct Envelope: Decodable {
        var results: [RawResult]
    }

    static let upstreamStatesNeedingFallback: Set<String> = ["blocked", "throttled", "error"]

    /// Playable, non-explicit songs for the term (UK storefront), or an empty list on any failure.
    static func results(term: String, limit: Int = 25, attribute: String? = nil) async throws -> [RawResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: "gb"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "lang", value: "en_gb"),
        ]
        if let attribute { components.queryItems?.append(URLQueryItem(name: "attribute", value: attribute)) }
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("NoteStalgia-iOS/0.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return try JSONDecoder().decode(Envelope.self, from: data).results
            .filter { $0.kind == "song" && $0.trackId != nil && $0.previewUrl != nil && $0.trackExplicitness != "explicit" }
            .prefix(25)
            .map { $0 }
    }
}
