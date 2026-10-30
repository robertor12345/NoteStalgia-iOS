import Foundation
import SwiftUI

// MARK: - Activities held outside the app
//
// Not every good afternoon is a playlist. Bingo, a chair-exercise class, a visiting singer, a trip to the garden centre:
// staff log them here afterwards — what it was, when, who came and how each of them was. The result is an ordinary
// `GroupSessionRecord` with `kind == .otherActivity`, so it syncs like any group record and reaches everything that
// reads group history: the profile's participation line, the planner's "no group this fortnight" and per-person
// engagement, and the Home Admin programme card. It has no playlist and no room ratings; the per-person line is the
// record, and the room's engagement is the average of those lines.

/// What kind of activity it was. Saved as `GroupSessionRecord.activityCategory` (the raw value).
enum OtherActivityKind: String, CaseIterable, Identifiable {
    case gamesAndQuizzes
    case exercise
    case artsAndCrafts
    case gardening
    case cooking
    case reminiscence
    case outing
    case entertainer
    case faith
    case petVisit
    case teaAndChat
    /// Free-text name, asked for.
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gamesAndQuizzes: return "Games & quizzes"
        case .exercise: return "Exercise & movement"
        case .artsAndCrafts: return "Arts & crafts"
        case .gardening: return "Gardening"
        case .cooking: return "Cooking & baking"
        case .reminiscence: return "Reminiscence"
        case .outing: return "Outing"
        case .entertainer: return "Visiting entertainer"
        case .faith: return "Faith & reflection"
        case .petVisit: return "Pet visit"
        case .teaAndChat: return "Tea & a chat"
        case .other: return "Something else"
        }
    }

    var systemImage: String {
        switch self {
        case .gamesAndQuizzes: return "puzzlepiece.fill"
        case .exercise: return "figure.mind.and.body"
        case .artsAndCrafts: return "paintpalette"
        case .gardening: return "leaf"
        case .cooking: return "fork.knife"
        case .reminiscence: return "book.closed"
        case .outing: return "bus"
        case .entertainer: return "theatermasks"
        case .faith: return "hands.sparkles"
        case .petVisit: return "pawprint"
        case .teaAndChat: return "cup.and.saucer"
        case .other: return "ellipsis.circle"
        }
    }
}

extension GroupSessionRecord {
    var otherActivityKind: OtherActivityKind? { activityCategory.flatMap(OtherActivityKind.init(rawValue:)) }

    /// What the dashboards and the profile call it: "Bingo night", "Whole-home playlist", "Jazz lounge".
    var displayTitle: String {
        activityTitle ?? (isMusic ? "Whole-home playlist" : (otherActivityKind?.label ?? "Activity"))
    }
}

/// The form behind "Log an activity": everything is typed or tapped here and only becomes a record on Save.
struct ActivityLogDraft: Equatable {
    static let durationChoices = [15, 30, 45, 60, 90, 120]
    static let titleMaxLength = 60
    static let noteMaxLength = 500

    var kind: OtherActivityKind?
    /// Only used for `.other`.
    var customTitle = ""
    var date: Date
    var durationMinutes = 45
    /// In the order they were added.
    var attendeeIds: [UUID] = []
    /// How each attendee was; nothing is assumed, so a missing entry is a gap to fill before saving.
    var responses: [UUID: GroupParticipantState] = [:]
    var note = ""
    /// Set when correcting an earlier log: saving writes a record that supersedes it.
    var replacing: UUID?
    /// One person, no list to pick from: a Care at home account logging for the person it looks after. The attendee is
    /// put in when the form opens, and the form asks only how they were.
    var solo = false
    /// Started from an earlier entry ("Repeat"): same activity and people, nothing said yet about how anyone was.
    var isRepeat = false

    init(now: Date = Date()) {
        date = now
    }

    /// The form started from an earlier entry: what it was and who came, as of now, with nothing yet said about how any of
    /// them were this time (that is the point of doing it again).
    init(repeating record: GroupSessionRecord, now: Date = Date()) {
        self.init(editing: record)
        date = now
        replacing = nil
        responses = [:]
        note = ""
        isRepeat = true
    }

    /// The form pre-filled from a logged activity, for correcting it.
    init(editing record: GroupSessionRecord) {
        date = record.date
        replacing = record.id
        kind = record.otherActivityKind
        if kind == .other { customTitle = record.activityTitle ?? "" }
        durationMinutes = max(5, record.durationSeconds / 60)
        attendeeIds = record.participantIds
        for note in record.participantNotes ?? [] { responses[note.residentId] = note.state }
        note = record.staffNote ?? ""
    }

    /// "Bingo", or what was typed for "Something else".
    var title: String {
        guard let kind else { return "" }
        return kind == .other ? InputRules.tidy(customTitle) : kind.label
    }

    func isAttending(_ id: UUID) -> Bool { attendeeIds.contains(id) }

    mutating func toggleAttendee(_ id: UUID) {
        if let index = attendeeIds.firstIndex(of: id) {
            attendeeIds.remove(at: index)
            responses[id] = nil
        } else {
            attendeeIds.append(id)
        }
    }

    /// Attendees nobody has said how they were yet.
    var unnotedIds: [UUID] { attendeeIds.filter { responses[$0] == nil } }

    /// The room's engagement on the dashboards' 1–10 scale: the mean of the people noted.
    var averageEngagement: Int? {
        let scores = attendeeIds.compactMap { responses[$0]?.engagementScore }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }
}

extension GroupSessionRecord {
    /// A finished log as the record every other part of the app already reads. `nil` until the draft names an activity.
    /// A draft that is correcting an earlier log writes a record that supersedes it.
    init?(loggedActivity draft: ActivityLogDraft, id: UUID = UUID(), homeId: UUID?, authorAccountId: UUID?) {
        guard let kind = draft.kind else { return nil }
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            id: id,
            date: draft.date,
            durationSeconds: draft.durationMinutes * 60,
            tracksPlayed: 0,
            moraleRating: nil,
            alertnessRating: nil,
            lucidityRating: nil,
            engagementRating: draft.averageEngagement,
            staffNote: note.isEmpty ? nil : note,
            playlistSnapshot: [],
            participantIds: draft.attendeeIds,
            activityTitle: draft.title,
            theme: nil,
            homeId: homeId,
            authorAccountId: authorAccountId,
            participantNotes: draft.attendeeIds.compactMap { id in
                draft.responses[id].map { GroupParticipantNote(residentId: id, state: $0) }
            },
            kind: .otherActivity,
            activityCategory: kind.rawValue,
            supersedes: draft.replacing
        )
    }

    /// Takes a logged activity off the dashboards without deleting anything: a record that supersedes it and counts for nothing.
    init(withdrawing record: GroupSessionRecord, at date: Date = Date(), homeId: UUID?, authorAccountId: UUID?) {
        self.init(
            id: UUID(),
            date: date,
            durationSeconds: 0,
            tracksPlayed: 0,
            playlistSnapshot: [],
            participantIds: [],
            activityTitle: record.activityTitle,
            homeId: homeId ?? record.homeId,
            authorAccountId: authorAccountId,
            kind: .otherActivity,
            activityCategory: record.activityCategory,
            supersedes: record.id,
            withdrawn: true
        )
    }
}

// MARK: - What a Care at home page shows

/// The activities logged outside the app for one person over a recent window: how many, how they were, the last few.
/// Pure, so the same numbers can be tested.
struct ActivityInsights: Equatable {
    struct Row: Identifiable, Equatable {
        var id: UUID
        var title: String
        var date: Date
        var response: GroupParticipantState?
        var note: String?
        var category: OtherActivityKind?
    }

    var windowDays: Int
    var count: Int
    var byResponse: [GroupParticipantState: Int]
    var rows: [Row]
    /// Mean of the 1–10 scores of the lines noted (enjoyed 9 … left early 2).
    var averageEngagement: Double?

    var isEmpty: Bool { count == 0 }

    static func build(records: [GroupSessionRecord], residentId: UUID, now: Date = Date(), windowDays: Int = 30, rowLimit: Int = 5) -> ActivityInsights {
        let start = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let mine = GroupSessionRecord.current(records)
            .filter { !$0.isMusic && $0.participantIds.contains(residentId) && $0.date >= start }
            .sorted { $0.date > $1.date }
        var byResponse: [GroupParticipantState: Int] = [:]
        var scores: [Int] = []
        for record in mine {
            if let response = record.participantNote(for: residentId) {
                byResponse[response, default: 0] += 1
                scores.append(response.engagementScore)
            }
        }
        return ActivityInsights(
            windowDays: windowDays,
            count: mine.count,
            byResponse: byResponse,
            rows: mine.prefix(rowLimit).map {
                Row(id: $0.id, title: $0.displayTitle, date: $0.date, response: $0.participantNote(for: residentId), note: $0.staffNote, category: $0.otherActivityKind)
            },
            averageEngagement: scores.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(scores.count)
        )
    }
}

extension GroupParticipantState {
    /// The status colour that goes with a line (always shown beside its icon and word, never alone).
    var brandTint: Color {
        switch self {
        case .enjoyed: return BrandTheme.statusPositive
        case .engaged: return BrandTheme.logoCyan
        case .lookedOn: return BrandTheme.logoLavenderBlue
        case .unsettled: return BrandTheme.statusAttention
        case .leftEarly: return BrandTheme.statusCaution
        }
    }
}
