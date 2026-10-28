import Foundation

struct GroupSessionTrack: Identifiable, Equatable {
    let id: UUID
    let title: String
    let genre: ResidentMusicGenre
    let sourceResidentName: String
    let score: Double
    /// What actually plays: a catalogue preview (sleeve, plays once, moves on) or the bundled stem.
    var ref: ResidentTrackRef
    /// Why the model chose it for this room ("A song Irene K. loves"); nil for roster-compiled picks.
    var reason: String?

    init(id: UUID, title: String, genre: ResidentMusicGenre, sourceResidentName: String, score: Double, ref: ResidentTrackRef? = nil, reason: String? = nil) {
        self.id = id
        self.title = title
        self.genre = genre
        self.sourceResidentName = sourceResidentName
        self.score = score
        self.ref = ref ?? ResidentTrackRef.bundled(title: title, genre: genre)
        self.reason = reason
    }
}

struct GroupSessionRecord: Identifiable, Equatable, Codable {
    let id: UUID
    let date: Date
    let durationSeconds: Int
    let tracksPlayed: Int
    var moraleRating: Int?
    var alertnessRating: Int?
    var lucidityRating: Int?
    var engagementRating: Int?
    var staffNote: String?
    /// Track titles heard during the session (POC snapshot).
    var playlistSnapshot: [String]
    /// Residents who took part (empty = whole-home playlist before the planner existed).
    var participantIds: [UUID] = []
    /// The planned activity, e.g. "Classical listening circle"; nil for a whole-home playlist.
    var activityTitle: String? = nil
    var theme: GroupActivityTheme? = nil
    /// Home the session happened in and who ran it — filled when the record is written (synced to the backend).
    var homeId: UUID? = nil
    var authorAccountId: UUID? = nil
}

struct GroupSessionFeedbackDraft: Equatable, Codable {
    var morale: Int?
    var alertness: Int?
    var lucidity: Int?
    var engagement: Int?
    var note: String = ""
}

enum GroupSessionFeedbackStep: Int, CaseIterable, Identifiable {
    case morale = 0
    case alertness = 1
    case lucidity = 2
    case engagement = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .morale: return "Group morale / affect"
        case .alertness: return "Group alertness"
        case .lucidity: return "Group orientation & responsiveness"
        case .engagement: return "Social engagement"
        }
    }

    var prompt: String {
        switch self {
        case .morale: return "How would you rate the overall mood and affect in the room?"
        case .alertness: return "How alert did the group appear (arousal level)?"
        case .lucidity: return "How orientated and responsive was the group collectively?"
        case .engagement: return "How socially engaged were residents with the music intervention?"
        }
    }

    var lowCaption: String {
        switch self {
        case .morale: return "1 · Low morale / flat affect"
        case .alertness: return "1 · Very drowsy / reduced arousal"
        case .lucidity: return "1 · Disorientated / minimally responsive"
        case .engagement: return "1 · Withdrawn / passive"
        }
    }

    var highCaption: String {
        switch self {
        case .morale: return "10 · Uplifted / positive group affect"
        case .alertness: return "10 · Fully alert"
        case .lucidity: return "10 · Orientated / responsive"
        case .engagement: return "10 · Actively engaged"
        }
    }
}

/// Builds a cross-resident group playlist from favourites, genre libraries, and session telemetry.
enum GroupSessionPlaylistCompiler {
    static func compile(
        patients: [CarePatientProfile],
        sessionRecords: [CareSessionRecord],
        maxTracks: Int = 14
    ) -> [GroupSessionTrack] {
        let roster = patients.filter { !$0.isProvisional }
        guard !roster.isEmpty else { return fallbackTracks() }

        var genreScores: [ResidentMusicGenre: Double] = [:]

        for patient in roster {
            genreScores[patient.favouriteMusicGenre, default: 0] += 3
            for group in patient.genrePlaylistGroups {
                genreScores[group.genre, default: 0] += 1.5
            }
        }

        for rec in sessionRecords {
            let moodBoost = Double(rec.moodRating ?? 5) / 10.0
            let engagementBoost = Double(rec.engagement ?? rec.comfortTolerance ?? 50) / 100.0
            let weight = (moodBoost + engagementBoost) * 1.5

            if let summary = rec.residentGenresPlayedSummary {
                for genre in ResidentMusicGenre.allCases where summary.localizedCaseInsensitiveContains(genre.accessibilityLabel) {
                    genreScores[genre, default: 0] += weight * 2
                }
            }

            if let plays = rec.residentGenrePlayCount, plays > 0 {
                if let patient = roster.first(where: { $0.id == rec.patientId }) {
                    genreScores[patient.favouriteMusicGenre, default: 0] += Double(plays) * 0.4
                }
            }
        }

        let rankedGenres = genreScores.sorted { $0.value > $1.value }.map(\.key)
        let topGenres = Set(rankedGenres.prefix(4))

        // Residents' own songs: catalogue references (previews, sleeves) when the playlist carries
        // them — family picks, discovery playlists — otherwise only titles that have bundled audio
        // (discovery stub playlists carry placeholder names that would be listed as "now playing"
        // while a different track is heard).
        let audible = Set(ResidentPlaybackTrackCatalog.allUniqueTitles)
        var candidates: [GroupSessionTrack] = []
        for patient in roster {
            for group in patient.genrePlaylistGroups where topGenres.contains(group.genre) {
                let genreWeight = genreScores[group.genre] ?? 1
                for playlist in group.playlists {
                    if let refs = playlist.tracks, !refs.isEmpty {
                        for ref in refs where ref.isBundled ? audible.contains(ref.title) : ref.previewURL != nil {
                            candidates.append(
                                GroupSessionTrack(
                                    id: UUID(),
                                    title: ref.title,
                                    genre: group.genre,
                                    sourceResidentName: patient.displayName,
                                    score: genreWeight + (ref.isBundled ? 0 : 0.5),
                                    ref: ref
                                )
                            )
                        }
                    } else {
                        for title in playlist.trackTitles where audible.contains(title) {
                            candidates.append(
                                GroupSessionTrack(
                                    id: UUID(),
                                    title: title,
                                    genre: group.genre,
                                    sourceResidentName: patient.displayName,
                                    score: genreWeight
                                )
                            )
                        }
                    }
                }
            }
        }

        // Every top genre contributes at least its catalog stem, even if no resident playlist names it.
        for genre in rankedGenres.prefix(4) {
            for title in ResidentPlaybackTrackCatalog.titles(for: genre) {
                candidates.append(
                    GroupSessionTrack(
                        id: UUID(),
                        title: title,
                        genre: genre,
                        sourceResidentName: "Home favourites",
                        score: (genreScores[genre] ?? 1) * 0.5
                    )
                )
            }
        }

        var bestByTitle: [String: GroupSessionTrack] = [:]
        for track in candidates {
            if let existing = bestByTitle[track.title], existing.score >= track.score { continue }
            bestByTitle[track.title] = track
        }

        let ordered = bestByTitle.values.sorted { $0.score > $1.score }
        if ordered.isEmpty { return fallbackTracks(from: roster) }
        return Array(ordered.prefix(maxTracks))
    }

    /// The backend's picks — ranked for the whole room — lead; the roster's own songs follow; the
    /// song already playing stays first so the room hears no jump. One entry per title.
    static func merge(serverPicks: [GroupSessionTrack], into local: [GroupSessionTrack], keepingFirst current: GroupSessionTrack?, maxTracks: Int = 14) -> [GroupSessionTrack] {
        var out: [GroupSessionTrack] = []
        var seen = Set<String>()
        func add(_ track: GroupSessionTrack) {
            if seen.insert(track.title.lowercased()).inserted { out.append(track) }
        }
        if let current { add(current) }
        serverPicks.forEach(add)
        local.forEach(add)
        return Array(out.prefix(maxTracks))
    }

    /// One audible stem per genre (catalog order) when the roster offers nothing to rank.
    private static func fallbackTracks(from roster: [CarePatientProfile] = []) -> [GroupSessionTrack] {
        ResidentMusicGenre.allCases.compactMap { genre in
            ResidentPlaybackTrackCatalog.titles(for: genre).first.map { title in
                GroupSessionTrack(id: UUID(), title: title, genre: genre, sourceResidentName: "Home favourites", score: 1)
            }
        }
    }
}
