import Foundation

// MARK: - Group activities — intelligent resident selection (POC heuristics)
//
// Staff choose who joins a group activity; the app suggests. Everything here is a pure function of
// the roster, the one-to-one session history and the group-session history, so it runs on demand
// and can be replayed in tests. Production ports these rules to the Recommendations context as the
// Phase-A heuristic model (docs/IMPLEMENTATION_PLAN.md §10); the inputs and outputs are the contract.

/// How a resident tends to do in company — set by staff on the profile (seeded for the mock roster).
/// Unknown is treated as "enjoys groups" for matching, but never produces a "prefers one-to-one" nudge.
enum GroupComfort: String, Codable, CaseIterable, Identifiable {
    case enjoysGroups
    case smallGroupsOnly
    case prefersOneToOne

    var id: String { rawValue }

    var label: String {
        switch self {
        case .enjoysGroups: return "Enjoys groups"
        case .smallGroupsOnly: return "Small groups"
        case .prefersOneToOne: return "Prefers one-to-one"
        }
    }
}

/// What a group activity is built around.
enum GroupActivityTheme: Equatable, Hashable, Codable {
    case genre(ResidentMusicGenre)
    case mixed
    case wholeHome

    var label: String {
        switch self {
        case let .genre(genre): return genre.rawValue.capitalized
        case .mixed: return "Shared favourites"
        case .wholeHome: return "Whole home"
        }
    }
}

/// A suggested activity with the residents the app would invite.
struct GroupActivitySuggestion: Identifiable, Equatable {
    let id: String
    var title: String
    var theme: GroupActivityTheme
    var genre: ResidentMusicGenre?
    var recommendedIds: [UUID]
    var reason: String
    var matchCount: Int
    var overdueCount: Int
}

/// The chosen activity carried into the session and onto its record.
struct GroupActivityPlan: Equatable {
    var title: String
    var theme: GroupActivityTheme
    var participantIds: [UUID]
}

/// Everything the planner knows about one resident, ready to display.
struct GroupResidentInsight: Identifiable, Equatable {
    enum Flag: String, CaseIterable, Identifiable {
        case overdue          // no one-to-one in 7+ days (or ever)
        case dueGroup         // no group activity in the last 14 days
        case regular          // 2+ activities (either kind) in the last 14 days
        case smallGroups
        case prefersOneToOne
        case gentle           // declining trend / unsettled recently — keep the room calm

        var id: String { rawValue }

        var label: String {
            switch self {
            case .overdue: return "Overdue a visit"
            case .dueGroup: return "Due a group"
            case .regular: return "Regular"
            case .smallGroups: return "Small groups"
            case .prefersOneToOne: return "Prefers 1-to-1"
            case .gentle: return "Keep it gentle"
            }
        }
    }

    let id: UUID
    var displayName: String
    var favouriteGenre: ResidentMusicGenre
    var genres: Set<ResidentMusicGenre>
    var stockPortraitAssetName: String?
    var daysSinceOneToOne: Int?
    var oneToOneCount14d: Int
    var groupCount14d: Int
    var daysSinceGroup: Int?
    var averageGroupEngagement: Double?
    var trend: CareHomeImpactTrend
    var groupComfort: GroupComfort?
    var flags: [Flag]
    /// Higher = would benefit more from being included in the next group activity.
    var needScore: Double
    /// One line for the picker row, e.g. "Last 1-to-1 9 days ago · no group in 14 days".
    var statusLine: String
    /// Staff notes about this resident from recent group check-ins, most recent first (up to three).
    var recentGroupNotes: [GroupParticipantState] = []

    var isRecommendable: Bool { groupComfort != .prefersOneToOne }
}

/// One nudge for staff. Always a suggestion — staff keep the final say.
struct GroupPlannerSuggestion: Identifiable, Equatable {
    enum Kind: String {
        case attention, pairing, oneToOne, organise
        var systemImage: String {
            switch self {
            case .attention: return "exclamationmark.bubble"
            case .pairing: return "person.2"
            case .oneToOne: return "person.fill"
            case .organise: return "sparkles"
            }
        }
    }

    let id: String
    var kind: Kind
    var text: String
    /// Residents the suggestion is about; "Add" puts them into the selection.
    var residentIds: [UUID]
    var canAdd: Bool
}

struct GroupEngagementOverview: Equatable {
    struct ActivityOutcome: Identifiable, Equatable {
        var id: String { title }
        var title: String
        var sessions: Int
        var averageEngagement: Double
    }

    var regularIds: [UUID]
    var needEncouragementIds: [UUID]
    var bestActivities: [ActivityOutcome]
    var groupSessions14d: Int
}

struct GroupActivityPlannerPresentation: Equatable {
    var residents: [GroupResidentInsight]
    var activities: [GroupActivitySuggestion]
    var suggestions: [GroupPlannerSuggestion]
    var overview: GroupEngagementOverview
}

enum GroupActivityPlanner {
    static let windowDays = 14
    static let overdueDays = 7
    static let minimumGroupSize = 3

    static func build(
        residents: [CarePatientProfile],
        sessionRecords: [CareSessionRecord],
        groupRecords: [GroupSessionRecord],
        now: Date = Date()
    ) -> GroupActivityPlannerPresentation {
        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86_400)
        // Group records are shared across homes; only the ones that involved these residents count
        // (a record with no participants on file is a legacy whole-home session and is kept).
        let residentIds = Set(residents.map(\.id))
        let groupRecords = GroupSessionRecord.current(groupRecords).filter { record in
            record.participantIds.isEmpty || record.participantIds.contains { residentIds.contains($0) }
        }
        let recentGroups = groupRecords.filter { $0.date >= windowStart }
        let insights = residents
            .map { insight(for: $0, sessionRecords: sessionRecords, groupRecords: groupRecords, recentGroups: recentGroups, now: now) }
            .sorted { lhs, rhs in
                if lhs.needScore != rhs.needScore { return lhs.needScore > rhs.needScore }
                return lhs.displayName < rhs.displayName
            }
        let activities = suggestedActivities(from: insights)
        let suggestions = staffSuggestions(insights: insights, activities: activities)
        let overview = engagementOverview(insights: insights, recentGroups: recentGroups)
        return GroupActivityPlannerPresentation(
            residents: insights,
            activities: activities,
            suggestions: suggestions,
            overview: overview
        )
    }

    // MARK: Per-resident

    /// Genres a resident responds to: favourite, playlists on file, liked songs, and what they chose
    /// on the calm surface recently.
    static func genreAffinity(for resident: CarePatientProfile, sessionRecords: [CareSessionRecord]) -> [ResidentMusicGenre: Double] {
        var score: [ResidentMusicGenre: Double] = [resident.favouriteMusicGenre: 3]
        for group in resident.genrePlaylistGroups {
            score[group.genre, default: 0] += 1.5
        }
        // Catalogue songs (family picks, discovery playlists) are filed under their genre on the
        // profile; the bundled catalogue only knows the seven stems.
        let refGenres: [String: ResidentMusicGenre] = Dictionary(
            resident.genrePlaylistGroups.flatMap { group in group.playlists.flatMap { ($0.tracks ?? []).map { ($0.title, group.genre) } } },
            uniquingKeysWith: { first, _ in first }
        )
        func genre(forTitle title: String) -> ResidentMusicGenre? {
            refGenres[title] ?? ResidentPlaybackTrackCatalog.primaryGenre(for: title)
        }
        for title in resident.suggestedLikedTrackTitles {
            if let genre = genre(forTitle: title) {
                score[genre, default: 0] += 1
            }
        }
        for record in sessionRecords where record.patientId == resident.id {
            for (name, count) in countedPairs(record.residentGenresPlayedSummary) {
                if let genre = ResidentMusicGenre.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame }) {
                    score[genre, default: 0] += 0.5 * Double(count)
                }
            }
            for (title, count) in countedPairs(record.residentLikedTracksSummary) {
                if let genre = genre(forTitle: title) {
                    score[genre, default: 0] += 1 * Double(count)
                }
            }
        }
        return score
    }

    private static func insight(
        for resident: CarePatientProfile,
        sessionRecords: [CareSessionRecord],
        groupRecords: [GroupSessionRecord],
        recentGroups: [GroupSessionRecord],
        now: Date
    ) -> GroupResidentInsight {
        let own = sessionRecords.filter { $0.patientId == resident.id }.sorted { $0.date > $1.date }
        let windowStart = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let daysSince = own.first.map { max(0, Int(now.timeIntervalSince($0.date) / 86_400)) }
        let oneToOne14 = own.filter { $0.date >= windowStart }.count
        let myGroups = groupRecords
            .filter { $0.participantIds.contains(resident.id) }
            .sorted { $0.date > $1.date }
        let groups14 = myGroups.filter { $0.date >= windowStart }.count
        let daysSinceGroup = myGroups.first.map { max(0, Int(now.timeIntervalSince($0.date) / 86_400)) }
        // Per-person engagement: a staff note about this resident outranks the room's score for
        // that session. At a music group "engaged" lifts the room's score to at least 7; an activity logged afterwards
        // has no room score, so the person's own note is the score (enjoyed 9 · engaged 7 · looked on 5 · unsettled 3
        // · left early 2).
        let engagementScores = myGroups.prefix(5).compactMap { record -> Double? in
            guard let note = record.participantNote(for: resident.id) else { return record.engagementRating.map(Double.init) }
            if note == .engaged, record.isMusic { return max(Double(record.engagementRating ?? 7), 7) }
            return Double(note.engagementScore)
        }
        let avgEngagement = engagementScores.isEmpty ? nil : engagementScores.reduce(0, +) / Double(engagementScores.count)
        let recentNotes = myGroups.prefix(3).compactMap { $0.participantNote(for: resident.id) }
        let trend = CareHomeAnalytics.residentTrend(resident: resident, records: sessionRecords, now: now)
        let affinity = genreAffinity(for: resident, sessionRecords: sessionRecords)
        let genres = Set(affinity.filter { $0.value >= 1.5 }.map(\.key))
        let unsettled = own.first.map { $0.calmPercent < 50 } ?? false
        let dislikesCompany = resident.dislikes.contains { $0.localizedCaseInsensitiveContains("chatter") || $0.localizedCaseInsensitiveContains("crowd") }

        var flags: [GroupResidentInsight.Flag] = []
        var need = 0.0
        if daysSince == nil || daysSince! >= overdueDays {
            flags.append(.overdue); need += 2
        }
        if groups14 == 0 {
            flags.append(.dueGroup); need += 1.5
        }
        if oneToOne14 + groups14 >= 2 {
            flags.append(.regular); need -= 0.5
        }
        if trend == .declining || unsettled {
            flags.append(.gentle); need += 0.5
        }
        switch resident.groupComfort {
        case .smallGroupsOnly:
            flags.append(.smallGroups); need -= 0.5
        case .prefersOneToOne:
            flags.append(.prefersOneToOne); need -= 2
        case .enjoysGroups, nil:
            if dislikesCompany { flags.append(.smallGroups); need -= 0.5 }
        }
        if let avgEngagement, avgEngagement >= 7 { need += 0.5 }      // groups visibly do them good

        var parts: [String] = []
        parts.append(daysSince.map { $0 == 0 ? "One-to-one today" : "Last one-to-one \($0) day\($0 == 1 ? "" : "s") ago" } ?? "No one-to-one on file")
        parts.append(groups14 == 0 ? "no group in 14 days" : "\(groups14) group\(groups14 == 1 ? "" : "s") in 14 days")
        if let lastNote = recentNotes.first {
            parts.append("\(lastNote.label.lowercased()) last time")
        }

        return GroupResidentInsight(
            id: resident.id,
            displayName: resident.displayName,
            favouriteGenre: resident.favouriteMusicGenre,
            genres: genres,
            stockPortraitAssetName: resident.stockPortraitAssetName,
            daysSinceOneToOne: daysSince,
            oneToOneCount14d: oneToOne14,
            groupCount14d: groups14,
            daysSinceGroup: daysSinceGroup,
            averageGroupEngagement: avgEngagement,
            trend: trend,
            groupComfort: resident.groupComfort,
            flags: flags,
            needScore: need,
            statusLine: parts.joined(separator: " · "),
            recentGroupNotes: recentNotes
        )
    }

    // MARK: Activities

    static func activityTitle(for genre: ResidentMusicGenre) -> String {
        switch genre {
        case .classical: return "Classical listening circle"
        case .jazz: return "Jazz lounge"
        case .rock: return "Rock & roll afternoon"
        case .pop: return "Pop memories"
        case .soul: return "Soul session"
        case .country: return "Country morning"
        case .gospel: return "Gospel gathering"
        }
    }

    private static func suggestedActivities(from insights: [GroupResidentInsight]) -> [GroupActivitySuggestion] {
        var out: [GroupActivitySuggestion] = []
        let recommendable = insights.filter { $0.isRecommendable && betterServedOneToOne($0) == nil }
        for genre in ResidentMusicGenre.allCases {
            let fans = recommendable.filter { $0.genres.contains(genre) }
            guard fans.count >= minimumGroupSize else { continue }
            let overdue = fans.filter { $0.flags.contains(.overdue) || $0.flags.contains(.dueGroup) }
            let score = fans.reduce(0.0) { $0 + max(0, $1.needScore) } + Double(fans.count) * 0.5
            let reason: String
            if overdue.isEmpty {
                reason = "\(fans.count) residents respond to \(genre.rawValue) — all seen recently, a good mood-lifter."
            } else {
                reason = "\(fans.count) residents respond to \(genre.rawValue); \(overdue.count) of them \(overdue.count == 1 ? "is" : "are") overdue a visit or a group."
            }
            out.append(
                GroupActivitySuggestion(
                    id: "genre.\(genre.rawValue)|\(score)",
                    title: activityTitle(for: genre),
                    theme: .genre(genre),
                    genre: genre,
                    recommendedIds: fans.sorted { $0.needScore > $1.needScore }.prefix(8).map(\.id),
                    reason: reason,
                    matchCount: fans.count,
                    overdueCount: overdue.count
                )
            )
        }
        out.sort { lhs, rhs in
            let l = Double(lhs.id.split(separator: "|").last ?? "0") ?? 0
            let r = Double(rhs.id.split(separator: "|").last ?? "0") ?? 0
            return l > r
        }
        var ranked = Array(out.prefix(3)).map { suggestion -> GroupActivitySuggestion in
            var copy = suggestion
            copy = GroupActivitySuggestion(
                id: String(suggestion.id.split(separator: "|").first ?? Substring(suggestion.id)),
                title: suggestion.title, theme: suggestion.theme, genre: suggestion.genre,
                recommendedIds: suggestion.recommendedIds, reason: suggestion.reason,
                matchCount: suggestion.matchCount, overdueCount: suggestion.overdueCount
            )
            return copy
        }

        // Shared favourites: residents who respond to two or more of the home's top genres.
        let topGenres = ranked.compactMap(\.genre).prefix(3)
        if topGenres.count >= 2 {
            let shared = recommendable.filter { $0.genres.intersection(Set(topGenres)).count >= 2 }
            if shared.count >= minimumGroupSize {
                let genreNames = topGenres.map { $0.rawValue }
                let names = genreNames.count == 2
                    ? "\(genreNames[0]) and \(genreNames[1])"
                    : genreNames.dropLast().joined(separator: ", ") + " and \(genreNames.last!)"
                ranked.append(
                    GroupActivitySuggestion(
                        id: "mixed",
                        title: "Shared favourites",
                        theme: .mixed,
                        genre: nil,
                        recommendedIds: shared.sorted { $0.needScore > $1.needScore }.prefix(8).map(\.id),
                        reason: "\(shared.count) residents enjoy two or more of \(names) — a mixed set they can share.",
                        matchCount: shared.count,
                        overdueCount: shared.filter { $0.flags.contains(.overdue) || $0.flags.contains(.dueGroup) }.count
                    )
                )
            }
        }
        return ranked
    }

    // MARK: Staff suggestions

    /// Residents the planner would rather see one-to-one before a group. Decided once, so the
    /// same person is never both "pair them up" and "see them alone".
    static func betterServedOneToOne(_ insight: GroupResidentInsight) -> String? {
        if insight.groupComfort == .prefersOneToOne {
            return "their profile says they prefer one-to-one"
        }
        if let avg = insight.averageGroupEngagement, avg < 4.5 {
            return String(format: "group engagement has averaged %.1f/10", avg)
        }
        // Two check-ins in a row where staff noted them unsettled or leaving early.
        let difficult = insight.recentGroupNotes.prefix(2).filter(\.isDifficult)
        if insight.recentGroupNotes.count >= 2, difficult.count == 2 {
            return "staff noted them \(difficult[0].label.lowercased()) at their last two groups"
        }
        if insight.flags.contains(.gentle), insight.groupComfort != .enjoysGroups, insight.trend == .declining {
            return "recent sessions have been unsettled"
        }
        return nil
    }

    private static func staffSuggestions(
        insights: [GroupResidentInsight],
        activities: [GroupActivitySuggestion]
    ) -> [GroupPlannerSuggestion] {
        var out: [GroupPlannerSuggestion] = []
        let byId = Dictionary(uniqueKeysWithValues: insights.map { ($0.id, $0) })
        let oneToOneIds = Set(insights.filter { betterServedOneToOne($0) != nil }.map(\.id))

        // 1. Nobody overlooked: overdue a visit and no group either.
        let overlooked = insights.filter { $0.flags.contains(.overdue) && $0.flags.contains(.dueGroup) && $0.isRecommendable && !oneToOneIds.contains($0.id) }
        if !overlooked.isEmpty {
            let names = overlooked.prefix(3).map(\.displayName)
            let more = overlooked.count > 3 ? " and \(overlooked.count - 3) more" : ""
            out.append(
                GroupPlannerSuggestion(
                    id: "attention",
                    kind: .attention,
                    text: "\(joined(names))\(more) \(overlooked.count == 1 ? "has" : "have") had no one-to-one or group in over a week — include them, or plan a visit.",
                    residentIds: overlooked.prefix(6).map(\.id),
                    canAdd: true
                )
            )
        }

        // 2. Organise: the strongest activity, phrased as an action.
        if let top = activities.first {
            out.append(
                GroupPlannerSuggestion(
                    id: "organise.\(top.id)",
                    kind: .organise,
                    text: top.overdueCount > 0
                        ? "A \(top.title.lowercased()) would reach \(top.overdueCount) resident\(top.overdueCount == 1 ? "" : "s") who \(top.overdueCount == 1 ? "is" : "are") overdue, with \(top.matchCount) who respond to it."
                        : "\(top.matchCount) residents respond to \(top.theme.label.lowercased()) — a \(top.title.lowercased()) is the easiest win today.",
                    residentIds: top.recommendedIds,
                    canAdd: true
                )
            )
        }

        // 3. Pairings: two residents who share a genre and haven't been in a group this fortnight.
        var pairingsAdded = 0
        for activity in activities where pairingsAdded < 2 {
            guard let genre = activity.genre else { continue }
            let candidates = activity.recommendedIds.compactMap { byId[$0] }
                .filter { $0.groupCount14d == 0 && $0.genres.contains(genre) && !oneToOneIds.contains($0.id) }
            guard candidates.count >= 2 else { continue }
            let a = candidates[0], b = candidates[1]
            out.append(
                GroupPlannerSuggestion(
                    id: "pair.\(genre.rawValue)",
                    kind: .pairing,
                    text: "\(a.displayName) and \(b.displayName) both respond to \(genre.rawValue) and haven’t shared a session in the last 14 days.",
                    residentIds: [a.id, b.id],
                    canAdd: true
                )
            )
            pairingsAdded += 1
        }

        // 4. Better served one-to-one.
        for ins in insights.filter({ oneToOneIds.contains($0.id) }).prefix(2) {
            let why = betterServedOneToOne(ins) ?? "recent sessions have been unsettled"
            out.append(
                GroupPlannerSuggestion(
                    id: "one.\(ins.id.uuidString)",
                    kind: .oneToOne,
                    text: "Consider a one-to-one for \(ins.displayName) rather than the group — \(why).",
                    residentIds: [ins.id],
                    canAdd: false
                )
            )
        }
        return out
    }

    // MARK: Engagement overview

    private static func engagementOverview(
        insights: [GroupResidentInsight],
        recentGroups: [GroupSessionRecord]
    ) -> GroupEngagementOverview {
        let regulars = insights.filter { $0.flags.contains(.regular) }.map(\.id)
        let needEncouragement = insights
            .filter { $0.groupCount14d == 0 && $0.isRecommendable }
            .sorted { $0.needScore > $1.needScore }
            .map(\.id)
        var byTitle: [String: [Int]] = [:]
        for record in recentGroups {
            guard let engagement = record.engagementRating else { continue }
            byTitle[record.activityTitle ?? "Whole-home playlist", default: []].append(engagement)
        }
        let best = byTitle
            .map { GroupEngagementOverview.ActivityOutcome(title: $0.key, sessions: $0.value.count, averageEngagement: Double($0.value.reduce(0, +)) / Double($0.value.count)) }
            .sorted { $0.averageEngagement > $1.averageEngagement }
        return GroupEngagementOverview(
            regularIds: regulars,
            needEncouragementIds: needEncouragement,
            bestActivities: Array(best.prefix(3)),
            groupSessions14d: recentGroups.count
        )
    }

    // MARK: Helpers

    /// "Classical ×2, Gospel ×3" → [("Classical", 2), ("Gospel", 3)]
    static func countedPairs(_ summary: String?) -> [(String, Int)] {
        guard let summary, !summary.isEmpty else { return [] }
        return summary.split(separator: ",").compactMap { part -> (String, Int)? in
            let piece = part.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { return nil }
            guard let mark = piece.lastIndex(of: "×") else { return (piece, 1) }
            let name = piece[..<mark].trimmingCharacters(in: .whitespaces)
            let count = Int(piece[piece.index(after: mark)...].trimmingCharacters(in: .whitespaces)) ?? 1
            return (name, count)
        }
    }

    private static func joined(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and \(names.last!)"
        }
    }

    /// Staff-set group comfort for the mock roster (keyed by first name); everyone else is unknown.
    static func seededGroupComfort(forFirstName name: String) -> GroupComfort? {
        switch name.lowercased() {
        case "gladys", "ethel": return .prefersOneToOne
        case "cyril", "muriel", "elena": return .smallGroupsOnly
        case "arthur", "margaret", "george", "irene", "harold", "james": return .enjoysGroups
        default: return nil
        }
    }
}

// MARK: - Demo history

/// A fortnight of group sessions for the mock home, so the planner's engagement view and the
/// "activities that land best" list have data on the first launch. Participants are chosen from
/// the residents' genre affinities exactly as the planner would, so history and suggestions agree.
enum GroupActivityMockData {
    static func records(residents: [CarePatientProfile], sessionRecords: [CareSessionRecord], homeId: UUID, now: Date = Date()) -> [GroupSessionRecord] {
        let roster = residents.filter { $0.homeId == homeId && !$0.isProvisional && $0.isActive }
        guard roster.count >= 6 else { return [] }
        let affinity = Dictionary(uniqueKeysWithValues: roster.map { ($0.id, GroupActivityPlanner.genreAffinity(for: $0, sessionRecords: sessionRecords)) })
        func fans(of genre: ResidentMusicGenre, limit: Int, skip: Int = 0) -> [UUID] {
            roster.filter { (affinity[$0.id]?[genre] ?? 0) >= 1.5 }
                .sorted { $0.displayName < $1.displayName }
                .dropFirst(skip)
                .prefix(limit)
                .map(\.id)
        }
        // (days ago, genre, participants, morale, alertness, orientation, engagement, minutes, tracks)
        let plan: [(Int, ResidentMusicGenre, [UUID], Int, Int, Int, Int, Int, Int)] = [
            (12, .classical, fans(of: .classical, limit: 6), 7, 6, 6, 7, 28, 6),
            (10, .rock, fans(of: .rock, limit: 5), 8, 8, 6, 8, 24, 5),
            (8, .jazz, fans(of: .jazz, limit: 5), 7, 7, 6, 6, 26, 5),
            (6, .classical, fans(of: .classical, limit: 6, skip: 2), 8, 7, 7, 8, 30, 7),
            (3, .country, fans(of: .country, limit: 4), 6, 6, 5, 5, 20, 4),
            (1, .soul, fans(of: .soul, limit: 5), 8, 7, 7, 9, 27, 6),
        ]
        let music: [GroupSessionRecord] = plan.enumerated().compactMap { index, p in
            let (daysAgo, genre, participants, morale, alert, orientation, engagement, minutes, tracks) = p
            guard participants.count >= 3 else { return nil }
            return GroupSessionRecord(
                id: UUID(uuidString: String(format: "62000000-0000-4000-8000-%012x", index + 1))!,
                date: now.addingTimeInterval(-Double(daysAgo) * 86_400 - 3_600 * 3),
                durationSeconds: minutes * 60,
                tracksPlayed: tracks,
                moraleRating: morale,
                alertnessRating: alert,
                lucidityRating: orientation,
                engagementRating: engagement,
                staffNote: index == 1 ? "Two residents got up to dance." : nil,
                playlistSnapshot: ResidentPlaybackTrackCatalog.titles(for: genre),
                participantIds: participants,
                activityTitle: GroupActivityPlanner.activityTitle(for: genre),
                theme: .genre(genre)
            )
        }
        return music + activitiesOutsideTheApp(roster: roster, now: now)
    }

    /// Two activities held away from the app, written up the way staff would (`ActivityLogDraft`), so the Home Admin
    /// programme card, the profile line and the planner show them from the first launch.
    private static func activitiesOutsideTheApp(roster: [CarePatientProfile], now: Date) -> [GroupSessionRecord] {
        let alphabetical = roster.sorted { $0.displayName < $1.displayName }
        let responses: [GroupParticipantState] = [.enjoyed, .engaged, .engaged, .lookedOn, .enjoyed, .engaged, .unsettled, .enjoyed]
        // (days ago, kind, skip, count, minutes, note)
        let plan: [(Int, OtherActivityKind, Int, Int, Int, String?)] = [
            (5, .gamesAndQuizzes, 1, 8, 45, "Bingo in the lounge. Several called the numbers out with the caller."),
            (2, .exercise, 3, 7, 30, "Seated exercise class — most joined the arm stretches."),
        ]
        return plan.enumerated().compactMap { index, p in
            let (daysAgo, kind, skip, count, minutes, note) = p
            let people = alphabetical.dropFirst(skip).prefix(count).map(\.id)
            guard people.count >= 3 else { return nil }
            var draft = ActivityLogDraft(now: now.addingTimeInterval(-Double(daysAgo) * 86_400 - 3_600 * 4))
            draft.kind = kind
            draft.durationMinutes = minutes
            draft.note = note ?? ""
            for (offset, id) in people.enumerated() {
                draft.attendeeIds.append(id)
                draft.responses[id] = responses[offset % responses.count]
            }
            return GroupSessionRecord(
                loggedActivity: draft,
                id: UUID(uuidString: String(format: "62000000-0000-4000-8000-%012x", 7 + index))!,
                homeId: nil,
                authorAccountId: nil
            )
        }
    }
}
