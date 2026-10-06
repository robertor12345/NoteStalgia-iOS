import SwiftUI
import UIKit

/// Picks the first SF Symbol name the current OS actually ships (many instrument glyphs vary by SDK).
enum SFCompat {
    nonisolated static func resolve(_ names: String...) -> String {
        resolve(Array(names))
    }

    nonisolated static func resolve(_ names: [String]) -> String {
        for name in names where UIImage(systemName: name) != nil {
            return name
        }
        return "music.note"
    }
}

/// Touch-first genres for resident iPad — icons only on screen; labels for VoiceOver.
enum ResidentMusicGenre: String, CaseIterable, Identifiable, Codable, Equatable {
    case jazz
    case classical
    case pop
    case rock
    case gospel
    case country
    case soul

    var id: String { rawValue }

    var accessibilityLabel: String {
        rawValue.capitalized
    }

    /// Custom circular artwork for the resident playlist surface (and staff genre chips).
    var artworkAssetName: String {
        switch self {
        case .jazz: return "GenreJazz"
        case .classical: return "GenreClassical"
        case .pop: return "GenrePop"
        case .rock: return "GenreRock"
        case .gospel: return "GenreGospel"
        case .country: return "GenreCountry"
        case .soul: return "GenreSoul"
        }
    }

    /// Instrument-first SF Symbols with fallbacks — used only where custom artwork isn't shown.
    var iconName: String {
        switch self {
        case .jazz:
            return SFCompat.resolve(
                "saxophone.fill", "saxophone", "music.mic", "wind.instrument.fill", "tuningfork", "music.note"
            )
        case .classical:
            return SFCompat.resolve("pianokeys", "music.note.list", "tuningfork", "music.note")
        case .pop:
            return SFCompat.resolve("mic.circle.fill", "mic.fill", "music.mic", "music.note")
        case .rock:
            return SFCompat.resolve("guitars.fill", "guitar.fill", "guitars", "music.quarternote.3")
        case .gospel:
            return SFCompat.resolve("trumpet.fill", "trumpet", "speaker.wave.2.fill", "music.quarternote.3")
        case .country:
            return SFCompat.resolve("banjo.fill", "banjo", "guitars.fill", "guitars", "guitars.case.fill")
        case .soul:
            return SFCompat.resolve("headphones", "headphones.circle", "music.note.list", "music.note")
        }
    }

    /// Session & roster tints — sky blue, sage green, and peach pastels (not traffic-light primaries).
    var accent: Color {
        switch self {
        case .jazz: return BrandTheme.goldSoft.opacity(0.88)
        case .classical: return Color(red: 0.62, green: 0.80, blue: 0.94).opacity(0.78)
        case .pop: return Color(red: 0.78, green: 0.86, blue: 0.98).opacity(0.82)
        case .rock: return Color(red: 0.48, green: 0.62, blue: 0.58).opacity(0.78)
        case .gospel: return Color(red: 1.00, green: 0.82, blue: 0.72).opacity(0.84)
        case .country: return BrandTheme.gold.opacity(0.78)
        case .soul: return Color(red: 0.58, green: 0.74, blue: 0.82).opacity(0.78)
        }
    }

    /// Saturated instrument icon tint for resident glyph buttons (readable on white puck).
    var glyphIconColor: Color {
        switch self {
        case .jazz: return Color(red: 0.62, green: 0.42, blue: 0.14)
        case .classical: return Color(red: 0.16, green: 0.44, blue: 0.68)
        case .pop: return Color(red: 0.22, green: 0.38, blue: 0.72)
        case .rock: return Color(red: 0.20, green: 0.38, blue: 0.34)
        case .gospel: return Color(red: 0.72, green: 0.38, blue: 0.22)
        case .country: return Color(red: 0.58, green: 0.40, blue: 0.16)
        case .soul: return Color(red: 0.24, green: 0.36, blue: 0.58)
        }
    }
}

enum ResidentTrafficMood: Int, CaseIterable, Identifiable {
    case low = 0
    case mid = 1
    case high = 2
    var id: Int { rawValue }
    /// Muted “traffic” semantics for **profile / intake** only — not used on the resident music surface.
    var color: Color {
        switch self {
        case .low: return Color(red: 0.62, green: 0.78, blue: 0.92).opacity(0.82)
        case .mid: return BrandTheme.goldSoft.opacity(0.88)
        case .high: return BrandTheme.gold.opacity(0.82)
        }
    }
    var iconName: String {
        switch self {
        case .low:
            return SFCompat.resolve("moon.zzz.fill", "moon.zzz", "moon.stars.fill", "moon.fill")
        case .mid:
            return SFCompat.resolve("cloud.sun.fill", "cloud.sun", "sun.haze.fill", "cloud.fill")
        case .high:
            return SFCompat.resolve("sun.horizon.fill", "sun.max.fill", "sun.min.fill")
        }
    }
}

enum ResidentFaceMood: Int, CaseIterable, Identifiable {
    case sad = 0
    case neutral = 1
    case happy = 2
    var id: Int { rawValue }
    var iconName: String {
        switch self {
        case .sad:
            return SFCompat.resolve("face.dashed.fill", "face.dashed", "face.frown.fill")
        case .neutral:
            return SFCompat.resolve("face.smiling", "face.smiling.inverse")
        case .happy:
            return SFCompat.resolve("face.smiling.fill", "face.smiling")
        }
    }
}
