import Foundation

/// Cultural / national background used to soft-bias discovery clip order and genre playlist tuning.
/// Flag glyphs use regional-indicator emoji (Unicode) so they render on stock iOS without assets.
enum ResidentNationality: String, CaseIterable, Identifiable, Codable, Equatable {
    case unitedKingdom
    case ireland
    case india
    case pakistan
    case bangladesh
    case jamaica
    case barbados
    case trinidadAndTobago
    case poland
    case italy
    case nigeria
    case ghana
    case kenya
    case somalia
    case china
    case philippines
    case unitedStates
    case canada
    case australia
    case southAfrica
    case germany
    case france
    case spain
    case portugal
    case ukraine
    case other

    var id: String { rawValue }

    /// ISO 3166-1 alpha-2 (or `XX` for unspecified).
    var isoCountryCode: String {
        switch self {
        case .unitedKingdom: return "GB"
        case .ireland: return "IE"
        case .india: return "IN"
        case .pakistan: return "PK"
        case .bangladesh: return "BD"
        case .jamaica: return "JM"
        case .barbados: return "BB"
        case .trinidadAndTobago: return "TT"
        case .poland: return "PL"
        case .italy: return "IT"
        case .nigeria: return "NG"
        case .ghana: return "GH"
        case .kenya: return "KE"
        case .somalia: return "SO"
        case .china: return "CN"
        case .philippines: return "PH"
        case .unitedStates: return "US"
        case .canada: return "CA"
        case .australia: return "AU"
        case .southAfrica: return "ZA"
        case .germany: return "DE"
        case .france: return "FR"
        case .spain: return "ES"
        case .portugal: return "PT"
        case .ukraine: return "UA"
        case .other: return "XX"
        }
    }

    var displayName: String {
        switch self {
        case .unitedKingdom: return "United Kingdom"
        case .ireland: return "Ireland"
        case .india: return "India"
        case .pakistan: return "Pakistan"
        case .bangladesh: return "Bangladesh"
        case .jamaica: return "Jamaica"
        case .barbados: return "Barbados"
        case .trinidadAndTobago: return "Trinidad and Tobago"
        case .poland: return "Poland"
        case .italy: return "Italy"
        case .nigeria: return "Nigeria"
        case .ghana: return "Ghana"
        case .kenya: return "Kenya"
        case .somalia: return "Somalia"
        case .china: return "China"
        case .philippines: return "Philippines"
        case .unitedStates: return "United States"
        case .canada: return "Canada"
        case .australia: return "Australia"
        case .southAfrica: return "South Africa"
        case .germany: return "Germany"
        case .france: return "France"
        case .spain: return "Spain"
        case .portugal: return "Portugal"
        case .ukraine: return "Ukraine"
        case .other: return "Other / prefer not to say"
        }
    }

    /// Regional-indicator flag emoji, or a neutral globe for unspecified.
    var flagEmoji: String {
        guard isoCountryCode != "XX", isoCountryCode.count == 2 else { return "🌍" }
        return isoCountryCode.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
            guard let flagScalar = UnicodeScalar(127397 + scalar.value) else { return }
            result.unicodeScalars.append(flagScalar)
        }
    }

    var menuLabel: String { "\(flagEmoji)  \(displayName)" }

    /// Genres that tend to land well for this background — ordered highest affinity first.
    var preferredGenres: [ResidentMusicGenre] {
        switch self {
        case .unitedKingdom:
            return [.classical, .pop, .rock, .jazz]
        case .ireland:
            return [.country, .classical, .gospel, .pop]
        case .india, .pakistan, .bangladesh:
            return [.classical, .soul, .pop]
        case .jamaica, .barbados, .trinidadAndTobago:
            return [.soul, .gospel, .pop, .jazz]
        case .poland, .ukraine, .germany:
            return [.classical, .gospel, .pop]
        case .italy, .france, .spain, .portugal:
            return [.classical, .pop, .soul]
        case .nigeria, .ghana, .kenya, .somalia:
            return [.gospel, .soul, .pop]
        case .china:
            return [.classical, .pop, .soul]
        case .philippines:
            return [.pop, .gospel, .classical]
        case .unitedStates:
            return [.jazz, .country, .soul, .gospel, .rock]
        case .canada, .australia:
            return [.pop, .rock, .country, .classical]
        case .southAfrica:
            return [.gospel, .soul, .jazz, .pop]
        case .other:
            return [.classical, .pop, .jazz]
        }
    }

    /// Soft weight 0…1 used when ranking genre candidates and discovery moods.
    func genreAffinity(for genre: ResidentMusicGenre) -> Double {
        guard let rank = preferredGenres.firstIndex(of: genre) else { return 0.12 }
        let steps = max(preferredGenres.count - 1, 1)
        return 1.0 - (Double(rank) / Double(steps)) * 0.55
    }

    func moodAffinity(for mood: MusicVisualMood) -> Double {
        let genres = mood.associatedResidentGenres
        guard genres.isEmpty == false else { return 0.2 }
        return genres.map { genreAffinity(for: $0) }.max() ?? 0.2
    }

    /// Default for UK care-home demos when a profile has no explicit selection yet.
    static let `default`: ResidentNationality = .unitedKingdom

    /// UK first, then A–Z by display name, with “Other” last.
    static var menuOrder: [ResidentNationality] {
        let middle = allCases
            .filter { $0 != .unitedKingdom && $0 != .other }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return [.unitedKingdom] + middle + [.other]
    }
}

extension MusicVisualMood {
    /// Genres this discovery visual most strongly suggests — used for nationality soft-bias.
    var associatedResidentGenres: [ResidentMusicGenre] {
        switch self {
        case .jazzNightclub: return [.jazz]
        case .classicalBallroom: return [.classical]
        case .popDanceParty: return [.pop]
        case .rockEnergetic: return [.rock]
        case .countryAmericana: return [.country]
        case .soulSmooth: return [.soul]
        case .gospelUplift: return [.gospel]
        case .nostalgic: return [.pop, .classical, .soul]
        case .openRoad: return [.rock, .country, .pop]
        case .ambientCalm: return [.classical, .soul]
        }
    }
}

/// Combines discovery sentiment candidates with nationality genre affinity.
enum ResidentNationalityMusicBias {
    /// Reorders / pads sentiment-driven genre candidates using nationality preference weights.
    static func rankedGenreCandidates(
        sentimentCandidates: [ResidentMusicGenre],
        nationality: ResidentNationality,
        limit: Int
    ) -> [ResidentMusicGenre] {
        var seen = Set<ResidentMusicGenre>()
        var ranked: [ResidentMusicGenre] = []

        let scoredSentiment = sentimentCandidates
            .map { ($0, nationality.genreAffinity(for: $0) + 0.35) }
            .sorted { $0.1 > $1.1 }

        for (genre, _) in scoredSentiment where seen.insert(genre).inserted {
            ranked.append(genre)
            if ranked.count >= limit { return ranked }
        }

        for genre in nationality.preferredGenres where seen.insert(genre).inserted {
            ranked.append(genre)
            if ranked.count >= limit { return ranked }
        }

        for genre in ResidentMusicGenre.allCases where seen.insert(genre).inserted {
            ranked.append(genre)
            if ranked.count >= limit { return ranked }
        }
        return ranked
    }
}
