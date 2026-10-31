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
    /// Activities logged outside the app for this resident alone (a walk, a pet visit): visits, not groups.
    var oneToOne14d: Int = 0
    var lastOneToOneTitle: String? = nil
    var lastOneToOneDaysAgo: Int? = nil
    var lastOneToOneNote: GroupParticipantState? = nil

    /// "2 one-to-one activities in the last 14 days · last: Pet visit, 2 days ago · they enjoyed it", or nil when none.
    var oneToOneLine: String? {
        guard oneToOne14d > 0, let title = lastOneToOneTitle, let days = lastOneToOneDaysAgo else { return nil }
        let when = days == 0 ? "today" : days == 1 ? "yesterday" : "\(days) days ago"
        var line = "\(oneToOne14d) one-to-one activit\(oneToOne14d == 1 ? "y" : "ies") in the last \(GroupActivityPlanner.windowDays) days · last: \(title), \(when)"
        if let note = lastOneToOneNote {
            switch note {
            case .enjoyed: line += " · they enjoyed it"
            case .engaged: line += " · they were engaged"
            case .lookedOn: line += " · they looked on"
            case .unsettled: line += " · they were unsettled"
            case .leftEarly: line += " · they left early"
            }
        }
        return line
    }

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
                case .enjoyed: last += " · they enjoyed it"
                case .engaged: last += " · they were engaged"
                case .lookedOn: last += " · they looked on"
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
    /// Activities staff logged as held outside the app (bingo, exercise, a visiting singer…), over the same window.
    var activities14d: Int = 0
    var activityAttendances14d: Int = 0
    var activityAverageEngagement: Double? = nil
}

enum GroupActivityReadModels {
    static func participation(for patientId: UUID, groupRecords: [GroupSessionRecord], now: Date = Date()) -> GroupParticipationSummary {
        let everything = GroupSessionRecord.current(groupRecords)
            .filter { $0.participantIds.contains(patientId) }
            .sorted { $0.date > $1.date }
        let mine = everything.filter { !$0.isOneToOneActivity }
        let alone = everything.filter(\.isOneToOneActivity)
        let windowStart = now.addingTimeInterval(-Double(GroupActivityPlanner.windowDays) * 86_400)
        let last = mine.first
        let lastAlone = alone.first
        return GroupParticipationSummary(
            count14d: mine.filter { $0.date >= windowStart }.count,
            lastTitle: last?.displayTitle,
            lastDaysAgo: last.map { max(0, Int(now.timeIntervalSince($0.date) / 86_400)) },
            lastEngagement: last?.engagementRating,
            lastNote: last?.participantNote(for: patientId),
            oneToOne14d: alone.filter { $0.date >= windowStart }.count,
            lastOneToOneTitle: lastAlone?.displayTitle,
            lastOneToOneDaysAgo: lastAlone.map { max(0, Int(now.timeIntervalSince($0.date) / 86_400)) },
            lastOneToOneNote: lastAlone?.participantNote(for: patientId)
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
        let inWindow = GroupSessionRecord.current(groupRecords)
            .filter { $0.date >= windowStart && ($0.participantIds.isEmpty || $0.participantIds.contains { residentIds.contains($0) }) }
        // The group programme is groups: an activity logged for one resident is a one-to-one visit, so it is left out of
        // sessions, reach, engagement and morale, but still counted under "Outside the app" below.
        let recent = inWindow.filter { !$0.isOneToOneActivity }
        let reached = Set(recent.flatMap { record in
            record.participantIds.isEmpty ? Array(residentIds) : record.participantIds.filter { residentIds.contains($0) }
        }).count
        let engagement = recent.compactMap { $0.engagementRating.map(Double.init) }
        let morale = recent.compactMap { $0.moraleRating.map(Double.init) }
        let outside = inWindow.filter { !$0.isMusic }
        let outsideEngagement = outside.compactMap { $0.engagementRating.map(Double.init) }
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
            noGroupNames: noGroup.prefix(3).compactMap { byId[$0]?.displayName },
            activities14d: outside.count,
            activityAttendances14d: outside.reduce(0) { $0 + $1.participantIds.filter { residentIds.contains($0) }.count },
            activityAverageEngagement: outsideEngagement.isEmpty ? nil : outsideEngagement.reduce(0, +) / Double(outsideEngagement.count)
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
        // The most recent *music* session: an activity logged outside the app carries no room ratings. By date, not
        // position — seeded and synced history arrives oldest first, a session just saved is inserted at the front.
        guard let last = GroupSessionRecord.current(groupSessionRecords).filter(\.isMusic).max(by: { $0.date < $1.date }),
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

// MARK: - Logging an activity held outside the app

/// The most recent activity logged outside the app, for the roster card.
struct LoggedActivitySummary: Equatable {
    var title: String
    var daysAgo: Int
    var attended: Int

    var line: String {
        let when = daysAgo == 0 ? "today" : daysAgo == 1 ? "yesterday" : "\(daysAgo) days ago"
        return "\(title) · \(when) · \(attended) attended"
    }
}

extension SessionPOCState {
    func latestLoggedActivity(now: Date = Date()) -> LoggedActivitySummary? {
        guard let last = GroupSessionRecord.current(groupSessionRecords).filter({ !$0.isMusic }).max(by: { $0.date < $1.date }) else { return nil }
        return LoggedActivitySummary(
            title: last.displayTitle,
            daysAgo: max(0, Int(now.timeIntervalSince(last.date) / 86_400)),
            attended: last.participantIds.count
        )
    }

    /// A blank form. For a Care at home account it already holds the one person it looks after: there is no list to pick from.
    private func blankActivityDraft() -> ActivityLogDraft {
        var draft = ActivityLogDraft()
        if isHouseholdAccount, let resident = householdResident() {
            draft.solo = true
            draft.attendeeIds = [resident.id]
        } else if let residentId = groupSession.activitySoloResidentId {
            draft.solo = true
            draft.attendeeIds = [residentId]
        }
        return draft
    }

    /// Whether the open form is for one person alone: a Care at home account, or staff who came from a resident's profile.
    var activityFormIsSolo: Bool {
        isHouseholdAccount || groupSession.activitySoloResidentId != nil
    }

    func beginActivityLog() {
        guard isSignedIn else {
            phase = .home
            return
        }
        groupSession.activitySoloResidentId = nil
        groupSession.activityReturnPhase = nil
        groupSession.activityDraft = blankActivityDraft()
        groupSession.activityErrors = [:]
        transitionToPhase(.careActivityLog)
    }

    /// "Log an activity" on one resident's profile: the one-person form for them, a one-to-one visit.
    func beginActivityLog(for residentId: UUID) {
        guard isSignedIn else {
            phase = .home
            return
        }
        selectedCarePatientId = residentId
        groupSession.activitySoloResidentId = residentId
        groupSession.activityReturnPhase = .carePatientDetail
        groupSession.activityDraft = blankActivityDraft()
        groupSession.activityErrors = [:]
        transitionToPhase(.careActivityLog)
    }

    /// Back to the roster for staff, to the resident's profile if that is where it was opened, to the person's home page for
    /// a Care at home account.
    func cancelActivityLog() {
        let target = groupSession.activityReturnPhase ?? staffHubPhase()
        groupSession.activitySoloResidentId = nil
        groupSession.activityReturnPhase = nil
        groupSession.activityDraft = ActivityLogDraft()
        groupSession.activityErrors = [:]
        transitionToPhase(target)
    }

    /// The residents staff can pick from, A–Z — or the one person a Care at home account looks after.
    func activityLogResidents() -> [CarePatientProfile] {
        if isHouseholdAccount { return householdResident().map { [$0] } ?? [] }
        if let residentId = groupSession.activitySoloResidentId { return carePatient(id: residentId).map { [$0] } ?? [] }
        return residentsInCurrentHome().sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// The home a logged activity belongs to.
    private func activityHomeId() -> UUID? {
        currentHouseholdAccount()?.homeId ?? currentHomeId
    }

    func toggleActivityAttendee(_ id: UUID) {
        groupSession.activityDraft.toggleAttendee(id)
        clearActivityError("activity.attendees")
        clearActivityError("activity.responses")
    }

    func setActivityResponse(_ response: GroupParticipantState, for id: UUID) {
        groupSession.activityDraft.responses[id] = response
        clearActivityError("activity.responses")
    }

    func clearActivityError(_ field: String) {
        if groupSession.activityErrors[field] != nil { groupSession.activityErrors[field] = nil }
    }

    /// The activities logged outside the app for the current home that still count, newest first.
    func recentLoggedActivities(limit: Int = 5) -> [GroupSessionRecord] {
        let ids = Set(activityLogResidents().map(\.id))
        return GroupSessionRecord.current(groupSessionRecords)
            .filter { !$0.isMusic && $0.participantIds.contains { ids.contains($0) } }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    /// Loads a logged activity into the form; saving writes a correction that replaces it.
    func beginEditingActivity(_ record: GroupSessionRecord) {
        var draft = ActivityLogDraft(editing: record)
        draft.solo = activityFormIsSolo
        groupSession.activityDraft = draft
        groupSession.activityErrors = [:]
    }

    /// Starts a new entry from an earlier one: same activity, length and people, now, with how they were left to say.
    func beginRepeatingActivity(_ record: GroupSessionRecord) {
        var draft = ActivityLogDraft(repeating: record)
        draft.solo = activityFormIsSolo
        groupSession.activityDraft = draft
        groupSession.activityErrors = [:]
    }

    func stopEditingActivity() {
        groupSession.activityDraft = blankActivityDraft()
        groupSession.activityErrors = [:]
    }

    /// Removes a logged activity from the dashboards. Nothing is deleted: a withdrawal record supersedes it.
    func withdrawActivity(_ record: GroupSessionRecord) {
        let withdrawal = GroupSessionRecord(withdrawing: record, homeId: activityHomeId(), authorAccountId: signedInSupervisorId)
        groupSessionRecords.insert(withdrawal, at: 0)
        if groupSession.activityDraft.replacing == record.id { stopEditingActivity() }
        MainActor.assumeIsolated { CalmExperienceFeedback.saved(announcing: "Activity removed.") }
    }

    /// "Note everyone as…": fills in the attendees nobody has said anything about yet, leaving the rest as they are.
    func setActivityResponseForUnnoted(_ response: GroupParticipantState) {
        for id in groupSession.activityDraft.unnotedIds { groupSession.activityDraft.responses[id] = response }
        clearActivityError("activity.responses")
    }

    /// Writes the log as a group record (which syncs and feeds the dashboards) and returns to the roster, or shows what
    /// is missing and stays.
    func saveActivityLog() {
        let draft = groupSession.activityDraft
        let names = Dictionary(uniqueKeysWithValues: activityLogResidents().map { ($0.id, $0.displayName) })
        let problems = draft.problems(names: names)
        guard problems.isEmpty else {
            groupSession.activityErrors = Dictionary(problems.map { ($0.field, $0.message) }, uniquingKeysWith: { first, _ in first })
            let first = problems.first?.message
            MainActor.assumeIsolated { CalmExperienceFeedback.attention(announcing: first) }
            return
        }
        guard let record = GroupSessionRecord(loggedActivity: draft, homeId: activityHomeId(), authorAccountId: signedInSupervisorId) else { return }
        groupSessionRecords.insert(record, at: 0)
        MainActor.assumeIsolated { CalmExperienceFeedback.saved(announcing: "Activity saved.") }
        cancelActivityLog()
    }
}

// MARK: - Care at home: activities outside the app

extension SessionPOCState {
    /// How the person this household looks after got on at the things done outside the app, over the last 30 days.
    func householdActivityInsights(now: Date = Date()) -> ActivityInsights? {
        guard let resident = householdResident() else { return nil }
        return ActivityInsights.build(records: groupSessionRecords, residentId: resident.id, now: now)
    }
}
