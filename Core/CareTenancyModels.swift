import Foundation

// MARK: - Organisation → home → supervisor → resident (POC tenancy)

struct CareOrganisation: Identifiable, Equatable {
    let id: UUID
    var name: String
    var emailDomains: [String]
}

struct CareHomeWing: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
}

struct CareHome: Identifiable, Equatable {
    let id: UUID
    let organisationId: UUID
    var name: String
    var wings: [CareHomeWing]
}

enum SupervisorRole: String, Equatable {
    case supervisor
    case homeLead
    case orgAdmin
}

struct SupervisorAccount: Identifiable, Equatable {
    let id: UUID
    let organisationId: UUID
    var email: String
    var displayName: String
    var role: SupervisorRole
    var homeIds: [UUID]
    var pin: String
}

extension SupervisorRole {
    var isHomeAdmin: Bool {
        self == .homeLead || self == .orgAdmin
    }
}

enum CareRosterDisplayMode: String, CaseIterable, Identifiable {
    case cards
    case compact

    var id: String { rawValue }
    var label: String { self == .cards ? "Cards" : "Compact" }
}

struct CareRosterSection: Identifiable, Equatable {
    enum Kind: Equatable {
        case pinned, recent, due, wing(String), searchResults, allResidents
    }

    let id: String
    var kind: Kind
    var title: String
    var subtitle: String?
    var patientIds: [UUID]
}

struct CareRosterPresentation: Equatable {
    var homeName: String
    var totalActiveResidents: Int
    var sections: [CareRosterSection]
    var isSearching: Bool
    var isBrowsingAll: Bool
}

enum CareRosterEngine {
    static let recentSessionWindowDays = 14
    static let dueSessionThresholdDays = 7
    static let todaySectionLimit = 20
    static let searchResultsLimit = 40

    static func activeResidents(in homeId: UUID, from all: [CarePatientProfile]) -> [CarePatientProfile] {
        all.filter { $0.homeId == homeId && !$0.isProvisional && $0.isActive }
    }

    static func wingName(home: CareHome, wingId: String) -> String {
        home.wings.first { $0.id == wingId }?.name ?? wingId
    }

    static func lastSessionDate(for patientId: UUID, records: [CareSessionRecord]) -> Date? {
        records.filter { $0.patientId == patientId }.map(\.date).max()
    }

    static func daysSinceLastSession(for patientId: UUID, records: [CareSessionRecord], now: Date = Date()) -> Int? {
        guard let last = lastSessionDate(for: patientId, records: records) else { return nil }
        return max(0, Int(now.timeIntervalSince(last) / 86_400))
    }

    static func isDue(for patientId: UUID, records: [CareSessionRecord], now: Date = Date()) -> Bool {
        guard let days = daysSinceLastSession(for: patientId, records: records, now: now) else { return true }
        return days >= dueSessionThresholdDays
    }

    static func isRecent(for patientId: UUID, records: [CareSessionRecord], now: Date = Date()) -> Bool {
        guard let days = daysSinceLastSession(for: patientId, records: records, now: now) else { return false }
        return days <= recentSessionWindowDays
    }

    static func matchesSearch(_ patient: CarePatientProfile, query: String, home: CareHome) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        let wing = wingName(home: home, wingId: patient.wingId).lowercased()
        let haystack = [patient.displayName, patient.roomLabel, patient.careContextLabel, wing]
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(q)
    }

    static func buildPresentation(
        home: CareHome,
        allResidents: [CarePatientProfile],
        records: [CareSessionRecord],
        pinnedIds: Set<UUID>,
        recentlyViewedIds: [UUID],
        preferredWingId: String?,
        searchQuery: String,
        browsingAll: Bool,
        now: Date = Date()
    ) -> CareRosterPresentation {
        let homeResidents = activeResidents(in: home.id, from: allResidents)
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedQuery.isEmpty {
            let matches = homeResidents
                .filter { matchesSearch($0, query: trimmedQuery, home: home) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .prefix(searchResultsLimit)
                .map(\.id)
            return CareRosterPresentation(
                homeName: home.name,
                totalActiveResidents: homeResidents.count,
                sections: [
                    CareRosterSection(
                        id: "search",
                        kind: .searchResults,
                        title: "Search results",
                        subtitle: "\(matches.count) match\(matches.count == 1 ? "" : "es")",
                        patientIds: Array(matches)
                    ),
                ],
                isSearching: true,
                isBrowsingAll: false
            )
        }

        if browsingAll {
            let allIds = homeResidents
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .map(\.id)
            return CareRosterPresentation(
                homeName: home.name,
                totalActiveResidents: homeResidents.count,
                sections: [
                    CareRosterSection(
                        id: "all",
                        kind: .allResidents,
                        title: "All residents",
                        subtitle: "A–Z",
                        patientIds: allIds
                    ),
                ],
                isSearching: false,
                isBrowsingAll: true
            )
        }

        var sections: [CareRosterSection] = []
        var used = Set<UUID>()

        func appendSection(_ section: CareRosterSection) {
            let fresh = section.patientIds.filter { !used.contains($0) }
            guard !fresh.isEmpty else { return }
            used.formUnion(fresh)
            sections.append(CareRosterSection(
                id: section.id,
                kind: section.kind,
                title: section.title,
                subtitle: section.subtitle,
                patientIds: fresh
            ))
        }

        var pinnedOrdered: [UUID] = []
        var seenPin = Set<UUID>()
        for id in recentlyViewedIds where pinnedIds.contains(id) {
            if seenPin.insert(id).inserted { pinnedOrdered.append(id) }
        }
        for resident in homeResidents where pinnedIds.contains(resident.id) && !seenPin.contains(resident.id) {
            pinnedOrdered.append(resident.id)
            seenPin.insert(resident.id)
        }
        appendSection(CareRosterSection(
            id: "pinned",
            kind: .pinned,
            title: "Pinned",
            subtitle: "Your regular residents",
            patientIds: Array(pinnedOrdered.prefix(todaySectionLimit))
        ))

        let recentIds = homeResidents
            .filter { isRecent(for: $0.id, records: records, now: now) }
            .sorted {
                (lastSessionDate(for: $0.id, records: records) ?? .distantPast) >
                (lastSessionDate(for: $1.id, records: records) ?? .distantPast)
            }
            .prefix(todaySectionLimit)
            .map(\.id)
        appendSection(CareRosterSection(
            id: "recent",
            kind: .recent,
            title: "Recent",
            subtitle: "Sessions in the last \(recentSessionWindowDays) days",
            patientIds: Array(recentIds)
        ))

        let dueIds = homeResidents
            .filter { isDue(for: $0.id, records: records, now: now) }
            .sorted {
                (daysSinceLastSession(for: $0.id, records: records, now: now) ?? 999) >
                (daysSinceLastSession(for: $1.id, records: records, now: now) ?? 999)
            }
            .prefix(todaySectionLimit)
            .map(\.id)
        appendSection(CareRosterSection(
            id: "due",
            kind: .due,
            title: "Due for a visit",
            subtitle: "No session in \(dueSessionThresholdDays)+ days",
            patientIds: Array(dueIds)
        ))

        if let wingId = preferredWingId, home.wings.contains(where: { $0.id == wingId }) {
            let wingIds = homeResidents
                .filter { $0.wingId == wingId }
                .sorted { $0.roomLabel.localizedCaseInsensitiveCompare($1.roomLabel) == .orderedAscending }
                .prefix(todaySectionLimit)
                .map(\.id)
            appendSection(CareRosterSection(
                id: "wing-\(wingId)",
                kind: .wing(wingId),
                title: wingName(home: home, wingId: wingId),
                subtitle: "On this wing today",
                patientIds: Array(wingIds)
            ))
        }

        let previewCount = sections.reduce(0) { $0 + $1.patientIds.count }
        if previewCount < min(8, homeResidents.count) {
            let filler = homeResidents
                .filter { !used.contains($0.id) }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .prefix(max(0, todaySectionLimit - previewCount))
                .map(\.id)
            appendSection(CareRosterSection(
                id: "more-today",
                kind: .allResidents,
                title: "More at this home",
                subtitle: nil,
                patientIds: Array(filler)
            ))
        }

        return CareRosterPresentation(
            homeName: home.name,
            totalActiveResidents: homeResidents.count,
            sections: sections,
            isSearching: false,
            isBrowsingAll: false
        )
    }
}

enum CareTenancyMockData {
    static let sunriseCareId = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    static let mapleLodgeId = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
    static let riversideHouseId = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!

    static let wingMemoryCare = "memory-care"
    static let wingResidential = "residential"
    static let wingDayProgram = "day-program"

    static let supervisorMaxId = UUID(uuidString: "30000000-0000-4000-8000-000000000001")!
    static let supervisorAlexId = UUID(uuidString: "30000000-0000-4000-8000-000000000002")!

    static let organisation = CareOrganisation(
        id: sunriseCareId,
        name: "Sunrise Care Group",
        emailDomains: ["sunrise-care.co.uk"]
    )

    static let mapleLodge = CareHome(
        id: mapleLodgeId,
        organisationId: sunriseCareId,
        name: "Maple Lodge",
        wings: [
            CareHomeWing(id: wingMemoryCare, name: "Memory care"),
            CareHomeWing(id: wingResidential, name: "Residential"),
            CareHomeWing(id: wingDayProgram, name: "Day programme"),
        ]
    )

    static let riversideHouse = CareHome(
        id: riversideHouseId,
        organisationId: sunriseCareId,
        name: "Riverside House",
        wings: [
            CareHomeWing(id: wingResidential, name: "Residential"),
            CareHomeWing(id: wingMemoryCare, name: "Memory care"),
        ]
    )

    static let homes: [CareHome] = [mapleLodge, riversideHouse]

    static let supervisors: [SupervisorAccount] = [
        SupervisorAccount(
            id: supervisorMaxId,
            organisationId: sunriseCareId,
            email: "max@sunrise-care.co.uk",
            displayName: "Max",
            role: .supervisor,
            homeIds: [mapleLodgeId],
            pin: "123456"
        ),
        SupervisorAccount(
            id: supervisorAlexId,
            organisationId: sunriseCareId,
            email: "alex@sunrise-care.co.uk",
            displayName: "Alex",
            role: .homeLead,
            homeIds: [mapleLodgeId, riversideHouseId],
            pin: "123456"
        ),
    ]

    static func home(id: UUID) -> CareHome? { homes.first { $0.id == id } }
    static func supervisor(id: UUID) -> SupervisorAccount? {
        guard let account = supervisors.first(where: { $0.id == id }) else { return nil }
        return SupervisorCredentialStore.accountWithEffectivePIN(account)
    }

    /// Deterministic roster — 37 profiles built with per-resident string formatting. Identical on
    /// every launch, so compute exactly once and reuse. `insightsDemoRecords()` also reads this,
    /// so caching here removes that nested re-generation too.
    static let allPatientsSnapshot: [CarePatientProfile] =
        namedMapleLodgeResidents() + generatedMapleLodgeResidents() + riversideSeedResidents()

    static func allPatients() -> [CarePatientProfile] { allPatientsSnapshot }

    /// Demo session history (~90 records). Cached once — see `allPatientsSnapshot`.
    static let supplementalRecordsSnapshot: [CareSessionRecord] = insightsDemoRecords()

    static func supplementalRecords() -> [CareSessionRecord] { supplementalRecordsSnapshot }

    /// Rich 14-day demo history — upward calm / wellbeing trends for admin insights.
    static func insightsDemoRecords(now: Date = Date()) -> [CareSessionRecord] {
        let heroIds: Set<UUID> = [
            CareStaffMockData.elena,
            CareStaffMockData.james,
            CareStaffMockData.sam,
        ]
        let patients = allPatients().filter { !heroIds.contains($0.id) }

        let moodByProgress: [(threshold: Double, label: String)] = [
            (0.0, "Anxious, Tired"),
            (0.25, "Restless"),
            (0.45, "Quieter"),
            (0.65, "Calm"),
            (0.82, "Settled"),
            (0.92, "Peaceful, Engaged"),
        ]

        // Bias toward recent days so home-wide session volume and reach climb over the fortnight.
        let daySlots: [Int] = [
            13, 12, 12, 11, 11, 10, 10, 9, 8, 8, 7, 7, 6, 6, 5, 5, 4, 4, 3, 3,
            2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0,
        ]

        var records: [CareSessionRecord] = []
        var slotIndex = 0

        for (patientIndex, patient) in patients.enumerated() {
            let sessionCount = 2 + (patientIndex % 3)
            for sessionIndex in 0 ..< sessionCount {
                let daysAgo: Int
                if sessionIndex == sessionCount - 1 {
                    daysAgo = [0, 1, 2, 3][patientIndex % 4]
                } else {
                    daysAgo = daySlots[slotIndex % daySlots.count]
                    slotIndex += 1 + (patientIndex % 2)
                }

                let recency = 1.0 - (Double(daysAgo) / 13.0)
                let sessionArc = sessionCount > 1
                    ? Double(sessionIndex) / Double(sessionCount - 1)
                    : 1.0
                let progress = min(1.0, recency * 0.55 + sessionArc * 0.45)
                let variance = Double((patientIndex + sessionIndex) % 5)

                let calmPercent = min(93, max(58, Int(56 + progress * 30 + variance)))
                let moodRating = min(9, max(5, Int(5 + progress * 3.8)))
                let alertness = min(9, max(5, Int(5 + progress * 3.2)))
                let emotional = min(9, max(5, Int(5 + progress * 3.6)))
                let lucidity = min(9, max(5, Int(6 + progress * 2.8)))
                let settledness = min(92, max(52, Int(52 + progress * 36 + variance)))
                let engagement = min(90, max(48, Int(48 + progress * 38 + variance * 0.6)))
                let comfort = min(94, max(58, Int(58 + progress * 32)))

                let moodSummary = moodByProgress.last { progress >= $0.threshold }?.label ?? "Calm"

                let staffNote: String? = progress >= 0.75
                    ? positiveStaffNote(for: patient.displayName, index: patientIndex + sessionIndex)
                    : (progress < 0.35 ? "Building rapport — shorter visit; will repeat gentle intro." : nil)

                records.append(
                    CareSessionRecord(
                        id: UUID(uuidString: String(format: "60000000-0000-4000-8000-%012x", records.count + 1))!,
                        patientId: patient.id,
                        date: now.addingTimeInterval(-Double(daysAgo) * 86_400 - Double(sessionIndex) * 3_600),
                        moodSummary: moodSummary,
                        calmPercent: calmPercent,
                        staffNote: staffNote,
                        settledness: settledness,
                        engagement: engagement,
                        comfortTolerance: comfort,
                        moodRating: moodRating,
                        alertnessRating: alertness,
                        emotionalStateRating: emotional,
                        lucidityRating: lucidity,
                        sessionDurationSeconds: Int(480 + progress * 420),
                        residentGenrePlayCount: 2 + Int(progress * 4),
                        residentTrackChangeCount: sessionIndex == 0 ? 1 : 2,
                        residentImmersiveEntryCount: progress >= 0.6 ? 1 : 0,
                        sessionTimeOfDay: sessionIndex.isMultiple(of: 2) ? "Afternoon" : "Late morning",
                        preSessionState: progress < 0.4 ? "Withdrawn / low engagement" : "Mild restlessness",
                        sessionContextSummary: "Lights dimmed · Resident-led",
                        residentLedSession: true,
                        distressOrPRNNearby: false,
                        lightsDimmed: true
                    )
                )
            }
        }

        return records
    }

    private static func positiveStaffNote(for name: String, index: Int) -> String {
        let notes = [
            "\(name) more settled than prior visit — calm score trending up.",
            "Visible relaxation by second track; carer ratings improved vs last session.",
            "Engaged with music longer; wellbeing markers strongest this fortnight.",
            "Family noted brighter affect after session — maintain this playlist.",
            "PRN not required; agitation eased within first five minutes.",
            "Sustained eye contact and softer breathing — session impact positive.",
        ]
        return notes[index % notes.count]
    }

    private static func namedMapleLodgeResidents() -> [CarePatientProfile] {
        let named = CareStaffMockData.initialPatients
        let wings = [wingResidential, wingDayProgram, wingMemoryCare]
        let rooms = ["Room 12A", "Quiet lounge", "Room 3C"]
        return named.enumerated().map { index, patient in
            var copy = patient
            let wing = wings[index]
            let room = rooms[index]
            let wingLabel = mapleLodge.wings.first { $0.id == wing }?.name ?? wing
            copy.homeId = mapleLodgeId
            copy.wingId = wing
            copy.roomLabel = room
            copy.isActive = true
            copy.careContextLabel = "\(room) · \(wingLabel)"
            return copy
        }
    }

    private static func generatedMapleLodgeResidents() -> [CarePatientProfile] {
        let firstNames = [
            "Margaret", "Arthur", "Dorothy", "Harold", "Betty", "George", "Jean", "Ronald",
            "Patricia", "Frank", "Irene", "Albert", "Gladys", "Stanley", "Rose", "Norman",
            "Audrey", "Cyril", "Muriel", "Keith", "Joan", "Raymond", "Ethel", "Leslie",
            "Phyllis", "Bernard", "Winifred", "Gordon",
        ]
        let portraits = ["StockPortraitElena", "StockPortraitJames", "StockPortraitSam"]
        let genres: [ResidentMusicGenre] = [.classical, .jazz, .pop, .gospel, .soul, .country]
        let wings = [wingMemoryCare, wingResidential, wingDayProgram]
        let templates = CareStaffMockData.initialPatients

        return firstNames.enumerated().map { index, first in
            let lastInitial = Character(UnicodeScalar(65 + (index % 26))!)
            let wing = wings[index % wings.count]
            let wingLabel = mapleLodge.wings.first { $0.id == wing }?.name ?? wing
            let room = wing == wingDayProgram ? "Day lounge \(index + 1)" : "Room \(100 + index)"
            let genre = genres[index % genres.count]
            let template = templates[index % templates.count]
            return CarePatientProfile(
                id: UUID(uuidString: String(format: "40000000-0000-4000-8000-%012x", index + 10))!,
                displayName: "\(first) \(lastInitial).",
                careContextLabel: "\(room) · \(wingLabel)",
                likes: template.likes,
                dislikes: template.dislikes,
                preferredLight: template.preferredLight,
                scentGuidance: template.scentGuidance,
                touchComfortNotes: template.touchComfortNotes,
                comfortThemes: template.comfortThemes,
                prefersGentleSoundOnsets: true,
                musicTempoBias: template.musicTempoBias,
                natureVsAbstract: template.natureVsAbstract,
                voiceVsInstrumental: template.voiceVsInstrumental,
                residentAgeYears: 72 + (index % 18),
                favouriteMusicGenre: genre,
                stockPortraitAssetName: portraits[index % portraits.count],
                isProvisional: false,
                genrePlaylistGroups: template.genrePlaylistGroups,
                homeId: mapleLodgeId,
                wingId: wing,
                roomLabel: room,
                isActive: true
            )
        }
    }

    private static func riversideSeedResidents() -> [CarePatientProfile] {
        let names = ["Helen T.", "Peter W.", "Grace L.", "David N.", "Mary S.", "John H."]
        let template = CareStaffMockData.initialPatients[0]
        return names.enumerated().map { index, name in
            let wing = index.isMultiple(of: 2) ? wingResidential : wingMemoryCare
            let wingLabel = riversideHouse.wings.first { $0.id == wing }?.name ?? wing
            let room = "Room \(20 + index)"
            return CarePatientProfile(
                id: UUID(uuidString: String(format: "50000000-0000-4000-8000-%012x", index + 1))!,
                displayName: name,
                careContextLabel: "\(room) · \(wingLabel)",
                likes: template.likes,
                dislikes: template.dislikes,
                preferredLight: template.preferredLight,
                scentGuidance: template.scentGuidance,
                touchComfortNotes: template.touchComfortNotes,
                comfortThemes: template.comfortThemes,
                prefersGentleSoundOnsets: true,
                musicTempoBias: template.musicTempoBias,
                natureVsAbstract: template.natureVsAbstract,
                voiceVsInstrumental: template.voiceVsInstrumental,
                residentAgeYears: 78 + index,
                favouriteMusicGenre: .classical,
                stockPortraitAssetName: "StockPortraitElena",
                isProvisional: false,
                genrePlaylistGroups: template.genrePlaylistGroups,
                homeId: riversideHouseId,
                wingId: wing,
                roomLabel: room,
                isActive: true
            )
        }
    }
}
