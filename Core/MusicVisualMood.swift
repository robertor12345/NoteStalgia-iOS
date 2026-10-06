import SwiftUI

/// Maps a piece of music (by **title keywords** first, then assigned **genre**) to the archival
/// clip + colour grade that best fits its mood.
///
/// The bundled tracks are AI-generated and carry **no genre metadata** — only titles — so the
/// title is the primary signal (e.g. "Velvet Cadenza" → classical ballroom, "Pine Smoke Drift"
/// → country/outdoors). Genre is the fallback when the title is not descriptive.
enum MusicVisualMood: CaseIterable {
    case jazzNightclub
    case classicalBallroom
    case popDanceParty
    case rockEnergetic
    case countryAmericana
    case soulSmooth
    case gospelUplift
    case nostalgic
    case openRoad
    case ambientCalm

    /// Ordered best-fit clips — index 0 is the strongest match; later entries add variety across
    /// tracks in the same mood. All clips are the app's verified public-domain Archive.org items.
    var clipPool: [ArchiveEraClip] {
        switch self {
        case .jazzNightclub: return [.rumbaMamba, .partyJohnnieRay]
        case .classicalBallroom: return [.royalWedding, .rumbaMamba]
        case .popDanceParty: return [.partyJohnnieRay, .bowlingFull]
        case .rockEnergetic: return [.partyJohnnieRay, .rumbaMamba]
        case .countryAmericana: return [.bowlingFull, .partyJohnnieRay]
        case .soulSmooth: return [.rumbaMamba, .royalWedding]
        case .gospelUplift: return [.royalWedding, .partyJohnnieRay]
        case .nostalgic: return [.partyJohnnieRay, .royalWedding]
        case .openRoad: return [.bowlingFull, .partyJohnnieRay]
        case .ambientCalm: return [.royalWedding, .rumbaMamba]
        }
    }

    var primaryClip: ArchiveEraClip { clipPool[0] }

    /// Mood-matched still imagery pulled from the internet (Wikimedia Commons — licensing is not a
    /// concern for this POC). These are shown as the resident-playlist / discovery visual so the
    /// picture on screen actually fits the song being played, instead of the generic archival dance
    /// footage. Verified to match each mood.
    var sceneImageURLs: [URL] {
        let strings: [String]
        switch self {
        case .jazzNightclub:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/9/93/%28Portrait_of_Henry_Allen%2C_Onyx%2C_New_York%2C_N.Y.%2C_ca._May_1946%29_%28LOC%29_%284843118971%29.jpg"]
        case .classicalBallroom:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Ballroom_dance_in_Somerville%2C_Massachusetts%2C_2008.jpg/1280px-Ballroom_dance_in_Somerville%2C_Massachusetts%2C_2008.jpg"]
        case .popDanceParty:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/A_Hard_Day%27s_Night_-_Beatles-inspired_Halloween_Costume_Party_%282015-10-29_21.00.44_by_LBJ_Library%29.jpg/1280px-A_Hard_Day%27s_Night_-_Beatles-inspired_Halloween_Costume_Party_%282015-10-29_21.00.44_by_LBJ_Library%29.jpg"]
        case .rockEnergetic:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Crowd_at_Knebworth_House_-_Rolling_Stones_1976.jpg/1280px-Crowd_at_Knebworth_House_-_Rolling_Stones_1976.jpg"]
        case .countryAmericana:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/Sunset_on_the_Plain_-_Flickr_-_DWRose.jpg/1280px-Sunset_on_the_Plain_-_Flickr_-_DWRose.jpg"]
        case .soulSmooth:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/John_Boutte_JazzFest_2010_microphone_high.jpg/1280px-John_Boutte_JazzFest_2010_microphone_high.jpg"]
        case .gospelUplift:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/Harlem_Gospel_Choir.jpg/1280px-Harlem_Gospel_Choir.jpg"]
        case .nostalgic:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/c/c9/Enjoying_classic_records_on_a_vintage_turntable_in_a_cozy_room_with_warm_wooden_accents.jpg/1280px-Enjoying_classic_records_on_a_vintage_turntable_in_a_cozy_room_with_warm_wooden_accents.jpg"]
        case .openRoad:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/2022_Downtown_West_Allis_Classic_Car_Show_087_%281970_Plymouth_Road_Runner%29.jpg/1280px-2022_Downtown_West_Allis_Classic_Car_Show_087_%281970_Plymouth_Road_Runner%29.jpg"]
        case .ambientCalm:
            strings = ["https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/A_Calm_Morninf_at_Glacier_Lake.jpg/1280px-A_Calm_Morninf_at_Glacier_Lake.jpg"]
        }
        return strings.compactMap(URL.init(string:))
    }

    /// Deterministic scene image for a given track/snippet position, so different tracks in the same
    /// mood can vary while a given track is always stable.
    func sceneImageURL(variant: Int) -> URL? {
        let pool = sceneImageURLs
        guard pool.isEmpty == false else { return nil }
        return pool[abs(variant) % pool.count]
    }

    /// A representative decade year — used to order discovery snippets around a resident's peak years.
    var eraYear: Int {
        switch self {
        case .jazzNightclub: return 1958
        case .classicalBallroom: return 1951
        case .popDanceParty: return 1957
        case .rockEnergetic: return 1956
        case .countryAmericana: return 1954
        case .soulSmooth: return 1960
        case .gospelUplift: return 1953
        case .nostalgic: return 1955
        case .openRoad: return 1962
        case .ambientCalm: return 1965
        }
    }

    /// Short reminiscence caption tied to the mood.
    var eraEvent: String {
        switch self {
        case .jazzNightclub: return "Late-night jazz clubs — smoky rooms and slow, velvet rhythm."
        case .classicalBallroom: return "Elegant ballrooms — orchestras, chandeliers, and graceful turns."
        case .popDanceParty: return "House-party record hops — teens dancing to the day's big hits."
        case .rockEnergetic: return "Rock-and-roll dance floors — the beat that got everyone up."
        case .countryAmericana: return "Small-town Americana — front porches, fairs, and open country."
        case .soulSmooth: return "Smooth soul evenings — warm voices and easy, swaying grooves."
        case .gospelUplift: return "Uplifting gospel gatherings — bright brass and joyful harmony."
        case .nostalgic: return "Echoes of yesterday — the songs that carry a whole life of memory."
        case .openRoad: return "The open road — chrome, highways, and the freedom of a long drive."
        case .ambientCalm: return "Quiet, drifting calm — soft light between still, peaceful rooms."
        }
    }

    /// Subtle top→bottom colour grade layered over the clip so each mood reads distinctly. Kept low
    /// contrast so the underlying footage (and visual fidelity) is preserved.
    var tintColors: [Color] {
        switch self {
        case .jazzNightclub:
            return [Color(red: 0.16, green: 0.10, blue: 0.32), Color(red: 0.42, green: 0.12, blue: 0.34)]
        case .classicalBallroom:
            return [Color(red: 0.24, green: 0.34, blue: 0.52), Color(red: 0.70, green: 0.74, blue: 0.82)]
        case .popDanceParty:
            return [Color(red: 0.92, green: 0.44, blue: 0.52), Color(red: 0.98, green: 0.72, blue: 0.56)]
        case .rockEnergetic:
            return [Color(red: 0.86, green: 0.36, blue: 0.20), Color(red: 0.56, green: 0.12, blue: 0.18)]
        case .countryAmericana:
            return [Color(red: 0.46, green: 0.56, blue: 0.36), Color(red: 0.86, green: 0.72, blue: 0.42)]
        case .soulSmooth:
            return [Color(red: 0.36, green: 0.20, blue: 0.46), Color(red: 0.64, green: 0.34, blue: 0.52)]
        case .gospelUplift:
            return [Color(red: 0.90, green: 0.72, blue: 0.34), Color(red: 0.98, green: 0.90, blue: 0.72)]
        case .nostalgic:
            return [Color(red: 0.52, green: 0.38, blue: 0.26), Color(red: 0.84, green: 0.68, blue: 0.48)]
        case .openRoad:
            return [Color(red: 0.24, green: 0.46, blue: 0.52), Color(red: 0.62, green: 0.78, blue: 0.84)]
        case .ambientCalm:
            return [Color(red: 0.28, green: 0.46, blue: 0.50), Color(red: 0.60, green: 0.58, blue: 0.74)]
        }
    }

    /// Default mood for a genre, used when a track title offers no stronger signal.
    static func forGenre(_ genre: ResidentMusicGenre) -> MusicVisualMood {
        switch genre {
        case .jazz: return .jazzNightclub
        case .classical: return .classicalBallroom
        case .pop: return .popDanceParty
        case .rock: return .rockEnergetic
        case .gospel: return .gospelUplift
        case .country: return .countryAmericana
        case .soul: return .soulSmooth
        }
    }

    /// Resolves the mood from a track title (preferred) with a genre fallback.
    static func resolve(title: String?, genre: ResidentMusicGenre?) -> MusicVisualMood {
        if let keyed = moodFromTitle(title) {
            return keyed
        }
        if let genre {
            return forGenre(genre)
        }
        return .nostalgic
    }

    /// Keyword scan over the title. Ordered so the most specific cues win.
    private static func moodFromTitle(_ title: String?) -> MusicVisualMood? {
        guard let title, title.isEmpty == false else { return nil }
        let t = title.lowercased()

        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }

        if has(["cadenza", "cadence", "concerto", "sonata", "waltz", "adagio", "nocturne"]) {
            return .classicalBallroom
        }
        if has(["afterhours", "after hours", "midnight", "jazz", "lounge", "blue note", "swing", "brass"]) {
            return .jazzNightclub
        }
        // Highway / open-road stems play under the Rock glyph (jukebox).
        if has(["highway", "road", "route", "drive", "journey", "wheels", "traffic"]) {
            return .rockEnergetic
        }
        // Pine Smoke Drift (without "(1)") is Country; the "(1)" variant is the Gospel interim stem.
        if t.contains("pine smoke drift (1)") || t.contains("pine smoke drift（1）") {
            return .gospelUplift
        }
        if has(["pine", "smoke", "prairie", "valley", "mountain", "river", "forest", "woods", "ranch", "dust", "harvest", "field"]) {
            return .countryAmericana
        }
        if has(["echo", "echoes", "yesterday", "sock hop", "memory", "memories", "remember", "old days", "days gone"]) {
            return .popDanceParty
        }
        if has(["drift between", "between rooms", "soul", "groove", "smooth", "honey"]) {
            return .soulSmooth
        }
        if has(["gospel", "hallelujah", "glory", "praise", "hymn", "choir"]) {
            return .gospelUplift
        }
        if has(["drift", "rooms", "still", "calm", "quiet", "dream", "sleep", "haze", "float", "drifting"]) {
            return .soulSmooth
        }
        if has(["rock", "electric", "wild", "fire", "thunder", "jukebox"]) {
            return .rockEnergetic
        }
        if has(["party", "dance", "hop", "twist", "boogie", "shake"]) {
            return .popDanceParty
        }
        return nil
    }
}

/// Stable, launch-independent hash for deterministic clip rotation.
///
/// Swift's `String.hashValue` is seeded randomly **per process**, so using it to pick imagery
/// makes the same track show different clips on every launch. FNV-1a is stable across launches.
enum StableHash {
    static func of(_ string: String) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Int(truncatingIfNeeded: hash & 0x7fff_ffff_ffff_ffff)
    }
}
