import Foundation

/// POC: after discovery, chooses **genre buckets** to add (or grows an encore list) based on traffic-light summaries.
///
/// Heuristic only: heavier **unpleasant** → prioritize calmer genres; heavier **pleasant** → add breadth / rhythm;
/// middling mixes get a shorter balanced sprinkle. Resident sandbox reads `genrePlaylistGroups` verbatim.
enum DiscoveryPlaylistTuning {
    private static let maxNewGenresPerPass = 3

    /// Mutates `patient.genrePlaylistGroups` (and sometimes `favouriteMusicGenre`) in place.
    /// Sentiment chooses the broad lane; nationality re-ranks and pads genre candidates.
    static func applyDiscoveryResults(_ results: [DiscoverySnippetResult], to patient: inout CarePatientProfile) {
        guard results.count >= DiscoveryFlowPOC.snippetCount else { return }

        let unpleasant = results.filter { $0.sentiment == .unpleasant }.count
        let pleasant = results.filter { $0.sentiment == .pleasant }.count

        let sentimentCandidates: [ResidentMusicGenre]
        if unpleasant > pleasant && unpleasant >= 2 {
            sentimentCandidates = [.classical, .gospel, .soul, .country]
        } else if pleasant > unpleasant && pleasant >= 2 {
            sentimentCandidates = [.jazz, .pop, .rock, .soul]
        } else {
            sentimentCandidates = [.classical, .pop, .jazz]
        }

        let candidates = ResidentNationalityMusicBias.rankedGenreCandidates(
            sentimentCandidates: sentimentCandidates,
            nationality: patient.nationality,
            limit: maxNewGenresPerPass + 2
        )

        var groups = patient.genrePlaylistGroups
        let owned = Set(groups.map(\.genre))
        let newGenres = candidates.filter { !owned.contains($0) }.prefix(maxNewGenresPerPass)

        for genre in newGenres {
            groups.append(stubGenreGroup(for: genre))
        }

        if newGenres.isEmpty {
            encoreOncePreferring(
                groups: &groups,
                primary: patient.favouriteMusicGenre,
                fallbackGenre: candidates.first(where: { owned.contains($0) })
            )
        }

        patient.genrePlaylistGroups = groups

        if unpleasant >= max(pleasant, unpleasant) && unpleasant >= 4 {
            let calmPick = patient.nationality.preferredGenres.first(where: {
                [.classical, .gospel, .soul].contains($0)
            }) ?? .classical
            patient.favouriteMusicGenre = calmPick
        } else if pleasant >= max(pleasant, unpleasant) && pleasant >= 4 {
            if patient.favouriteMusicGenre == .classical || patient.favouriteMusicGenre == .gospel {
                let preferredUpbeat = patient.nationality.preferredGenres.first(where: {
                    [.pop, .jazz, .soul, .rock].contains($0)
                })
                let hasPreferred = preferredUpbeat.map { genre in groups.contains(where: { $0.genre == genre }) } ?? false
                if let preferredUpbeat, hasPreferred {
                    patient.favouriteMusicGenre = preferredUpbeat
                } else {
                    let hasPop = groups.contains(where: { $0.genre == .pop })
                    patient.favouriteMusicGenre = hasPop ? .pop : .jazz
                }
            }
        } else if let topNational = patient.nationality.preferredGenres.first,
                  groups.contains(where: { $0.genre == topNational }) {
            // Light confirm — keep favourite aligned with nationality when discovery was mixed.
            if patient.favouriteMusicGenre != topNational,
               patient.nationality.genreAffinity(for: patient.favouriteMusicGenre) < 0.45 {
                patient.favouriteMusicGenre = topNational
            }
        }
    }

    private static func encoreOncePreferring(groups: inout [CareGenrePlaylistGroup], primary: ResidentMusicGenre, fallbackGenre: ResidentMusicGenre?) {
        if appendEncoreIfMissing(genre: primary, groups: &groups) { return }
        if let fb = fallbackGenre, appendEncoreIfMissing(genre: fb, groups: &groups) { return }
        guard let ix = groups.indices.first else { return }
        let g = groups[ix].genre
        if groups[ix].playlists.contains(where: { $0.title.hasPrefix("Discovery encore") }) { return }
        groups[ix].playlists.append(stubEncore(for: g))
    }

    /// Returns whether an encore playlist was appended.
    @discardableResult
    private static func appendEncoreIfMissing(genre: ResidentMusicGenre, groups: inout [CareGenrePlaylistGroup]) -> Bool {
        guard let ix = groups.firstIndex(where: { $0.genre == genre }) else {
            groups.append(stubGenreGroup(for: genre, encoreOnly: true))
            return true
        }
        if groups[ix].playlists.contains(where: { $0.title.hasPrefix("Discovery encore") }) { return false }
        groups[ix].playlists.append(stubEncore(for: genre))
        return true
    }

    static func stubGenreGroup(for genre: ResidentMusicGenre, encoreOnly: Bool = false) -> CareGenrePlaylistGroup {
        CareGenrePlaylistGroup(genre: genre, playlists: [encoreOnly ? stubEncore(for: genre) : stubPrimary(for: genre)])
    }

    private static func stubPrimary(for genre: ResidentMusicGenre) -> CarePlaylistEntry {
        CarePlaylistEntry(
            id: UUID(),
            title: "Discovery \(genre.accessibilityLabel) — gentle start",
            trackCount: 8,
            durationMinutes: 24,
            trackTitles: DiscoveryStubTracks.titles(for: genre, variant: .primary)
        )
    }

    private static func stubEncore(for genre: ResidentMusicGenre) -> CarePlaylistEntry {
        CarePlaylistEntry(
            id: UUID(),
            title: "Discovery encore · \(genre.accessibilityLabel)",
            trackCount: 6,
            durationMinutes: 18,
            trackTitles: DiscoveryStubTracks.titles(for: genre, variant: .encore)
        )
    }
}

private enum DiscoveryStubTracks {
    enum Variant { case primary, encore }

    static func titles(for genre: ResidentMusicGenre, variant: Variant) -> [String] {
        switch variant {
        case .primary:
            switch genre {
            case .jazz: return ["Muted brass swell", "Soft brush taps", "Late lamppost blues", "Whisper reed", "Two-step hush"]
            case .classical: return ["Morning etude", "Slow arco line", "Chapel light pad", "Solo piano veil", "Gentle resolution"]
            case .pop: return ["Radio glow", "Soft hook loop", "Window seat hum", "Summer tape warmth", "Evening refrain"]
            case .rock: return ["Warm amp bloom", "Clean arpeggio", "Quiet bridge", "Held power chord fade", "Side-stage hush"]
            case .gospel: return ["Hall hum", "Solo verse air", "Choir swell — soft", "Organ pad bloom", "Tender Amen"]
            case .country: return ["Front porch sway", "Acoustic dusk", "Distant freight rhythm", "Lamplight refrain", "Dust road calm"]
            case .soul: return ["Ribbon mic breath", "Soft Rhodes halo", "Backbeat pillow", "Vocal warmth bloom", "Dim club outro"]
            }
        case .encore:
            switch genre {
            case .jazz: return ["One more refrain", "Sax breath tail", "Curtain hiss"]
            case .classical: return ["Single chord echo", "Library quiet", "Nocturne tail"]
            case .pop: return ["Radio tail", "One-line hook", "Soft fade beat"]
            case .rock: return ["Amp hiss calm", "String decay", "Last bar rest"]
            case .gospel: return ["Hall tail", "Solo hum", "Pad release"]
            case .country: return ["Porch last chord", "Crickets pad", "Gentle strum fade"]
            case .soul: return ["Ribbon tail", "Room reverb bloom", "Last breath note"]
            }
        }
    }
}
