import Foundation

// MARK: - Group activities beyond the planner: profile + dashboard read models

/// One resident's recent group participation, for the profile.
struct GroupParticipationSummary: Equatable {
    var count14d: Int
    var lastTitle: String?
    var lastDaysAgo: Int?
    var lastEngagement: Int?
    /// What staff noted about this resident at the last group's check-in, if anything.
    var lastNote: GroupParticipantState? = nil

    var line: String {
        var parts: [String] = []
        parts.append(count14d == 0
            ? "No group activities in the last \(GroupActivityPlanner.windowDays) days"
            : "\(count14d) group activit\(count14d == 1 ? "y" : "ies") in the last \(GroupActivityPlanner.windowDays) days")
        if let lastTitle, let lastDaysAgo {
            let when = lastDaysAgo == 0 ? "today" : lastDaysAgo == 1 ? "yesterday" : "\(lastDaysAgo) days ago"
            var last = "last: \(lastTitle), \(when)"
            if let lastEngagement { last += " · room engagement \(lastEngagement)/10" }
            if let lastNote {
                switch lastNote {
                case .engaged: last += " · they were engaged"
                case .unsettled: last += " · they were unsettled"
                case .leftEarly: last += " · they left early"
                }
            }
            parts.append(last)
        }
        return parts.joined(separator: " · ")
    }
}

/// The home's group programme over the dashboard window, for Home Admin.
struct GroupProgrammeSummary: Equatable {
    var sessions14d: Int
    var residentsReached: Int
    var activeResidents: Int
    var averageEngagement: Double?
    var averageMorale: Double?
    var bestActivity: GroupEngagementOverview.ActivityOutcome?
    var noGroupCount: Int
    var noGroupNames: [String]
}

enum GroupActivityReadModels {
    static func participation(for patientId: UUID, groupRecords: [GroupSessionRecord], now: Date = Date()) -> GroupParticipationSummary {
        let mine = groupRecords
            .filter { $0.participantIds.contains(patientId) }
            .sorted { $0.date > $1.date }
        let windowStart = now.addingTimeInterval(-Double(GroupActivityPlanner.windowDays) * 86_400)
        let last = mine.first
        return GroupParticipationSummary(
            count14d: mine.filter { $0.date >= windowStart }.count,
            lastTitle: last.map { $0.activityTitle ?? "Whole-home playlist" },
            lastDaysAgo: last.map { max(0, Int(now.timeIntervalSince($0.date) / 86_400)) },
            lastEngagement: last?.engagementRating,
            lastNote: last?.participantNote(for: patientId)
        )
    }

    static func programme(
        residents: [CarePatientProfile],
        sessionRecords: [CareSessionRecord],
        groupRecords: [GroupSessionRecord],
        now: Date = Date()
    ) -> GroupProgrammeSummary {
        let windowStart = now.addingTimeInterval(-Double(GroupActivityPlanner.windowDays) * 86_400)
        let residentIds = Set(residents.map(\.id))
        let recent = groupRecords
            .filter { $0.date >= windowStart && ($0.participantIds.isEmpty || $0.participantIds.contains { residentIds.contains($0) }) }
        let reached = Set(recent.flatMap { record in
            record.participantIds.isEmpty ? Array(residentIds) : record.participantIds.filter { residentIds.contains($0) }
        }).count
        let engagement = recent.compactMap { $0.engagementRating.map(Double.init) }
        let morale = recent.compactMap { $0.moraleRating.map(Double.init) }
        let planner = GroupActivityPlanner.build(residents: residents, sessionRecords: sessionRecords, groupRecords: groupRecords, now: now)
        let byId = Dictionary(uniqueKeysWithValues: planner.residents.map { ($0.id, $0) })
        let noGroup = planner.overview.needEncouragementIds
        return GroupProgrammeSummary(
            sessions14d: recent.count,
            residentsReached: reached,
            activeResidents: residents.count,
            averageEngagement: engagement.isEmpty ? nil : engagement.reduce(0, +) / Double(engagement.count),
            averageMorale: morale.isEmpty ? nil : morale.reduce(0, +) / Double(morale.count),
            bestActivity: planner.overview.bestActivities.first,
            noGroupCount: noGroup.count,
            noGroupNames: noGroup.prefix(3).compactMap { byId[$0]?.displayName }
        )
    }
}

/// The four 1–10 ratings from the most recent group check-in (shown on the roster's Group sessions card).
struct GroupSessionRatings: Equatable {
    let morale: Int
    let alertness: Int
    let orientation: Int
    let engagement: Int
}

extension SessionPOCState {
    /// `nil` until a group session has been rated on all four scales.
    func latestGroupSessionRatings() -> GroupSessionRatings? {
        guard let last = groupSessionRecords.first,
              let morale = last.moraleRating,
              let alertness = last.alertnessRating,
              let lucidity = last.lucidityRating,
              let engagement = last.engagementRating
        else { return nil }
        return GroupSessionRatings(morale: morale, alertness: alertness, orientation: lucidity, engagement: engagement)
    }

    /// Staff-set comfort in company; drives the planner's recommendations.
    func setResidentGroupComfort(for patientId: UUID, comfort: GroupComfort?) {
        guard let index = carePatients.firstIndex(where: { $0.id == patientId }),
              carePatients[index].groupComfort != comfort else { return }
        var patients = carePatients
        patients[index].groupComfort = comfort
        carePatients = patients
    }

    func groupParticipationSummary(for patientId: UUID) -> GroupParticipationSummary {
        GroupActivityReadModels.participation(for: patientId, groupRecords: groupSessionRecords)
    }

    /// For the Home Admin dashboard. Runs the planner over the whole home, so it is cached the same
    /// way as `careHomeDashboardPresentation()` and only rebuilt when residents, records or home change.
    func groupProgrammeSummary() -> GroupProgrammeSummary {
        let key = CareRosterUIStore.GroupProgrammeCacheKey(
            homeId: currentHomeId,
            dataRevision: careData.dataRevision,
            groupRecordCount: groupSessionRecords.count
        )
        if let cache = rosterUI.groupProgrammeCache, cache.key == key {
            return cache.value
        }
        let value = GroupActivityReadModels.programme(
            residents: residentsInCurrentHome(),
            sessionRecords: careSessionRecords,
            groupRecords: groupSessionRecords
        )
        rosterUI.groupProgrammeCache = (key, value)
        return value
    }
}
