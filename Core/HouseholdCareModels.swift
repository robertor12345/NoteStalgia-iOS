import UIKit

// MARK: - Care at home (household accounts)

/// Who the household carer is to the person they look after. Shown on their home screen and in
/// write-ups; it does not change what the app does.
enum HouseholdRelationship: String, Codable, CaseIterable, Identifiable {
    case familyMember
    case privateCarer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .familyMember: return "Family member"
        case .privateCarer: return "Private carer"
        }
    }
}

/// A family member or private household care worker who created their own account and registered
/// exactly one resident. Signs in with the same email + 6-digit PIN form as care-home staff.
///
/// The POC keeps these on the device (`HouseholdCareStore`); production auth replaces the store.
struct HouseholdCareAccount: Identifiable, Codable, Equatable {
    let id: UUID
    var email: String
    var displayName: String
    var relationship: HouseholdRelationship
    var pin: String
    /// Every household is modelled as a one-wing `CareHome`, so the roster engine, dashboards and
    /// session history work unchanged (`homeId` on the resident, `currentHomeId` in the flow).
    let homeId: UUID
    var residentId: UUID?
    let createdAt: Date
}

enum HouseholdCare {
    static let organisationId = UUID(uuidString: "50000000-0000-4000-8000-000000000001")!
    static let wingId = "at-home"
    static let wingName = "At home"
    static let homeName = "Care at home"

    /// Demo household — always available, never persisted (like the mock care-home accounts).
    static let demoAccountId = UUID(uuidString: "50000000-0000-4000-8000-000000000010")!
    static let demoHomeId = UUID(uuidString: "50000000-0000-4000-8000-000000000011")!
    static let demoResidentId = UUID(uuidString: "50000000-0000-4000-8000-000000000012")!
    static let demoEmail = "claire@example.com"
    static let demoPIN = "123456"

    static func home(for account: HouseholdCareAccount) -> CareHome {
        CareHome(
            id: account.homeId,
            organisationId: organisationId,
            name: homeName,
            wings: [CareHomeWing(id: wingId, name: wingName)]
        )
    }

    /// The household account in the shape the rest of the flow already understands.
    static func supervisorAccount(for account: HouseholdCareAccount) -> SupervisorAccount {
        SupervisorAccount(
            id: account.id,
            organisationId: organisationId,
            email: account.email,
            displayName: account.displayName,
            role: .household,
            homeIds: [account.homeId],
            pin: account.pin
        )
    }

    static func careContextLabel(for relationship: HouseholdRelationship) -> String {
        switch relationship {
        case .familyMember: return "Cared for at home · family"
        case .privateCarer: return "Cared for at home · private carer"
        }
    }

    /// A newly registered resident. Comfort notes start from the same gentle defaults as a
    /// discovery resident; the carer edits them on the profile. Playlists start from the
    /// nationality's first preferred genre and are reshaped by the listening discovery.
    static func makeResident(
        id: UUID = UUID(),
        name: String,
        age: Int,
        nationality: ResidentNationality,
        relationship: HouseholdRelationship,
        homeId: UUID
    ) -> CarePatientProfile {
        let genre = nationality.preferredGenres.first ?? .classical
        return CarePatientProfile(
            id: id,
            displayName: name,
            careContextLabel: careContextLabel(for: relationship),
            likes: [],
            dislikes: [],
            preferredLight: "Soft, indirect — avoid overhead glare.",
            scentGuidance: "Unscented room unless familiar and agreed.",
            touchComfortNotes: "Ask before touch; go slowly.",
            comfortThemes: [],
            prefersGentleSoundOnsets: true,
            musicTempoBias: 0.35,
            natureVsAbstract: 0.3,
            voiceVsInstrumental: 0.4,
            residentAgeYears: age,
            nationality: nationality,
            favouriteMusicGenre: genre,
            suggestedLikedTrackTitles: [],
            stockPortraitAssetName: ResidentPortraitCatalog.assetName(displayName: name),
            isProvisional: false,
            genrePlaylistGroups: [DiscoveryPlaylistTuning.stubGenreGroup(for: genre)],
            homeId: homeId,
            wingId: wingId,
            roomLabel: "",
            isActive: true
        )
    }
}

// MARK: - Store (on-device POC persistence)

/// Household accounts, their resident and session history live on this device so an account
/// created today is still there tomorrow. Accounts sit in `UserDefaults`; the resident, history and
/// portrait go to Application Support as JSON / JPEG. Production replaces all of this with the
/// backend in `docs/IMPLEMENTATION_PLAN.md`.
enum HouseholdCareStore {
    private static let accountsKey = "poc.household.accounts"
    private static let dataFileName = "household-care.json"

    struct Data: Codable {
        var residents: [CarePatientProfile] = []
        var records: [CareSessionRecord] = []
        /// Activities logged outside the app (`ActivityLogDraft`), including corrections and removals. Optional so a file
        /// written before they existed still decodes — a missing key must never cost a household its history.
        var activities: [GroupSessionRecord]? = nil
    }

    // MARK: Accounts

    /// Demo account first, then everything created on this device.
    static func allAccounts() -> [HouseholdCareAccount] {
        [demoAccount] + storedAccounts
    }

    static func account(id: UUID) -> HouseholdCareAccount? {
        allAccounts().first { $0.id == id }
    }

    static func account(email: String) -> HouseholdCareAccount? {
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        return allAccounts().first { $0.email.lowercased() == needle }
    }

    static func isHouseholdHome(_ homeId: UUID) -> Bool {
        allAccounts().contains { $0.homeId == homeId }
    }

    static func add(_ account: HouseholdCareAccount) {
        var accounts = storedAccounts
        accounts.removeAll { $0.id == account.id }
        accounts.append(account)
        storedAccounts = accounts
    }

    static func update(_ account: HouseholdCareAccount) {
        guard account.id != demoAccountId else { return }
        add(account)
    }

    static func setPIN(_ pin: String, for accountId: UUID) {
        guard var account = account(id: accountId) else { return }
        account.pin = pin
        update(account)
    }

    private static var storedAccounts: [HouseholdCareAccount] {
        get {
            guard let data = UserDefaults.standard.data(forKey: accountsKey) else { return [] }
            return (try? JSONDecoder().decode([HouseholdCareAccount].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: accountsKey)
            }
        }
    }

    /// Demo recordings only (`DemoLaunchOptions.resetHouseholds`): forget every account created on
    /// this device together with its resident, history and portraits. The demo household is static.
    static func wipeStored() {
        let ids = loadData().residents.map(\.id)
        UserDefaults.standard.removeObject(forKey: accountsKey)
        if let url = dataURL { try? FileManager.default.removeItem(at: url) }
        if let dir = supportDirectory {
            for id in ids {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("portrait-\(id.uuidString).jpg"))
            }
        }
    }

    // MARK: Resident + history

    static func loadData() -> Data {
        guard let url = dataURL, let raw = try? Foundation.Data(contentsOf: url) else { return Data() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Data.self, from: raw)) ?? Data()
    }

    static func persist(_ data: Data) {
        guard let url = dataURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let raw = try? encoder.encode(data) else { return }
        try? raw.write(to: url, options: .atomic)
    }

    static func savePortrait(_ image: UIImage, for residentId: UUID) {
        guard let dir = supportDirectory, let data = image.jpegData(compressionQuality: 0.86) else { return }
        try? data.write(to: dir.appendingPathComponent("portrait-\(residentId.uuidString).jpg"), options: .atomic)
    }

    static func loadPortraits(for residentIds: [UUID]) -> [UUID: UIImage] {
        guard let dir = supportDirectory else { return [:] }
        var out: [UUID: UIImage] = [:]
        for id in residentIds {
            let url = dir.appendingPathComponent("portrait-\(id.uuidString).jpg")
            if let data = try? Foundation.Data(contentsOf: url), let image = UIImage(data: data) {
                out[id] = image
            }
        }
        return out
    }

    private static var dataURL: URL? {
        supportDirectory?.appendingPathComponent(dataFileName)
    }

    private static var supportDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = base.appendingPathComponent("NoteStalgia", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Everything the launch seed appends to the mock roster: the demo household plus the
    /// accounts, residents, history and portraits stored on this device.
    static func seedContent(now: Date = Date()) -> (residents: [CarePatientProfile], records: [CareSessionRecord], activities: [GroupSessionRecord], portraits: [UUID: UIImage]) {
        let stored = loadData()
        let residents = [demoResident] + stored.residents
        let records = demoRecords(now: now) + stored.records
        let activities = demoActivities(now: now) + (stored.activities ?? [])
        return (residents, records, activities, loadPortraits(for: stored.residents.map(\.id)))
    }

    /// Two things Claire logged for Harold, so the Care at home insights have an "outside the app" card from the first launch.
    static func demoActivities(now: Date = Date()) -> [GroupSessionRecord] {
        let plan: [(Int, OtherActivityKind, GroupParticipantState, String?)] = [
            (6, .petVisit, .enjoyed, "Biscuit the spaniel came round. He talked to her the whole time."),
            (2, .gardening, .engaged, nil),
        ]
        return plan.enumerated().compactMap { index, p in
            var draft = ActivityLogDraft(now: now.addingTimeInterval(-Double(p.0) * 86_400 - 3_600 * 5))
            draft.kind = p.1
            draft.solo = true
            draft.durationMinutes = 45
            draft.attendeeIds = [HouseholdCare.demoResidentId]
            draft.responses[HouseholdCare.demoResidentId] = p.2
            draft.note = p.3 ?? ""
            return GroupSessionRecord(
                loggedActivity: draft,
                id: UUID(uuidString: String(format: "62000000-0000-4000-8000-%012x", 0xc1 + index))!,
                homeId: HouseholdCare.demoHomeId,
                authorAccountId: HouseholdCare.demoAccountId
            )
        }
    }

    // MARK: Demo household

    static let demoAccountId = HouseholdCare.demoAccountId

    static let demoAccount = HouseholdCareAccount(
        id: HouseholdCare.demoAccountId,
        email: HouseholdCare.demoEmail,
        displayName: "Claire",
        relationship: .familyMember,
        pin: HouseholdCare.demoPIN,
        homeId: HouseholdCare.demoHomeId,
        residentId: HouseholdCare.demoResidentId,
        createdAt: Date(timeIntervalSince1970: 1_790_000_000)
    )

    /// Claire's father Harold: a full profile (from the shared seed table) plus a fortnight of
    /// sessions with a gently rising trend, so the household insights have something to show.
    static let demoResident: CarePatientProfile = {
        let seed = ResidentProfileSeeds.seed(forFirstName: "Harold")
        let name = "Harold T."
        return CarePatientProfile(
            id: HouseholdCare.demoResidentId,
            displayName: name,
            careContextLabel: HouseholdCare.careContextLabel(for: .familyMember),
            likes: seed.likes,
            dislikes: seed.dislikes,
            preferredLight: seed.light,
            scentGuidance: seed.scent,
            touchComfortNotes: seed.touch,
            comfortThemes: seed.themes,
            prefersGentleSoundOnsets: seed.gentleOnsets,
            musicTempoBias: seed.tempo,
            natureVsAbstract: seed.nature,
            voiceVsInstrumental: seed.voice,
            residentAgeYears: 86,
            nationality: .unitedKingdom,
            favouriteMusicGenre: seed.favourite,
            suggestedLikedTrackTitles: ResidentProfileSeeds.suggestedTitles(for: seed),
            stockPortraitAssetName: ResidentPortraitCatalog.assetName(displayName: name),
            isProvisional: false,
            genrePlaylistGroups: ResidentProfileSeeds.playlistGroups(for: seed, residentIndex: 200),
            homeId: HouseholdCare.demoHomeId,
            wingId: HouseholdCare.wingId,
            roomLabel: "",
            isActive: true
        )
    }()

    static func demoRecords(now: Date = Date()) -> [CareSessionRecord] {
        let favourite = demoResident.favouriteMusicGenre
        let second = demoResident.genrePlaylistGroups.dropFirst().first?.genre ?? .jazz
        let favTitle = ResidentPlaybackTrackCatalog.titles(for: favourite).first ?? favourite.rawValue.capitalized
        let secondTitle = ResidentPlaybackTrackCatalog.titles(for: second).first ?? second.rawValue.capitalized
        // (days ago, calm %, mood, alertness, emotional, orientation, seconds, mood summary, time of day)
        let plan: [(Int, Int, Int, Int, Int, Int, Int, String, String)] = [
            (13, 54, 5, 5, 5, 4, 420, "Restless, Tired", "Afternoon"),
            (11, 61, 6, 5, 6, 5, 540, "Quieter, Softer", "Morning"),
            (9, 66, 6, 6, 7, 5, 600, "Settled, Content", "Afternoon"),
            (7, 70, 7, 6, 7, 6, 660, "Settled, Content", "Evening"),
            (5, 73, 7, 7, 8, 6, 720, "Calm, Engaged", "Morning"),
            (3, 78, 8, 7, 8, 7, 840, "Calm, Engaged", "Afternoon"),
            (1, 81, 8, 8, 9, 7, 900, "Calm, Engaged", "Afternoon"),
        ]
        return plan.enumerated().map { index, p in
            let (daysAgo, calm, mood, alert, emotional, orientation, seconds, summary, timeOfDay) = p
            let favPlays = 1 + index / 2
            let secondPlays = index % 2 == 0 ? 1 : 2
            let genres = "\(favourite.rawValue.capitalized) ×\(favPlays), \(second.rawValue.capitalized) ×\(secondPlays)"
            let minutes = seconds / 60
            return CareSessionRecord(
                id: UUID(uuidString: String(format: "50000000-0000-4000-8000-0000000001%02x", index))!,
                patientId: HouseholdCare.demoResidentId,
                date: now.addingTimeInterval(-Double(daysAgo) * 86_400 - 3_600 * Double(10 + index)),
                moodSummary: summary,
                calmPercent: calm,
                staffNote: index == 6 ? "Hummed along and asked for the piano piece again." : nil,
                settledness: calm,
                engagement: min(100, calm + 6),
                comfortTolerance: min(100, calm + 10),
                moodRating: mood,
                alertnessRating: alert,
                emotionalStateRating: emotional,
                lucidityRating: orientation,
                sessionDurationSeconds: seconds,
                residentGenrePlayCount: favPlays + secondPlays,
                residentTrackChangeCount: secondPlays,
                residentImmersiveEntryCount: 1,
                residentGenresPlayedSummary: genres,
                residentLikedTracksSummary: index >= 2 ? "\(favTitle) ×\(1 + index / 3)" : nil,
                residentSkippedTracksSummary: index == 1 ? "\(secondTitle) ×1" : nil,
                sessionTimeOfDay: timeOfDay,
                preSessionState: index < 2 ? "Mild restlessness" : "Settled at baseline",
                sessionContextSummary: "\(timeOfDay) · Before: \(index < 2 ? "mild restlessness" : "settled at baseline") · Lights dimmed",
                residentLedSession: index >= 3,
                distressOrPRNNearby: false,
                insightNarrative: "Harold T. spent \(minutes)m with \(genres.lowercased()) during a reminiscence music session at home.",
                insightSuggestedNextStep: index >= 4
                    ? "Keep the afternoon \(favourite.rawValue) start — wellbeing is trending up; try adding a second \(second.rawValue) track before tea."
                    : "Offer the \(favourite.rawValue) playlist again at the same time tomorrow and note how he settles.",
                insightHandoverText: nil,
                insightFamilyText: nil,
                lightsDimmed: true
            )
        }
    }
}

// MARK: - Directory (mock care-home tenancy + household accounts)

/// One lookup for every account and home the flow can be signed into: the mock organisation's
/// supervisors and homes plus the household accounts on this device.
enum CareAccountDirectory {
    static func account(id: UUID) -> SupervisorAccount? {
        if APIConfig.isConfigured, let principal = PrincipalCache.principal(accountId: id) { return principal.supervisorAccount }
        if let mock = CareTenancyMockData.supervisor(id: id) { return mock }
        return HouseholdCareStore.account(id: id).map(HouseholdCare.supervisorAccount(for:))
    }

    static func account(email: String) -> SupervisorAccount? {
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let mock = CareTenancyMockData.supervisors.first(where: { $0.email.lowercased() == needle }) {
            return SupervisorCredentialStore.accountWithEffectivePIN(mock)
        }
        return HouseholdCareStore.account(email: needle).map(HouseholdCare.supervisorAccount(for:))
    }

    static func home(id: UUID) -> CareHome? {
        if APIConfig.isConfigured, let remote = PrincipalCache.home(id: id) { return remote }
        if let mock = CareTenancyMockData.home(id: id) { return mock }
        return HouseholdCareStore.allAccounts().first { $0.homeId == id }.map(HouseholdCare.home(for:))
    }

    static func isHousehold(accountId: UUID) -> Bool {
        if APIConfig.isConfigured, let principal = PrincipalCache.principal(accountId: accountId) { return principal.isHousehold }
        return HouseholdCareStore.account(id: accountId) != nil
    }
}
