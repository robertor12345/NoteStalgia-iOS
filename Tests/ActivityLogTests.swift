import XCTest
@testable import NoteStalgia_iOS

/// An activity held outside the app is logged as an ordinary group record, so these tests cover the two halves of that
/// promise: the form turns into a well-formed record, and everything that reads group history counts it correctly.
final class ActivityLogTests: XCTestCase {
    private let residents = CareStaffMockData.initialPatients
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func draft(kind: OtherActivityKind? = .gamesAndQuizzes, responses: [GroupParticipantState?] = [.enjoyed, .engaged, .lookedOn]) -> ActivityLogDraft {
        var draft = ActivityLogDraft(now: now.addingTimeInterval(-3_600))
        draft.kind = kind
        for (resident, response) in zip(residents, responses) {
            draft.toggleAttendee(resident.id)
            draft.responses[resident.id] = response
        }
        return draft
    }

    // MARK: The form

    func testRemovingAnAttendeeRemovesTheirLine() {
        var form = draft()
        let first = residents[0].id
        form.toggleAttendee(first)
        XCTAssertFalse(form.isAttending(first))
        XCTAssertNil(form.responses[first])
        XCTAssertEqual(form.attendeeIds.count, 2)
    }

    func testRoomEngagementIsTheMeanOfThePeopleNoted() {
        // enjoyed 9 + engaged 7 + looked on 5 = 21 / 3 = 7
        XCTAssertEqual(draft().averageEngagement, 7)
        XCTAssertNil(ActivityLogDraft(now: now).averageEngagement)
    }

    func testAnEmptyFormNamesEachThingMissing() {
        let problems = ActivityLogDraft(now: now).problems(names: [:], now: now)
        XCTAssertEqual(problems.map(\.field), ["activity.kind", "activity.attendees"])
    }

    func testSomethingElseNeedsAName() {
        var form = draft(kind: .other)
        XCTAssertTrue(form.problems(names: [:], now: now).contains { $0.field == "activity.title" })
        form.customTitle = "Poetry afternoon"
        XCTAssertFalse(form.problems(names: [:], now: now).contains { $0.field == "activity.title" })
        XCTAssertEqual(form.title, "Poetry afternoon")
    }

    func testAttendeesWithoutALineAreNamedInTheMessage() {
        let form = draft(responses: [.enjoyed, nil, nil])
        let names = Dictionary(uniqueKeysWithValues: residents.map { ($0.id, $0.displayName) })
        let message = form.problems(names: names, now: now).first { $0.field == "activity.responses" }?.message
        XCTAssertEqual(message, "Note how \(residents[1].displayName) and \(residents[2].displayName) got on.")
    }

    func testAFutureStartAndMarkupInTheNoteAreRefused() {
        var form = draft()
        form.date = now.addingTimeInterval(3_600)
        form.note = "<script>"
        let fields = form.problems(names: [:], now: now).map(\.field)
        XCTAssertTrue(fields.contains("activity.when"))
        XCTAssertTrue(fields.contains("activity.note"))
    }

    func testACompleteFormHasNoProblems() {
        XCTAssertTrue(draft().problems(names: [:], now: now).isEmpty)
    }

    // MARK: The record

    func testTheRecordCarriesTheLogAndNoPlaylist() throws {
        var form = draft()
        form.durationMinutes = 60
        form.note = "  Lovely afternoon  "
        let home = UUID(), author = UUID()
        let record = try XCTUnwrap(GroupSessionRecord(loggedActivity: form, homeId: home, authorAccountId: author))
        XCTAssertEqual(record.kind, .otherActivity)
        XCTAssertFalse(record.isMusic)
        XCTAssertEqual(record.activityCategory, "gamesAndQuizzes")
        XCTAssertEqual(record.displayTitle, "Games & quizzes")
        XCTAssertEqual(record.durationSeconds, 3_600)
        XCTAssertEqual(record.participantIds, form.attendeeIds)
        XCTAssertEqual(record.participantNote(for: residents[0].id), .enjoyed)
        XCTAssertEqual(record.engagementRating, 7)
        XCTAssertEqual(record.staffNote, "Lovely afternoon")
        XCTAssertEqual(record.tracksPlayed, 0)
        XCTAssertTrue(record.playlistSnapshot.isEmpty)
        XCTAssertNil(record.moraleRating)
        XCTAssertEqual(record.homeId, home)
        XCTAssertEqual(record.authorAccountId, author)
    }

    func testNoRecordWithoutAKind() {
        XCTAssertNil(GroupSessionRecord(loggedActivity: draft(kind: nil), homeId: nil, authorAccountId: nil))
    }

    func testTheRecordSurvivesTheWireAndOlderRecordsStayMusic() throws {
        let record = try XCTUnwrap(GroupSessionRecord(loggedActivity: draft(), homeId: nil, authorAccountId: nil))
        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(GroupSessionRecord.self, from: data), record)

        // A record written before activities could be logged has neither field.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["kind"] = nil
        object["activityCategory"] = nil
        let old = try JSONDecoder().decode(GroupSessionRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(old.isMusic)
        XCTAssertNil(old.otherActivityKind)
    }

    // MARK: What reads group history

    private func logged(_ daysAgo: Int, responses: [GroupParticipantState?]) throws -> GroupSessionRecord {
        var form = draft(responses: responses)
        form.date = now.addingTimeInterval(-Double(daysAgo) * 86_400 - 3_600)
        return try XCTUnwrap(GroupSessionRecord(loggedActivity: form, homeId: nil, authorAccountId: nil))
    }

    func testTheProfileLineCountsAnActivityAndSaysHowTheyWere() throws {
        let record = try logged(2, responses: [.enjoyed, .engaged, .lookedOn])
        let summary = GroupActivityReadModels.participation(for: residents[0].id, groupRecords: [record], now: now)
        XCTAssertEqual(summary.count14d, 1)
        XCTAssertEqual(summary.lastTitle, "Games & quizzes")
        XCTAssertTrue(summary.line.contains("they enjoyed it"), summary.line)
        let looking = GroupActivityReadModels.participation(for: residents[2].id, groupRecords: [record], now: now)
        XCTAssertTrue(looking.line.contains("they looked on"), looking.line)
    }

    func testTheProgrammeCardSeparatesActivitiesFromMusic() throws {
        let music = GroupSessionRecord(
            id: UUID(), date: now.addingTimeInterval(-86_400), durationSeconds: 1_500, tracksPlayed: 5,
            moraleRating: 8, alertnessRating: 7, lucidityRating: 7, engagementRating: 9, staffNote: nil,
            playlistSnapshot: ["A"], participantIds: residents.map(\.id), activityTitle: "Jazz lounge", theme: .genre(.jazz)
        )
        let programme = GroupActivityReadModels.programme(
            residents: residents, sessionRecords: [], groupRecords: [music, try logged(3, responses: [.enjoyed, .engaged, .lookedOn])], now: now
        )
        XCTAssertEqual(programme.sessions14d, 2)
        XCTAssertEqual(programme.activities14d, 1)
        XCTAssertEqual(programme.activityAttendances14d, 3)
        XCTAssertEqual(programme.activityAverageEngagement, 7)
        // Morale is only ever rated at a music session, so the activity can't dilute it.
        XCTAssertEqual(programme.averageMorale, 8)
        XCTAssertEqual(programme.residentsReached, 3)
    }

    func testAnActivityCountsAsCompanyForThePlanner() throws {
        let record = try logged(1, responses: [.enjoyed, .engaged, .lookedOn])
        let before = GroupActivityPlanner.build(residents: residents, sessionRecords: [], groupRecords: [], now: now)
        let after = GroupActivityPlanner.build(residents: residents, sessionRecords: [], groupRecords: [record], now: now)
        for resident in residents {
            XCTAssertEqual(before.residents.first { $0.id == resident.id }?.groupCount14d, 0)
            XCTAssertEqual(after.residents.first { $0.id == resident.id }?.groupCount14d, 1)
        }
    }

    func testPerPersonScoresUseTheirOwnLineAndPleasantOnesAreNotDifficult() throws {
        let record = try logged(1, responses: [.enjoyed, .lookedOn, .leftEarly])
        let plan = GroupActivityPlanner.build(residents: residents, sessionRecords: [], groupRecords: [record], now: now)
        func engagement(_ index: Int) -> Double? { plan.residents.first { $0.id == residents[index].id }?.averageGroupEngagement }
        XCTAssertEqual(engagement(0), 9)
        XCTAssertEqual(engagement(1), 5)
        XCTAssertEqual(engagement(2), 2)
        XCTAssertFalse(GroupParticipantState.enjoyed.isDifficult)
        XCTAssertFalse(GroupParticipantState.lookedOn.isDifficult)
        XCTAssertTrue(GroupParticipantState.leftEarly.isDifficult)
    }

    func testTheMockHistoryIncludesActivitiesThatReadAsLogged() {
        // Twelve distinct residents in the mock home, cloned from the three mock profiles (their id is a `let`).
        let roster = (0 ..< 12).map { index -> CarePatientProfile in
            let base = CareStaffMockData.initialPatients[index % CareStaffMockData.initialPatients.count]
            var object = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as! [String: Any]
            object["id"] = UUID().uuidString
            object["displayName"] = "Resident \(String(format: "%02d", index))"
            object["homeId"] = CareTenancyMockData.mapleLodgeId.uuidString
            return try! JSONDecoder().decode(CarePatientProfile.self, from: JSONSerialization.data(withJSONObject: object))
        }
        let history = GroupActivityMockData.records(residents: roster, sessionRecords: [], homeId: CareTenancyMockData.mapleLodgeId, now: now)
        let outside = history.filter { !$0.isMusic }
        XCTAssertEqual(outside.count, 2)
        XCTAssertTrue(outside.allSatisfy { $0.participantNotes?.count == $0.participantIds.count && $0.playlistSnapshot.isEmpty })
    }

    // MARK: Correcting and removing

    func testACorrectionReplacesTheEarlierLogEverywhere() throws {
        let original = try logged(2, responses: [.enjoyed, .enjoyed, .enjoyed])
        // Staff reopen it: the form comes back as it was written.
        var form = ActivityLogDraft(editing: original)
        XCTAssertEqual(form.kind, .gamesAndQuizzes)
        XCTAssertEqual(form.attendeeIds, original.participantIds)
        XCTAssertEqual(form.responses[residents[0].id], .enjoyed)
        XCTAssertEqual(form.replacing, original.id)
        // …and one line was wrong.
        form.responses[residents[2].id] = .leftEarly
        let correction = try XCTUnwrap(GroupSessionRecord(loggedActivity: form, homeId: nil, authorAccountId: nil))
        XCTAssertEqual(correction.supersedes, original.id)

        let counted = GroupSessionRecord.current([original, correction])
        XCTAssertEqual(counted.map(\.id), [correction.id])
        let summary = GroupActivityReadModels.participation(for: residents[2].id, groupRecords: [original, correction], now: now)
        XCTAssertEqual(summary.count14d, 1, "the person is counted once, not once per version")
        XCTAssertTrue(summary.line.contains("they left early"), summary.line)
        let programme = GroupActivityReadModels.programme(residents: residents, sessionRecords: [], groupRecords: [original, correction], now: now)
        XCTAssertEqual(programme.activities14d, 1)
        XCTAssertEqual(programme.activityAttendances14d, 3)
    }

    func testRemovingAnActivityTakesItOffTheDashboardsAndKeepsTheHistory() throws {
        let original = try logged(1, responses: [.enjoyed, .engaged, .lookedOn])
        let withdrawal = GroupSessionRecord(withdrawing: original, at: now, homeId: nil, authorAccountId: nil)
        XCTAssertEqual(withdrawal.supersedes, original.id)
        XCTAssertEqual(withdrawal.withdrawn, true)
        XCTAssertTrue(withdrawal.participantIds.isEmpty)
        XCTAssertTrue(GroupSessionRecord.current([original, withdrawal]).isEmpty)

        let programme = GroupActivityReadModels.programme(residents: residents, sessionRecords: [], groupRecords: [original, withdrawal], now: now)
        XCTAssertEqual(programme.activities14d, 0)
        XCTAssertEqual(programme.sessions14d, 0)
        let plan = GroupActivityPlanner.build(residents: residents, sessionRecords: [], groupRecords: [original, withdrawal], now: now)
        XCTAssertEqual(plan.residents.first { $0.id == residents[0].id }?.groupCount14d, 0)
        XCTAssertEqual(GroupActivityReadModels.participation(for: residents[0].id, groupRecords: [original, withdrawal], now: now).count14d, 0)
        // Nothing was deleted from the history: both records are still there to sync.
        XCTAssertEqual([original, withdrawal].count, 2)
    }

    func testOlderAndNewerRecordsDecodeWithoutTheCorrectionFields() throws {
        let record = try logged(1, responses: [.enjoyed, .engaged, .lookedOn])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        object["supersedes"] = nil
        object["withdrawn"] = nil
        let decoded = try JSONDecoder().decode(GroupSessionRecord.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.supersedes)
        XCTAssertNil(decoded.withdrawn)
        XCTAssertEqual(GroupSessionRecord.current([decoded]).count, 1)
    }

    // MARK: Sounds and haptics

    func testSoundsAndHapticsAreOnUnlessSwitchedOff() {
        let defaults = UserDefaults.standard
        let sounds = defaults.object(forKey: FeedbackPreferences.soundsKey)
        let haptics = defaults.object(forKey: FeedbackPreferences.hapticsKey)
        defer {
            defaults.set(sounds, forKey: FeedbackPreferences.soundsKey)
            defaults.set(haptics, forKey: FeedbackPreferences.hapticsKey)
        }
        defaults.removeObject(forKey: FeedbackPreferences.soundsKey)
        defaults.removeObject(forKey: FeedbackPreferences.hapticsKey)
        XCTAssertTrue(FeedbackPreferences.soundsOn)
        XCTAssertTrue(FeedbackPreferences.hapticsOn)
        defaults.set(false, forKey: FeedbackPreferences.soundsKey)
        XCTAssertFalse(FeedbackPreferences.soundsOn)
        XCTAssertTrue(FeedbackPreferences.hapticsOn, "the two switches are independent")
    }

    // MARK: Repeating, and Care at home

    func testRepeatingKeepsTheActivityAndThePeopleButNotHowTheyWere() throws {
        let original = try logged(5, responses: [.enjoyed, .engaged, .lookedOn])
        var form = ActivityLogDraft(repeating: original, now: now)
        XCTAssertEqual(form.kind, original.otherActivityKind)
        XCTAssertEqual(form.attendeeIds, original.participantIds)
        XCTAssertEqual(form.date, now)
        XCTAssertTrue(form.responses.isEmpty, "how they were is the thing that changes")
        XCTAssertNil(form.replacing, "a repeat is a new entry, not a correction")
        XCTAssertTrue(form.isRepeat)
        XCTAssertFalse(form.problems(names: [:], now: now).isEmpty, "it cannot be saved until everyone has a line")
        for id in form.attendeeIds { form.responses[id] = .engaged }
        let again = try XCTUnwrap(GroupSessionRecord(loggedActivity: form, homeId: nil, authorAccountId: nil))
        XCTAssertNil(again.supersedes)
        XCTAssertNotEqual(again.id, original.id)
        XCTAssertEqual(GroupSessionRecord.current([original, again]).count, 2, "both stay on the books")
    }

    func testAOnePersonFormNamesThemInTheMessage() {
        var form = ActivityLogDraft(now: now.addingTimeInterval(-60))
        form.kind = .petVisit
        form.solo = true
        form.attendeeIds = [residents[0].id]
        let names = [residents[0].id: residents[0].displayName]
        XCTAssertEqual(form.problems(names: names, now: now).first?.message, "Say how \(residents[0].displayName) was.")
        form.responses[residents[0].id] = .enjoyed
        XCTAssertTrue(form.problems(names: names, now: now).isEmpty)
    }

    func testCareAtHomeInsightsCountOnlyTheirPersonAndWhatStillCounts() throws {
        let harold = residents[0].id
        func entry(_ daysAgo: Int, _ kind: OtherActivityKind, _ response: GroupParticipantState, id: UUID = UUID()) -> GroupSessionRecord {
            var draft = ActivityLogDraft(now: now.addingTimeInterval(-Double(daysAgo) * 86_400))
            draft.kind = kind
            draft.solo = true
            draft.attendeeIds = [harold]
            draft.responses[harold] = response
            return GroupSessionRecord(loggedActivity: draft, id: id, homeId: nil, authorAccountId: nil)!
        }
        let pets = entry(6, .petVisit, .enjoyed)
        let garden = entry(2, .gardening, .engaged)
        let tooOld = entry(45, .outing, .enjoyed)
        let removed = entry(1, .cooking, .unsettled)
        let someoneElse = try logged(1, responses: [.enjoyed, .engaged, .lookedOn])   // a care home's, with Harold among three
        let withdrawal = GroupSessionRecord(withdrawing: removed, at: now, homeId: nil, authorAccountId: nil)

        let insights = ActivityInsights.build(records: [pets, garden, tooOld, removed, withdrawal], residentId: harold, now: now)
        XCTAssertEqual(insights.count, 2, "the old one is outside the window and the removed one is gone")
        XCTAssertEqual(insights.rows.map(\.title), ["Gardening", "Pet visit"])
        XCTAssertEqual(insights.byResponse[.enjoyed], 1)
        XCTAssertEqual(insights.byResponse[.engaged], 1)
        XCTAssertEqual(insights.averageEngagement, 8)
        XCTAssertTrue(ActivityInsights.build(records: [], residentId: harold, now: now).isEmpty)
        // The same person in a group log counts too — it is still something they did.
        XCTAssertEqual(ActivityInsights.build(records: [pets, someoneElse], residentId: harold, now: now).count, 2)
    }

    func testAHouseholdFileWrittenBeforeActivitiesStillLoads() throws {
        let old = #"{"residents":[],"records":[]}"#.data(using: .utf8)!
        let data = try JSONDecoder().decode(HouseholdCareStore.Data.self, from: old)
        XCTAssertNil(data.activities)
        var withActivities = HouseholdCareStore.Data()
        withActivities.activities = HouseholdCareStore.demoActivities(now: now)
        let round = try JSONDecoder().decode(HouseholdCareStore.Data.self, from: JSONEncoder().encode(withActivities))
        XCTAssertEqual(round.activities?.count, 2)
    }
}
