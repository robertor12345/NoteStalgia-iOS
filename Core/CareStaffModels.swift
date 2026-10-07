import Foundation

// Portrait assets (`PortraitWoman01…06`, `PortraitMan01…06`) live in `App/Assets.xcassets` and are
// assigned per resident by `ResidentPortraitCatalog`. Replace with your own licensed imagery and
// consent before shipping.

/// Person-centred profile for one-to-one calm moments — sensory hints, life themes, and adaptive sound shaping preferences.
struct CarePatientProfile: Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var careContextLabel: String
    var likes: [String]
    var dislikes: [String]
    /// Lighting / glare hints for a low-stimulation space (Namaste-style calm room).
    var preferredLight: String
    /// Scent guidance — gentle, optional; many homes avoid strong perfume.
    var scentGuidance: String
    /// Touch consent / comfort (e.g. hand rest OK, prefers not).
    var touchComfortNotes: String
    /// Reminiscence anchors — garden, seaside, faith, baking, etc.
    var comfortThemes: [String]
    /// When true, the mixer favours very soft onsets and avoids abrupt changes.
    var prefersGentleSoundOnsets: Bool
    /// 0 = slower / gentler pacing, 1 = slightly brighter tempo.
    var musicTempoBias: Double
    /// 0 = more nature-forward, 1 = more abstract / minimal.
    var natureVsAbstract: Double
    /// 0 = mostly instrumental, 1 = more voice-forward content.
    var voiceVsInstrumental: Double
    /// Approximate age for era-biased snippet algorithm (peak years ~15–30 from birth year implied).
    var residentAgeYears: Int
    /// Cultural / national background — soft-biases discovery clip order and genre playlist tuning.
    var nationality: ResidentNationality
    /// Preferred genre for resident iPad playlists.
    var favouriteMusicGenre: ResidentMusicGenre
    /// Supervisor-seeded track titles that boost playlist ordering on the resident surface
    /// (combined with live sun-likes; does not replace discovery or skips).
    var suggestedLikedTrackTitles: [String] = []
    /// Bundled portrait in `Assets.xcassets`, assigned at seed time via
    /// `ResidentPortraitCatalog.assetName(displayName:)`; `nil` for a provisional resident mid-discovery.
    /// A captured photo (`CareDataStore.carePatientPortraitImages`) always wins.
    var stockPortraitAssetName: String?
    /// Temporary profile created during new-resident discovery — replaced when supervisor saves details.
    var isProvisional: Bool
    /// Curated playlists keyed by genre — shown when staff opens this profile (e.g. from face-linked photo).
    var genrePlaylistGroups: [CareGenrePlaylistGroup]
    var homeId: UUID = CareTenancyMockData.mapleLodgeId
    var wingId: String = CareTenancyMockData.wingResidential
    var roomLabel: String = ""
    var isActive: Bool = true
}

/// Saved playlist linked to a genre for resident calm sessions (POC stubs).
struct CarePlaylistEntry: Identifiable, Equatable {
    let id: UUID
    var title: String
    var trackCount: Int
    var durationMinutes: Int
    /// Song titles for the in-app playlist player (subset is fine for POC demos).
    var trackTitles: [String]
}

/// Playlists grouped under one genre on a patient’s profile.
struct CareGenrePlaylistGroup: Identifiable, Equatable {
    var id: ResidentMusicGenre { genre }
    var genre: ResidentMusicGenre
    var playlists: [CarePlaylistEntry]
}

struct CareSessionRecord: Identifiable, Equatable {
    let id: UUID
    let patientId: UUID
    let date: Date
    let moodSummary: String
    let calmPercent: Int
    var staffNote: String?
    /// 0–100: seemed more settled vs distressed after the moment (nil if not captured).
    var settledness: Int?
    /// 0–100: withdrawn vs engaged / connected.
    var engagement: Int?
    /// 0–100: struggled to tolerate vs comfortable throughout.
    var comfortTolerance: Int?
    /// Supervisor 1–10 ratings (nil if skipped).
    var moodRating: Int?
    var alertnessRating: Int?
    var emotionalStateRating: Int?
    var lucidityRating: Int?
    /// Resident calm-surface session length (seconds).
    var sessionDurationSeconds: Int?
    var residentGenrePlayCount: Int?
    var residentTrackChangeCount: Int?
    var residentImmersiveEntryCount: Int?
    var residentGenresPlayedSummary: String?
    /// Collated resident-surface interaction line (duration, taps, likes, skips, dwell, rage).
    var residentInteractionCollation: String? = nil
    var residentLikedTracksSummary: String? = nil
    var residentSkippedTracksSummary: String? = nil
    var residentTopDwellTracksSummary: String? = nil
    var residentRageBurstCount: Int? = nil
    /// Session context tags (time of day, prior state, environment).
    var sessionTimeOfDay: String? = nil
    var preSessionState: String? = nil
    var sessionContextSummary: String? = nil
    var residentLedSession: Bool? = nil
    var distressOrPRNNearby: Bool? = nil
    /// Generated at save time for handover / care-plan use.
    var insightNarrative: String? = nil
    var insightSuggestedNextStep: String? = nil
    var insightHandoverText: String? = nil
    var insightFamilyText: String? = nil
    var lightsDimmed: Bool? = nil
}

enum CareStaffMockData {
    static let elena = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-111111111101")!
    static let james = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-111111111102")!
    static let sam = UUID(uuidString: "aaaaaaaa-bbbb-4ccc-8ddd-111111111103")!

    static let initialPatients: [CarePatientProfile] = [
        CarePatientProfile(
            id: elena,
            displayName: "Elena M.",
            careContextLabel: "Room 12A · Residential",
            likes: ["Soft piano", "Rain at the window", "Short, unhurried blocks"],
            dislikes: ["Sudden tempo shifts", "Bright percussion", "Busy chatter nearby"],
            preferredLight: "Soft, indirect — avoid overhead glare.",
            scentGuidance: "Unscented room or a single mild linen spray if asked.",
            touchComfortNotes: "Comfortable with light hand rest; prefers warning before touch.",
            comfortThemes: ["Garden mornings", "Church bells from childhood", "Baking bread"],
            prefersGentleSoundOnsets: true,
            musicTempoBias: 0.35,
            natureVsAbstract: 0.22,
            voiceVsInstrumental: 0.4,
            residentAgeYears: 82,
            nationality: .italy,
            favouriteMusicGenre: .classical,
            suggestedLikedTrackTitles: ["Velvet Cadenza", "Pine Smoke Drift (1)"],
            stockPortraitAssetName: ResidentPortraitCatalog.assetName(displayName: "Elena M."),
            isProvisional: false,
            genrePlaylistGroups: [
                CareGenrePlaylistGroup(
                    genre: .classical,
                    playlists: [
                        CarePlaylistEntry(
                            id: UUID(uuidString: "cccc1111-1111-4111-8111-111111111101")!,
                            title: "Soft piano · morning",
                            trackCount: 1,
                            durationMinutes: 3,
                            trackTitles: ["Velvet Cadenza"]
                        ),
                    ]
                ),
                CareGenrePlaylistGroup(
                    genre: .gospel,
                    playlists: [
                        CarePlaylistEntry(
                            id: UUID(uuidString: "cccc1111-1111-4111-8111-111111111103")!,
                            title: "Hymns — gentle choir",
                            trackCount: 1,
                            durationMinutes: 2,
                            trackTitles: ["Pine Smoke Drift (1)"]
                        ),
                    ]
                ),
            ]
        ),
        CarePatientProfile(
            id: james,
            displayName: "James R.",
            careContextLabel: "Day programme · Quiet lounge",
            likes: ["Low strings", "Very slow builds", "Predictable loops"],
            dislikes: ["Crowded highs", "Fast rhythm guitar", "Screen glare"],
            preferredLight: "Dimmer side of room; natural daylight diffused.",
            scentGuidance: "No strong scents — can startle.",
            touchComfortNotes: "Prefers weighted blanket offered verbally first; minimal touch.",
            comfortThemes: ["Fishing trips", "Northern hills", "Jazz from the 50s"],
            prefersGentleSoundOnsets: true,
            musicTempoBias: 0.2,
            natureVsAbstract: 0.55,
            voiceVsInstrumental: 0.15,
            residentAgeYears: 76,
            nationality: .unitedKingdom,
            favouriteMusicGenre: .jazz,
            suggestedLikedTrackTitles: ["Velvet Afterhours", "Drift Between Rooms"],
            stockPortraitAssetName: ResidentPortraitCatalog.assetName(displayName: "James R."),
            isProvisional: false,
            genrePlaylistGroups: [
                CareGenrePlaylistGroup(
                    genre: .jazz,
                    playlists: [
                        CarePlaylistEntry(
                            id: UUID(uuidString: "cccc2222-2222-4222-8222-222222222201")!,
                            title: "50s lounge — brushed drums",
                            trackCount: 1,
                            durationMinutes: 4,
                            trackTitles: ["Velvet Afterhours"]
                        ),
                    ]
                ),
                CareGenrePlaylistGroup(
                    genre: .soul,
                    playlists: [
                        CarePlaylistEntry(
                            id: UUID(uuidString: "cccc2222-2222-4222-8222-222222222203")!,
                            title: "Warm vocals, soft band",
                            trackCount: 1,
                            durationMinutes: 3,
                            trackTitles: ["Drift Between Rooms"]
                        ),
                    ]
                ),
            ]
        ),
        CarePatientProfile(
            id: sam,
            displayName: "Sam K.",
            careContextLabel: "1:1 · Outreach",
            likes: ["Gentle spoken reassurance", "Ocean loops", "Birdsong far in the distance"],
            dislikes: ["Repetitive chime alarms", "Footsteps in echoey hall"],
            preferredLight: "Warm lamp; blinds half-closed in afternoon.",
            scentGuidance: "Optional: citrus peel on a plate — familiar, not sprayed.",
            touchComfortNotes: "Enjoys steady shoulder presence; say their name softly first.",
            comfortThemes: ["Seaside holidays", "Children’s laughter", "Sunday roast"],
            prefersGentleSoundOnsets: true,
            musicTempoBias: 0.5,
            natureVsAbstract: 0.3,
            voiceVsInstrumental: 0.65,
            residentAgeYears: 71,
            nationality: .jamaica,
            favouriteMusicGenre: .classical,
            suggestedLikedTrackTitles: ["Velvet Cadenza", "Echoes of Yesterday"],
            stockPortraitAssetName: ResidentPortraitCatalog.assetName(displayName: "Sam K."),
            isProvisional: false,
            genrePlaylistGroups: [
                CareGenrePlaylistGroup(
                    genre: .classical,
                    playlists: [
                        CarePlaylistEntry(
                            id: UUID(uuidString: "cccc3333-3333-4333-8333-333333333301")!,
                            title: "Ocean + piano blend",
                            trackCount: 1,
                            durationMinutes: 3,
                            trackTitles: ["Velvet Cadenza"]
                        ),
                    ]
                ),
                CareGenrePlaylistGroup(
                    genre: .pop,
                    playlists: [
                        CarePlaylistEntry(
                            id: UUID(uuidString: "cccc3333-3333-4333-8333-333333333302")!,
                            title: "Light nostalgia — soft hooks",
                            trackCount: 1,
                            durationMinutes: 4,
                            trackTitles: ["Echoes of Yesterday"]
                        ),
                    ]
                ),
            ]
        ),
    ]

    static let initialRecords: [CareSessionRecord] = [
        // Elena — clear upward arc (anxiety easing, calm and carer ratings improving)
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222201")!,
            patientId: elena,
            date: Date().addingTimeInterval(-86_400 * 1),
            moodSummary: "Calm, Settled",
            calmPercent: 88,
            staffNote: "Sustained eye contact; smiled during gospel track. Best session this fortnight.",
            settledness: 86,
            engagement: 78,
            comfortTolerance: 90,
            moodRating: 8,
            alertnessRating: 7,
            emotionalStateRating: 9,
            lucidityRating: 7,
            sessionDurationSeconds: 840,
            residentGenrePlayCount: 5,
            residentTrackChangeCount: 2,
            residentImmersiveEntryCount: 2,
            residentGenresPlayedSummary: "Classical ×2, Gospel ×3",
            sessionTimeOfDay: "Afternoon",
            preSessionState: "Mild restlessness",
            sessionContextSummary: "Afternoon · Before: mild restlessness · Lights dimmed · Resident-led",
            residentLedSession: true,
            distressOrPRNNearby: false,
            insightNarrative: "Elena M. spent 14m 0s · Classical ×2, Gospel ×3 · 2 therapeutic visual accesses during a reminiscence music session.",
            insightSuggestedNextStep: "Continue afternoon classical-to-gospel flow; wellbeing trending up — maintain this playlist shape.",
            insightHandoverText: nil,
            insightFamilyText: nil,
            lightsDimmed: true
        ),
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222202")!,
            patientId: elena,
            date: Date().addingTimeInterval(-86_400 * 6),
            moodSummary: "Quieter, Softer",
            calmPercent: 74,
            staffNote: "Less fidgeting than last week.",
            settledness: 70,
            engagement: 64,
            comfortTolerance: 78,
            moodRating: 7,
            alertnessRating: 6,
            emotionalStateRating: 7,
            lucidityRating: 6,
            sessionDurationSeconds: 660,
            residentGenrePlayCount: 3,
            residentTrackChangeCount: 1,
            residentImmersiveEntryCount: 1,
            residentGenresPlayedSummary: "Classical ×2, Gospel ×1",
            sessionTimeOfDay: "Afternoon",
            preSessionState: "Anxious / unsettled",
            sessionContextSummary: "Afternoon · Before: anxious / unsettled · Lights dimmed",
            residentLedSession: true,
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222205")!,
            patientId: elena,
            date: Date().addingTimeInterval(-86_400 * 12),
            moodSummary: "Anxious, Tired",
            calmPercent: 59,
            staffNote: "Short block; needed reassurance at start.",
            settledness: 54,
            engagement: 48,
            comfortTolerance: 62,
            moodRating: 5,
            alertnessRating: 5,
            emotionalStateRating: 5,
            lucidityRating: 6,
            sessionDurationSeconds: 480,
            sessionTimeOfDay: "Afternoon",
            preSessionState: "Withdrawn / low engagement",
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
        // James — overwhelm reducing, calm scores climbing
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222203")!,
            patientId: james,
            date: Date().addingTimeInterval(-86_400 * 0),
            moodSummary: "Calm, Content",
            calmPercent: 86,
            staffNote: "Stayed through full playlist; visible relaxation in shoulders.",
            settledness: 84,
            engagement: 72,
            comfortTolerance: 88,
            moodRating: 8,
            alertnessRating: 7,
            emotionalStateRating: 8,
            lucidityRating: 8,
            sessionDurationSeconds: 900,
            residentGenrePlayCount: 4,
            residentTrackChangeCount: 1,
            residentImmersiveEntryCount: 1,
            residentGenresPlayedSummary: "Jazz ×2, Classical ×2",
            sessionTimeOfDay: "Late morning",
            preSessionState: "Mild agitation",
            sessionContextSummary: "Late morning · Before: mild agitation · Lights dimmed",
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222206")!,
            patientId: james,
            date: Date().addingTimeInterval(-86_400 * 5),
            moodSummary: "Restless → Settling",
            calmPercent: 71,
            staffNote: "Dim lights helped; settled after first track.",
            settledness: 68,
            engagement: 58,
            comfortTolerance: 74,
            moodRating: 6,
            alertnessRating: 6,
            emotionalStateRating: 7,
            lucidityRating: 7,
            sessionDurationSeconds: 600,
            sessionTimeOfDay: "Late morning",
            preSessionState: "Overwhelmed / sensory overload",
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222204")!,
            patientId: james,
            date: Date().addingTimeInterval(-86_400 * 11),
            moodSummary: "Overwhelmed",
            calmPercent: 56,
            staffNote: "Needed slower intro; stopped early once.",
            settledness: 50,
            engagement: 42,
            comfortTolerance: 55,
            moodRating: 4,
            alertnessRating: 5,
            emotionalStateRating: 4,
            lucidityRating: 7,
            sessionDurationSeconds: 420,
            sessionTimeOfDay: "Late morning",
            preSessionState: "Heightened distress",
            distressOrPRNNearby: true,
            lightsDimmed: true
        ),
        // Sam — mood lifting, strong engagement on recent visits
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222207")!,
            patientId: sam,
            date: Date().addingTimeInterval(-86_400 * 2),
            moodSummary: "Peaceful, Engaged",
            calmPercent: 91,
            staffNote: "Hummed along; asked to keep listening — rare this month.",
            settledness: 90,
            engagement: 86,
            comfortTolerance: 92,
            moodRating: 9,
            alertnessRating: 7,
            emotionalStateRating: 9,
            lucidityRating: 8,
            sessionDurationSeconds: 960,
            residentGenrePlayCount: 6,
            residentTrackChangeCount: 2,
            residentImmersiveEntryCount: 2,
            residentGenresPlayedSummary: "Soul ×3, Gospel ×3",
            sessionTimeOfDay: "Early evening",
            preSessionState: "Low mood",
            sessionContextSummary: "Early evening · Before: low mood · Resident-led",
            residentLedSession: true,
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222208")!,
            patientId: sam,
            date: Date().addingTimeInterval(-86_400 * 7),
            moodSummary: "Calm",
            calmPercent: 78,
            staffNote: "Voice + ocean landed well; stayed for full length.",
            settledness: 76,
            engagement: 80,
            comfortTolerance: 86,
            moodRating: 7,
            alertnessRating: 6,
            emotionalStateRating: 8,
            lucidityRating: 7,
            sessionDurationSeconds: 720,
            residentGenresPlayedSummary: "Soul ×2, Gospel ×2",
            sessionTimeOfDay: "Early evening",
            preSessionState: "Withdrawn",
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
        CareSessionRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-4ccc-8ddd-222222222209")!,
            patientId: sam,
            date: Date().addingTimeInterval(-86_400 * 13),
            moodSummary: "Down, Stressed",
            calmPercent: 63,
            staffNote: "Took time to engage; shorter session.",
            settledness: 58,
            engagement: 52,
            comfortTolerance: 68,
            moodRating: 5,
            alertnessRating: 5,
            emotionalStateRating: 5,
            lucidityRating: 7,
            sessionDurationSeconds: 540,
            sessionTimeOfDay: "Early evening",
            preSessionState: "Low mood / tearful",
            distressOrPRNNearby: false,
            lightsDimmed: true
        ),
    ]
}
