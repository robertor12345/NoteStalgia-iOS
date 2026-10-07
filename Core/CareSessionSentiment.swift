import Foundation

/// Supervisor 1–10 ratings captured after a calm session (existing residents).
struct SessionSentimentDraft: Equatable {
    var mood: Int?
    var alertness: Int?
    var emotionalState: Int?
    var lucidity: Int?
    var note: String = ""
}

enum CareSessionSentimentStep: Int, CaseIterable, Identifiable {
    case mood = 0
    case alertness = 1
    case emotionalState = 2
    case lucidity = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .mood: return "Mood / affect"
        case .alertness: return "Alertness"
        case .emotionalState: return "Emotional presentation"
        case .lucidity: return "Orientation & responsiveness"
        }
    }

    var prompt: String {
        switch self {
        case .mood: return "How did their mood and affect appear after the session?"
        case .alertness: return "How alert did they appear (arousal level)?"
        case .emotionalState: return "How would you describe their emotional presentation?"
        case .lucidity: return "How orientated and responsive were they (person, place, interaction)?"
        }
    }

    var lowCaption: String {
        switch self {
        case .mood: return "1 · Low mood / distressed presentation"
        case .alertness: return "1 · Very drowsy / reduced arousal"
        case .emotionalState: return "1 · Distressed / blunted affect"
        case .lucidity: return "1 · Disorientated / minimally responsive"
        }
    }

    var highCaption: String {
        switch self {
        case .mood: return "10 · Settled / positive affect"
        case .alertness: return "10 · Fully alert"
        case .emotionalState: return "10 · Calm / regulated presentation"
        case .lucidity: return "10 · Orientated / appropriately responsive"
        }
    }
}

struct CareSessionSentimentSummary: Equatable {
    let sessionCount: Int
    let averageMood: Double?
    let averageAlertness: Double?
    let averageEmotionalState: Double?
    let averageLucidity: Double?

    var hasData: Bool {
        sessionCount > 0 && (averageMood != nil || averageAlertness != nil || averageEmotionalState != nil || averageLucidity != nil)
    }

    func formattedAveragesLine() -> String? {
        guard hasData else { return nil }
        var parts: [String] = []
        if let v = averageMood { parts.append(String(format: "Mood/affect %.1f", v)) }
        if let v = averageAlertness { parts.append(String(format: "Alertness %.1f", v)) }
        if let v = averageEmotionalState { parts.append(String(format: "Emotional presentation %.1f", v)) }
        if let v = averageLucidity { parts.append(String(format: "Orientation %.1f", v)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum CareSessionSentimentAnalytics {
    static func summary(for records: [CareSessionRecord]) -> CareSessionSentimentSummary {
        let rated = records.filter {
            $0.moodRating != nil || $0.alertnessRating != nil || $0.emotionalStateRating != nil || $0.lucidityRating != nil
        }
        return CareSessionSentimentSummary(
            sessionCount: rated.count,
            averageMood: average(rated.compactMap(\.moodRating)),
            averageAlertness: average(rated.compactMap(\.alertnessRating)),
            averageEmotionalState: average(rated.compactMap(\.emotionalStateRating)),
            averageLucidity: average(rated.compactMap(\.lucidityRating))
        )
    }

    static func homeOverview(for patients: [CarePatientProfile], records: [CareSessionRecord]) -> CareSessionSentimentSummary {
        let ids = Set(patients.map(\.id))
        let relevant = records.filter { ids.contains($0.patientId) }
        return summary(for: relevant)
    }

    private static func average(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }
}

// MARK: - Session context (UK care-floor tags)

enum SessionTimeOfDay: String, CaseIterable, Identifiable, Equatable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    static func inferred(from date: Date = Date()) -> SessionTimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5 ..< 12: return .morning
        case 12 ..< 17: return .afternoon
        case 17 ..< 21: return .evening
        default: return .night
        }
    }
}

enum SessionPriorState: String, CaseIterable, Identifiable, Equatable {
    case agitated
    case withdrawn
    case neutral
    case tired

    var id: String { rawValue }

    var label: String {
        switch self {
        case .agitated: return "Agitated / behaviourally unsettled"
        case .withdrawn: return "Withdrawn / low engagement"
        case .neutral: return "Settled at baseline"
        case .tired: return "Somnolent / fatigued"
        }
    }
}

enum SessionEnvironmentTag: String, CaseIterable, Identifiable, Equatable {
    case lightsDimmed
    case visitorsPresent
    case postMedication
    case postMeal
    case postPersonalCare

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lightsDimmed: return "Lights dimmed"
        case .visitorsPresent: return "Visitors present"
        case .postMedication: return "Following medicines round"
        case .postMeal: return "Following meal"
        case .postPersonalCare: return "Following personal care"
        }
    }
}

/// Quick context captured before or during post-session feedback.
struct SessionContextDraft: Equatable {
    var timeOfDay: SessionTimeOfDay = SessionTimeOfDay.inferred()
    var priorState: SessionPriorState?
    var environmentTags: Set<SessionEnvironmentTag> = []
    var residentLedSession: Bool = true
    var distressOrPRNNearby: Bool = false

    func formattedContextLine() -> String? {
        var parts: [String] = [timeOfDay.label]
        if let priorState { parts.append("Pre-session: \(priorState.label.lowercased())") }
        let tags = environmentTags.sorted { $0.rawValue < $1.rawValue }.map(\.label)
        if !tags.isEmpty { parts.append(tags.joined(separator: ", ")) }
        parts.append(residentLedSession ? "Resident-led" : "Staff-led")
        if distressOrPRNNearby { parts.append("Acute distress or PRN (as-required) medication nearby") }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Generated insight pack

struct CareSessionInsightPack: Equatable {
    let narrative: String
    let deltaLines: [String]
    let suggestedNextStep: String
    let carePlanBullet: String
    let handoverText: String
    let familyText: String
    /// The same facts, broken out for the at-a-glance supervisor layout (the texts above are what gets copied).
    let summary: CareSessionInsightSummary
    /// `handoverText` split into labelled sections for on-screen reading.
    let handoverSections: [CareInsightSection]
}

struct CareInsightSection: Equatable, Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

/// Structured view of one session for the post-session summary screen.
struct CareSessionInsightSummary: Equatable {
    struct Rating: Equatable, Identifiable {
        let label: String
        let value: Int
        var id: String { label }
    }

    struct GenrePlay: Equatable, Identifiable {
        let name: String
        let count: Int
        var id: String { name }
        var genre: ResidentMusicGenre? {
            ResidentMusicGenre.allCases.first { $0.accessibilityLabel.caseInsensitiveCompare(name) == .orderedSame }
        }
    }

    struct TrackListen: Equatable, Identifiable {
        let title: String
        let detail: String?
        var id: String { title }
    }

    enum Trend: Equatable {
        /// No earlier rated session to compare with.
        case firstRated
        case higher(now: Double, usual: Double)
        case steady(now: Double, usual: Double)
        case lower(now: Double, usual: Double)
    }

    let dateText: String
    let durationText: String?
    /// Composite of the carer ratings (needs at least two).
    let wellbeing: Double?
    let trend: Trend?
    /// Secondary trend remarks (mood, duration) — the composite is carried by `trend`.
    let trendNotes: [String]
    let ratings: [Rating]
    let genres: [GenrePlay]
    let liked: [TrackListen]
    let skipped: [String]
    let longestListening: [TrackListen]
    let frustrationBursts: Int
    let calmRoomVisits: Int
    let contextTags: [String]
    let distressOrPRNNearby: Bool
    let note: String?
}

enum CareSessionInsightBuilder {
    private static let ukLocale = Locale(identifier: "en_GB")
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = ukLocale
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func build(
        patient: CarePatientProfile,
        record: CareSessionRecord,
        priorRecords: [CareSessionRecord]
    ) -> CareSessionInsightPack {
        let narrative = buildNarrative(patient: patient, record: record)
        let deltas = buildDeltas(record: record, priorRecords: priorRecords)
        let nextStep = buildNextStep(patient: patient, record: record, priorRecords: priorRecords)
        let carePlan = buildCarePlanBullet(patient: patient, record: record, nextStep: nextStep)
        let handover = buildHandover(
            patient: patient,
            record: record,
            narrative: narrative,
            deltas: deltas,
            nextStep: nextStep
        )
        let family = buildFamilyText(patient: patient, record: record, narrative: narrative)
        return CareSessionInsightPack(
            narrative: narrative,
            deltaLines: deltas,
            suggestedNextStep: nextStep,
            carePlanBullet: carePlan,
            handoverText: handover.text,
            familyText: family,
            summary: buildSummary(record: record, priorRecords: priorRecords, deltas: deltas),
            handoverSections: handover.sections
        )
    }

    static func wellbeingScore(for record: CareSessionRecord) -> Double? {
        let values = [
            record.moodRating,
            record.alertnessRating,
            record.emotionalStateRating,
            record.lucidityRating,
        ].compactMap { $0 }
        guard values.count >= 2 else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func buildNarrative(patient: CarePatientProfile, record: CareSessionRecord) -> String {
        var sentences: [String] = []
        let name = patient.displayName

        if let interaction = record.residentInteractionSummaryLine() {
            sentences.append("\(name) spent \(interaction.lowercased()) during a reminiscence music session.")
        } else if let seconds = record.sessionDurationSeconds, seconds > 0 {
            sentences.append("\(name) participated in a reminiscence music session for \(formatDuration(seconds)).")
        } else {
            sentences.append("\(name) completed a non-pharmacological reminiscence music session.")
        }

        if let genres = record.residentGenresPlayedSummary, !genres.isEmpty {
            sentences.append("Musical stimuli explored: \(genres).")
        }

        if let likes = record.residentLikedTracksSummary, !likes.isEmpty {
            sentences.append("Tracks they appeared to enjoy: \(likes).")
        }
        if let skipped = record.residentSkippedTracksSummary, !skipped.isEmpty {
            sentences.append("Tracks they moved on from: \(skipped).")
        }
        if let dwell = record.residentTopDwellTracksSummary, !dwell.isEmpty {
            sentences.append("Longest listening: \(dwell).")
        }
        if let rage = record.residentRageBurstCount, rage > 0 {
            sentences.append("Rapid repeated taps were noted \(rage) time\(rage == 1 ? "" : "s") (treated as frustration, not preference).")
        }

        if let visits = record.residentImmersiveEntryCount, visits > 0 {
            sentences.append("They accessed therapeutic nature visuals \(visits) time\(visits == 1 ? "" : "s").")
        }

        if let ratings = staffObservedPhrase(record) {
            sentences.append("Carer observations (1–10): \(ratings).")
        }

        if let context = record.sessionContextSummary, !context.isEmpty {
            sentences.append("Context: \(context).")
        }

        if let note = record.staffNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            sentences.append("Note: \(note)")
        }

        return sentences.joined(separator: " ")
    }

    private static func buildDeltas(record: CareSessionRecord, priorRecords: [CareSessionRecord]) -> [String] {
        guard let current = wellbeingScore(for: record) else {
            return priorRecords.isEmpty
                ? ["First rated session — future visits will show trends."]
                : []
        }

        let priorRated = priorRecords.compactMap { rec -> (CareSessionRecord, Double)? in
            guard let score = wellbeingScore(for: rec) else { return nil }
            return (rec, score)
        }
        guard !priorRated.isEmpty else {
            return ["First rated session — baseline established for future comparison."]
        }

        let recent = priorRated.prefix(5)
        let average = recent.map(\.1).reduce(0, +) / Double(recent.count)
        let delta = current - average
        var lines: [String] = []

        if abs(delta) < 0.4 {
            lines.append("Composite observed wellbeing in line with their last \(recent.count) session\(recent.count == 1 ? "" : "s") (avg \(formatScore(average))/10).")
        } else if delta > 0 {
            lines.append("Composite observed wellbeing ↑ vs recent sessions (now \(formatScore(current))/10; usual avg \(formatScore(average))/10).")
        } else {
            lines.append("Composite observed wellbeing ↓ vs recent sessions (now \(formatScore(current))/10; usual avg \(formatScore(average))/10).")
        }

        if let mood = record.moodRating {
            let priorMoods = priorRecords.compactMap(\.moodRating).prefix(5)
            if !priorMoods.isEmpty {
                let moodAvg = Double(priorMoods.reduce(0, +)) / Double(priorMoods.count)
                lines.append(moodTrendLabel(name: "Mood/affect", current: Double(mood), average: moodAvg))
            }
        }

        if let seconds = record.sessionDurationSeconds {
            let priorDurations = priorRecords.compactMap(\.sessionDurationSeconds).prefix(5)
            if !priorDurations.isEmpty {
                let durAvg = Double(priorDurations.reduce(0, +)) / Double(priorDurations.count)
                if Double(seconds) > durAvg * 1.15 {
                    lines.append("Session duration longer than recent average.")
                } else if Double(seconds) < durAvg * 0.85 {
                    lines.append("Session duration shorter than recent average — consider a briefer intervention next time.")
                }
            }
        }

        return lines
    }

    private static func buildNextStep(
        patient: CarePatientProfile,
        record: CareSessionRecord,
        priorRecords: [CareSessionRecord]
    ) -> String {
        let score = wellbeingScore(for: record)
        let topGenre = record.residentGenresPlayedSummary?
            .split(separator: ",")
            .first?
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ×")
            .first

        if let score, score >= 7.5 {
            var parts = ["Repeat a similar reminiscence music intervention"]
            if let topGenre, !topGenre.isEmpty { parts.append("starting with \(topGenre.lowercased())") }
            if let tod = record.sessionTimeOfDay { parts.append("in the \(tod.lowercased())") }
            if record.lightsDimmed == true { parts.append("with low-stimulus lighting") }
            if let visits = record.residentImmersiveEntryCount, visits > 0 {
                parts.append("and offer therapeutic nature visuals again")
            }
            return parts.joined(separator: " ") + "."
        }

        if let score, score < 5 {
            var parts = ["Offer a shorter intervention (10–12 min)"]
            if patient.prefersGentleSoundOnsets { parts.append("with gradual auditory onsets") }
            if let favourite = favouriteGenreLabel(patient) {
                parts.append("using gentle \(favourite) from their care profile")
            }
            parts.append("and low-stimulus environmental conditions")
            return parts.joined(separator: ", ") + "."
        }

        if let topGenre, !topGenre.isEmpty {
            return "Offer \(topGenre.lowercased()) again at a similar time of day; titrate duration to observed engagement."
        }

        if let favourite = favouriteGenreLabel(patient) {
            return "Try their preferred \(favourite) genre next time, maintaining a low-stimulus care environment."
        }

        return "Continue person-centred reminiscence music; record which genres they initiate or respond to first."
    }

    private static func buildCarePlanBullet(
        patient: CarePatientProfile,
        record: CareSessionRecord,
        nextStep: String
    ) -> String {
        var parts: [String] = ["Reminiscence/music intervention:"]
        if let genres = record.residentGenresPlayedSummary, !genres.isEmpty {
            parts.append("responded to \(genres)")
        } else {
            parts.append("session recorded")
        }
        if let score = wellbeingScore(for: record) {
            parts.append("(carer-observed composite score \(formatScore(score))/10 — not a clinical assessment)")
        }
        parts.append("— \(nextStep)")
        return parts.joined(separator: " ")
    }

    private static func buildHandover(
        patient: CarePatientProfile,
        record: CareSessionRecord,
        narrative: String,
        deltas: [String],
        nextStep: String
    ) -> (text: String, sections: [CareInsightSection]) {
        var facts: [CareInsightSection] = []
        if let interaction = record.residentInteractionSummaryLine() {
            facts.append(CareInsightSection(title: "Intervention", body: "reminiscence music — \(interaction)"))
        }
        if let context = record.sessionContextSummary, !context.isEmpty {
            facts.append(CareInsightSection(title: "Clinical context", body: context))
        }
        if let observed = staffObservedPhrase(record) {
            facts.append(CareInsightSection(title: "Carer observations (1–10)", body: observed))
        }
        if !deltas.isEmpty {
            facts.append(CareInsightSection(title: "Trend vs recent sessions", body: deltas.joined(separator: " ")))
        }
        let narrativeSection = CareInsightSection(title: "Narrative", body: narrative)
        let actionSection = CareInsightSection(title: "Care plan action", body: nextStep)
        let noteSection = record.staffNote?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            .map { CareInsightSection(title: "Carer note", body: $0) }

        func line(_ section: CareInsightSection) -> String { "\(section.title): \(section.body)" }

        var lines: [String] = []
        lines.append("NURSING HANDOVER RECORD — \(patient.displayName)")
        lines.append(dateFormatter.string(from: record.date))
        lines.append("")
        lines.append(contentsOf: facts.map(line))
        lines.append("")
        lines.append(line(narrativeSection))
        lines.append("")
        lines.append(line(actionSection))
        if let noteSection {
            lines.append("")
            lines.append(line(noteSection))
        }
        let sections = facts + [actionSection] + (noteSection.map { [$0] } ?? []) + [narrativeSection]
        return (lines.joined(separator: "\n"), sections)
    }

    private static func buildSummary(
        record: CareSessionRecord,
        priorRecords: [CareSessionRecord],
        deltas: [String]
    ) -> CareSessionInsightSummary {
        let current = wellbeingScore(for: record)
        let priorScores = priorRecords.compactMap(wellbeingScore(for:)).prefix(5)
        var trend: CareSessionInsightSummary.Trend?
        var trendNotes = deltas
        if let current {
            if priorScores.isEmpty {
                trend = .firstRated
                trendNotes = []
            } else {
                let usual = priorScores.reduce(0, +) / Double(priorScores.count)
                let delta = current - usual
                trend = abs(delta) < 0.4 ? .steady(now: current, usual: usual)
                    : delta > 0 ? .higher(now: current, usual: usual)
                    : .lower(now: current, usual: usual)
                trendNotes = Array(deltas.dropFirst())
            }
        } else if priorRecords.isEmpty {
            trend = .firstRated
            trendNotes = []
        }

        let ratings: [CareSessionInsightSummary.Rating] = [
            ("Mood / affect", record.moodRating),
            ("Emotional presentation", record.emotionalStateRating),
            ("Alertness", record.alertnessRating),
            ("Orientation & responsiveness", record.lucidityRating),
        ].compactMap { label, value in value.map { .init(label: label, value: $0) } }

        let genres = splitList(record.residentGenresPlayedSummary).map { item -> CareSessionInsightSummary.GenrePlay in
            let (name, count) = splitCount(item)
            return .init(name: name, count: count ?? 1)
        }
        let liked = splitList(record.residentLikedTracksSummary).map { item -> CareSessionInsightSummary.TrackListen in
            let (title, count) = splitCount(item)
            return .init(title: title, detail: (count ?? 1) > 1 ? "×\(count!)" : nil)
        }
        let longest = splitList(record.residentTopDwellTracksSummary).map { item -> CareSessionInsightSummary.TrackListen in
            // "Title 47s" — the listening time is the last word.
            guard let space = item.lastIndex(of: " "), item.hasSuffix("s"),
                  let seconds = Int(item[item.index(after: space)...].dropLast())
            else { return .init(title: item, detail: nil) }
            return .init(title: String(item[..<space]), detail: formatDuration(seconds))
        }

        // "Afternoon · Following meal, Lights dimmed · Resident-led" → one chip per fact.
        let contextTags = (record.sessionContextSummary ?? "")
            .components(separatedBy: " · ")
            .flatMap { $0.components(separatedBy: ", ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Acute distress") }

        return CareSessionInsightSummary(
            dateText: dateFormatter.string(from: record.date),
            durationText: record.sessionDurationSeconds.flatMap { $0 > 0 ? formatDuration($0) : nil },
            wellbeing: current,
            trend: trend,
            trendNotes: trendNotes,
            ratings: ratings,
            genres: genres,
            liked: liked,
            skipped: splitList(record.residentSkippedTracksSummary),
            longestListening: longest,
            frustrationBursts: record.residentRageBurstCount ?? 0,
            calmRoomVisits: record.residentImmersiveEntryCount ?? 0,
            contextTags: contextTags,
            distressOrPRNNearby: record.distressOrPRNNearby == true,
            note: record.staffNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        )
    }

    private static func splitList(_ summary: String?) -> [String] {
        (summary ?? "")
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// "Jazz ×2" → ("Jazz", 2); "Jazz" → ("Jazz", nil).
    private static func splitCount(_ item: String) -> (String, Int?) {
        let parts = item.components(separatedBy: " ×")
        guard parts.count == 2, let count = Int(parts[1]) else { return (item, nil) }
        return (parts[0], count)
    }

    private static func buildFamilyText(
        patient: CarePatientProfile,
        record: CareSessionRecord,
        narrative: String
    ) -> String {
        let firstName = patient.displayName.split(separator: " ").first.map(String.init) ?? patient.displayName
        var line = "Today \(firstName) took part in a reminiscence music session"
        if let seconds = record.sessionDurationSeconds, seconds >= 60 {
            line += " for about \(max(1, seconds / 60)) minute\(seconds >= 120 ? "s" : "")"
        }
        if let genres = record.residentGenresPlayedSummary?.split(separator: ",").first {
            let genre = String(genres).components(separatedBy: " ×").first ?? String(genres)
            line += ", listening to \(genre.trimmingCharacters(in: .whitespaces).lowercased())"
        }
        if let mood = record.moodRating, mood >= 7 {
            line += ". They appeared settled and content"
        } else if let mood = record.moodRating, mood <= 4 {
            line += ". They appeared more distressed and harder to settle today"
        }
        line += "."
        if let note = record.staffNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            line += " Carer note: \(note)"
        }
        return line
    }

    private static func staffObservedPhrase(_ record: CareSessionRecord) -> String? {
        var parts: [String] = []
        if let v = record.moodRating { parts.append("mood/affect \(v)/10") }
        if let v = record.emotionalStateRating { parts.append("emotional presentation \(v)/10") }
        if let v = record.alertnessRating { parts.append("alertness \(v)/10") }
        if let v = record.lucidityRating { parts.append("orientation-responsiveness \(v)/10") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func moodTrendLabel(name: String, current: Double, average: Double) -> String {
        let delta = current - average
        if abs(delta) < 0.4 { return "\(name) similar to recent sessions." }
        if delta > 0 { return "\(name) higher than recent average." }
        return "\(name) lower than recent average."
    }

    private static func formatScore(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    private static func favouriteGenreLabel(_ patient: CarePatientProfile) -> String? {
        patient.favouriteMusicGenre.accessibilityLabel.lowercased()
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

extension CareSessionRecord {
    /// Narrative only — the history row shows the suggested step on its own "Next:" line.
    func insightPreviewLine() -> String? {
        insightNarrative
    }
}
