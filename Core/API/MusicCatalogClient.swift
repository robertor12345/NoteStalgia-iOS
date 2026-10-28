import Foundation

/// Song search, discovery planning and recommendations against the backend. Every call is a thin
/// typed wrapper over `APIClient`; callers decide what to do offline.
enum MusicCatalogClient {
    struct SearchResponse: Decodable {
        var tracks: [APITrack]
        var upstream: String?
    }

    static func search(query: String, genre: ResidentMusicGenre? = nil, limit: Int = 20) async throws -> [ResidentTrackRef] {
        var params = ["q": query, "limit": String(limit)]
        if let genre { params["genre"] = genre.rawValue }
        let response: SearchResponse = try await APIClient.shared.get("music/search", query: params)
        var refs = response.tracks.compactMap { $0.ref(fallbackGenre: genre) }
        // Apple rate-limits the Worker's shared egress: when the backend could not reach iTunes, this
        // device asks iTunes itself and hands the results to the Worker, which maps and keeps them.
        if genre == nil, refs.count < limit,
           ITunesDirectSearch.upstreamStatesNeedingFallback.contains(response.upstream ?? ""),
           let direct = try? await ITunesDirectSearch.results(term: query), !direct.isEmpty,
           let ingested: SearchResponse = try? await APIClient.shared.post("music/tracks/ingest", body: ITunesDirectSearch.IngestBody(results: direct)) {
            let known = Set(refs.map(\.id))
            refs += ingested.tracks.compactMap { $0.ref() }.filter { !known.contains($0.id) }
        }
        return refs
    }

    private struct ExpandBody: Encodable {
        var artist: String
    }

    /// Grows the catalogue around an artist the resident loves so the recommender has similar songs
    /// to offer. The Worker tries its own (cached, rate-limited) upstream call; when Apple blocks it,
    /// this device searches iTunes by artist and hands the artist's own songs to the Worker.
    @discardableResult
    static func expandArtist(_ artist: String) async throws -> Int {
        let response: SearchResponse = try await APIClient.shared.post("music/artists/expand", body: ExpandBody(artist: artist))
        var count = response.tracks.count
        if ITunesDirectSearch.upstreamStatesNeedingFallback.contains(response.upstream ?? ""),
           let direct = try? await ITunesDirectSearch.results(term: artist, limit: 25, attribute: "artistTerm") {
            let wanted = artistKey(artist)
            let own = direct.filter { artistKey($0.artistName ?? "") == wanted }
            if !own.isEmpty,
               let ingested: SearchResponse = try? await APIClient.shared.post("music/tracks/ingest", body: ITunesDirectSearch.IngestBody(results: Array(own.prefix(25)), artist: artist)) {
                count += ingested.tracks.count
            }
        }
        return count
    }

    /// Mirrors the Worker's `normalise` closely enough to keep tributes and covers out.
    private static func artistKey(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func browse(genre: ResidentMusicGenre, limit: Int = 40) async throws -> [ResidentTrackRef] {
        let response: SearchResponse = try await APIClient.shared.get("music/browse", query: ["genre": genre.rawValue, "limit": String(limit)])
        return response.tracks.compactMap { $0.ref(fallbackGenre: genre) }
    }

    private struct PlanResponse: Decodable {
        var planId: String
        var snippets: [APIPlannedSnippet]
    }

    private static func plan(from response: PlanResponse) -> DiscoveryPlan {
        DiscoveryPlan(planId: response.planId, snippets: response.snippets.map(\.ref), whys: response.snippets.map(\.why))
    }

    /// Seven snippets for a resident the server knows.
    static func discoveryPlan(residentId: UUID) async throws -> DiscoveryPlan {
        plan(from: try await APIClient.shared.get("residents/\(residentId.uuidString.lowercased())/discovery/plan"))
    }

    struct ColdStart: Encodable {
        var age: Int
        var nationality: ResidentNationality
        var favourite: ResidentMusicGenre?
        var picks: [Pick]?
    }

    struct Pick: Encodable {
        var trackId: String
        var sentiment: String
    }

    /// Seven snippets for a resident who only exists on this iPad so far (mid-discovery).
    static func coldDiscoveryPlan(age: Int, nationality: ResidentNationality, favourite: ResidentMusicGenre?) async throws -> DiscoveryPlan {
        plan(from: try await APIClient.shared.post("discovery/cold/plan", body: ColdStart(age: age, nationality: nationality, favourite: favourite, picks: nil)))
    }

    private struct ResultsBody: Encodable {
        var planId: String?
        var picks: [Pick]
    }

    static func discoveryResults(residentId: UUID, planId: String?, picks: [Pick]) async throws -> DiscoveryOutcome {
        try await APIClient.shared.post("residents/\(residentId.uuidString.lowercased())/discovery/results", body: ResultsBody(planId: planId, picks: picks))
    }

    static func coldDiscoveryResults(age: Int, nationality: ResidentNationality, favourite: ResidentMusicGenre?, picks: [Pick]) async throws -> DiscoveryOutcome {
        try await APIClient.shared.post("discovery/cold/results", body: ColdStart(age: age, nationality: nationality, favourite: favourite, picks: picks))
    }

    private struct RecommendationsResponse: Decodable {
        var queues: [APIGenreQueue]
    }

    static func recommendations(residentId: UUID, genre: ResidentMusicGenre? = nil, limit: Int = 8) async throws -> [APIGenreQueue] {
        var params = ["limit": String(limit)]
        if let genre { params["genre"] = genre.rawValue }
        let response: RecommendationsResponse = try await APIClient.shared.get("residents/\(residentId.uuidString.lowercased())/recommendations", query: params)
        return response.queues
    }

    struct GroupPlaylist {
        var genres: [ResidentMusicGenre]
        var tracks: [ResidentTrackRef]
        /// Track id → one line ("A song Irene K. loves").
        var reasons: [String: String]
        /// Track id → the residents it was chosen for.
        var champions: [String: [String]]
    }

    private struct GroupPlaylistBody: Encodable {
        var residentIds: [String]
        var genres: [ResidentMusicGenre]?
        var limit: Int
    }

    private struct GroupPlaylistResponse: Decodable {
        var genres: [ResidentMusicGenre]
        var tracks: [APITrack]
        var reasons: [String: String]?
        var champions: [String: [String]]?
    }

    /// A playlist ranked by every participant's taste profile at once (`POST /homes/{id}/group/playlist`).
    static func groupPlaylist(homeId: UUID, residentIds: [UUID], genres: [ResidentMusicGenre], limit: Int = 14) async throws -> GroupPlaylist {
        let body = GroupPlaylistBody(residentIds: residentIds.map { $0.uuidString.lowercased() }, genres: genres.isEmpty ? nil : genres, limit: limit)
        let response: GroupPlaylistResponse = try await APIClient.shared.post("homes/\(homeId.uuidString.lowercased())/group/playlist", body: body)
        return GroupPlaylist(genres: response.genres, tracks: response.tracks.compactMap { $0.ref() }, reasons: response.reasons ?? [:], champions: response.champions ?? [:])
    }

    static func sendSignals(residentId: UUID, batch: SignalBatch) async throws {
        let _: EmptyResponse = try await APIClient.shared.post("residents/\(residentId.uuidString.lowercased())/signals", body: batch)
    }
}
