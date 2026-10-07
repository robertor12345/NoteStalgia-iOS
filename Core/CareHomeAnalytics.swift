import Foundation

// MARK: - Home admin dashboard models

enum CareHomeImpactTrend: String, Equatable {
    case improving
    case stable
    case declining
    case noData

    var label: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Needs attention"
        case .noData: return "No rated data"
        }
    }
}

struct CareHomeKPICard: Identifiable, Equatable {
    let id: String
    var title: String
    var value: String
    var detail: String
}

struct CareHomeWingImpact: Identifiable, Equatable {
    let id: String
    var wingName: String
    var sessionCount: Int
    var residentsReached: Int
    var averageCalmPercent: Int?
    var averageWellbeing: Double?
    var intensity: Double
}

struct CareHomeResidentImpact: Identifiable, Equatable {
    let id: UUID
    var patientId: UUID
    var displayName: String
    var wingLabel: String
    var roomLabel: String
    var impactLine: String
    var trend: CareHomeImpactTrend
    var lastCalmPercent: Int?
    var wellbeingScore: Double?
    var daysSinceLastSession: Int?
}

struct CareHomeRecentSessionRow: Identifiable, Equatable {
    let id: UUID
    var patientName: String
    var wingLabel: String
    var date: Date
    var calmPercent: Int
    var moodSummary: String
    var wellbeingScore: Double?
    var impactLine: String?
}

struct CareHomeTrendPoint: Identifiable, Equatable {
    let id: String
    var dayLabel: String
    var value: Double?
}

enum CareHomeTrendValueFormat: Equatable {
    case count
    case percent
    case score
}

struct CareHomeTrendAxis: Equatable {
    var title: String
    var minimum: Double
    var maximum: Double
    var tickValues: [Double]
}

struct CareHomeTrendSeries: Identifiable, Equatable {
    let id: String
    var title: String
    var unitLabel: String
    var legendDescription: String
    var valueFormat: CareHomeTrendValueFormat
    var axis: CareHomeTrendAxis
    var points: [CareHomeTrendPoint]
    var latestSummary: String?
}

struct CareHomeDashboardPresentation: Equatable {
    var homeName: String
    var periodLabel: String
    var totalActiveResidents: Int
    var trendSeries: [CareHomeTrendSeries]
    var kpis: [CareHomeKPICard]
    var wingBreakdown: [CareHomeWingImpact]
    var positiveHighlights: [CareHomeResidentImpact]
    var attentionNeeded: [CareHomeResidentImpact]
    var recentSessions: [CareHomeRecentSessionRow]
    var hasSessionData: Bool
}

enum CareHomeAnalytics {
    static let dashboardWindowDays = 14
    static let attentionThresholdDays = 7

    static func buildDashboard(
        home: CareHome?,
        residents: [CarePatientProfile],
        records: [CareSessionRecord],
        now: Date = Date()
    ) -> CareHomeDashboardPresentation {
        let homeName = home?.name ?? "Care home"
        let residentIds = Set(residents.map(\.id))
        let windowStart = now.addingTimeInterval(-Double(dashboardWindowDays) * 86_400)
        let windowRecords = records
            .filter { residentIds.contains($0.patientId) && $0.date >= windowStart }
            .sorted { $0.date > $1.date }

        let residentsWithSessions = Set(windowRecords.map(\.patientId)).count
        let avgCalm = averageCalm(windowRecords)
        let avgWellbeing = averageWellbeing(windowRecords)

        let kpis = [
            CareHomeKPICard(
                id: "sessions",
                title: "Sessions",
                value: "\(windowRecords.count)",
                detail: "Last \(dashboardWindowDays) days"
            ),
            CareHomeKPICard(
                id: "reach",
                title: "Residents reached",
                value: "\(residentsWithSessions)",
                detail: "of \(residents.count) active"
            ),
            CareHomeKPICard(
                id: "calm",
                title: "Avg at ease",
                value: avgCalm.map { "\($0)%" } ?? "—",
                detail: "During session"
            ),
            CareHomeKPICard(
                id: "wellbeing",
                title: "Observed wellbeing",
                value: avgWellbeing.map { String(format: "%.1f/10", $0) } ?? "—",
                detail: "Carer ratings composite"
            ),
        ]

        let wingBreakdown = wingImpacts(home: home, residents: residents, records: windowRecords)
        let impacts = residentImpacts(residents: residents, records: records, home: home, now: now)
        let trendSeries = buildTrendSeries(residents: residents, records: records, now: now)
        let positive = impacts
            .filter { $0.trend == .improving }
            .prefix(6)
        let attention = impacts
            .filter { $0.trend == .declining || ($0.daysSinceLastSession ?? 0) >= attentionThresholdDays }
            .sorted {
                ($0.daysSinceLastSession ?? 999, $0.displayName) >
                ($1.daysSinceLastSession ?? 999, $1.displayName)
            }
            .prefix(8)

        let recent = windowRecords.prefix(10).compactMap { record -> CareHomeRecentSessionRow? in
            guard let resident = residents.first(where: { $0.id == record.patientId }) else { return nil }
            let wing = wingName(home: home, wingId: resident.wingId)
            return CareHomeRecentSessionRow(
                id: record.id,
                patientName: resident.displayName,
                wingLabel: wing,
                date: record.date,
                calmPercent: record.calmPercent,
                moodSummary: record.moodSummary,
                wellbeingScore: sessionImpactScore(record),
                impactLine: sessionImpactLine(for: record, prior: records.filter {
                    $0.patientId == record.patientId && $0.date < record.date
                })
            )
        }

        return CareHomeDashboardPresentation(
            homeName: homeName,
            periodLabel: "Last \(dashboardWindowDays) days",
            totalActiveResidents: residents.count,
            trendSeries: trendSeries,
            kpis: kpis,
            wingBreakdown: wingBreakdown,
            positiveHighlights: Array(positive),
            attentionNeeded: Array(attention),
            recentSessions: recent,
            hasSessionData: !windowRecords.isEmpty
        )
    }

    // MARK: - Private

    private static func buildTrendSeries(
        residents: [CarePatientProfile],
        records: [CareSessionRecord],
        now: Date
    ) -> [CareHomeTrendSeries] {
        let calendar = Calendar.current
        let residentIds = Set(residents.map(\.id))
        let homeRecords = records.filter { residentIds.contains($0.patientId) }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        let dayStarts: [Date] = (0 ..< dashboardWindowDays).reversed().map { offset in
            calendar.startOfDay(for: now.addingTimeInterval(-Double(offset) * 86_400))
        }

        func recordsForDay(_ day: Date) -> [CareSessionRecord] {
            homeRecords.filter { calendar.isDate($0.date, inSameDayAs: day) }
        }

        let sessionPoints: [CareHomeTrendPoint] = dayStarts.map { day in
            let count = recordsForDay(day).count
            return CareHomeTrendPoint(
                id: day.timeIntervalSince1970.description,
                dayLabel: dayFormatter.string(from: day),
                value: count > 0 ? Double(count) : nil
            )
        }

        let calmPoints: [CareHomeTrendPoint] = dayStarts.map { day in
            let dayRecords = recordsForDay(day)
            guard !dayRecords.isEmpty else {
                return CareHomeTrendPoint(id: day.timeIntervalSince1970.description, dayLabel: dayFormatter.string(from: day), value: nil)
            }
            let avg = dayRecords.map(\.calmPercent).reduce(0, +) / dayRecords.count
            return CareHomeTrendPoint(
                id: day.timeIntervalSince1970.description,
                dayLabel: dayFormatter.string(from: day),
                value: Double(avg)
            )
        }

        let wellbeingPoints: [CareHomeTrendPoint] = dayStarts.map { day in
            let scores = recordsForDay(day).compactMap { sessionImpactScore($0) }
            guard !scores.isEmpty else {
                return CareHomeTrendPoint(id: day.timeIntervalSince1970.description, dayLabel: dayFormatter.string(from: day), value: nil)
            }
            let avg = scores.reduce(0, +) / Double(scores.count)
            return CareHomeTrendPoint(
                id: day.timeIntervalSince1970.description,
                dayLabel: dayFormatter.string(from: day),
                value: avg
            )
        }

        let reachPoints: [CareHomeTrendPoint] = dayStarts.map { day in
            let reached = Set(recordsForDay(day).map(\.patientId)).count
            return CareHomeTrendPoint(
                id: day.timeIntervalSince1970.description,
                dayLabel: dayFormatter.string(from: day),
                value: reached > 0 ? Double(reached) : nil
            )
        }

        return [
            makeTrendSeries(
                id: "sessions",
                title: "Sessions",
                unitLabel: "per day",
                legendDescription: "Calm music sessions completed each day",
                valueFormat: .count,
                points: sessionPoints,
                latestSummary: latestTrendSummary(points: sessionPoints, suffix: "sessions")
            ),
            makeTrendSeries(
                id: "reach",
                title: "Residents reached",
                unitLabel: "unique residents / day",
                legendDescription: "Distinct residents with at least one session that day",
                valueFormat: .count,
                points: reachPoints,
                latestSummary: latestTrendSummary(points: reachPoints, suffix: "residents")
            ),
            makeTrendSeries(
                id: "calm",
                title: "Avg at ease",
                unitLabel: "% at ease during session",
                legendDescription: "Average at-ease score across sessions each day",
                valueFormat: .percent,
                points: calmPoints,
                latestSummary: latestCalmSummary(points: calmPoints),
                fixedAxis: CareHomeTrendAxis(title: "% at ease", minimum: 0, maximum: 100, tickValues: [0, 25, 50, 75, 100])
            ),
            makeTrendSeries(
                id: "wellbeing",
                title: "Observed wellbeing",
                unitLabel: "carer rating (out of 10)",
                legendDescription: "Composite wellbeing from post-session carer ratings",
                valueFormat: .score,
                points: wellbeingPoints,
                latestSummary: latestWellbeingSummary(points: wellbeingPoints),
                fixedAxis: CareHomeTrendAxis(title: "Score", minimum: 0, maximum: 10, tickValues: [0, 2.5, 5, 7.5, 10])
            ),
        ]
    }

    private static func makeTrendSeries(
        id: String,
        title: String,
        unitLabel: String,
        legendDescription: String,
        valueFormat: CareHomeTrendValueFormat,
        points: [CareHomeTrendPoint],
        latestSummary: String?,
        fixedAxis: CareHomeTrendAxis? = nil
    ) -> CareHomeTrendSeries {
        let values = points.compactMap(\.value)
        let axis = fixedAxis ?? countAxis(for: id, values: values)
        return CareHomeTrendSeries(
            id: id,
            title: title,
            unitLabel: unitLabel,
            legendDescription: legendDescription,
            valueFormat: valueFormat,
            axis: axis,
            points: points,
            latestSummary: latestSummary
        )
    }

    private static func countAxis(for id: String, values: [Double]) -> CareHomeTrendAxis {
        let title: String
        switch id {
        case "sessions": title = "Sessions"
        case "reach": title = "Residents"
        default: title = "Count"
        }
        let peak = values.max() ?? 0
        let maximum: Double
        if peak <= 1 {
            maximum = 2
        } else if peak <= 4 {
            maximum = ceil(peak)
        } else {
            maximum = ceil(peak / 2) * 2
        }
        let tickStep = maximum <= 4 ? 1.0 : max(1, round(maximum / 4))
        var ticks: [Double] = [0]
        var tick = tickStep
        while tick < maximum {
            ticks.append(tick)
            tick += tickStep
        }
        if ticks.last != maximum {
            ticks.append(maximum)
        }
        return CareHomeTrendAxis(title: title, minimum: 0, maximum: maximum, tickValues: ticks)
    }

    private static func latestTrendSummary(points: [CareHomeTrendPoint], suffix: String) -> String? {
        guard let latest = points.last(where: { $0.value != nil })?.value else { return nil }
        let formatted = latest.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", latest)
            : String(format: "%.1f", latest)
        return "Latest day: \(formatted) \(suffix)"
    }

    private static func latestCalmSummary(points: [CareHomeTrendPoint]) -> String? {
        guard let latest = points.last(where: { $0.value != nil })?.value else { return nil }
        return "Latest day: \(Int(latest.rounded()))% at ease"
    }

    private static func latestWellbeingSummary(points: [CareHomeTrendPoint]) -> String? {
        guard let latest = points.last(where: { $0.value != nil })?.value else { return nil }
        return String(format: "Latest day: %.1f/10", latest)
    }

    private static func wingImpacts(
        home: CareHome?,
        residents: [CarePatientProfile],
        records: [CareSessionRecord]
    ) -> [CareHomeWingImpact] {
        let wings = home?.wings ?? []
        let grouped = Dictionary(grouping: residents, by: \.wingId)
        let maxSessions = max(1, wings.map { wing in
            records.filter { rec in
                grouped[wing.id]?.contains(where: { $0.id == rec.patientId }) == true
            }.count
        }.max() ?? 1)

        return wings.map { wing in
            let wingResidents = grouped[wing.id] ?? []
            let ids = Set(wingResidents.map(\.id))
            let wingRecords = records.filter { ids.contains($0.patientId) }
            let reached = Set(wingRecords.map(\.patientId)).count
            return CareHomeWingImpact(
                id: wing.id,
                wingName: wing.name,
                sessionCount: wingRecords.count,
                residentsReached: reached,
                averageCalmPercent: averageCalm(wingRecords),
                averageWellbeing: averageWellbeing(wingRecords),
                intensity: Double(wingRecords.count) / Double(maxSessions)
            )
        }
        .filter { $0.sessionCount > 0 || grouped[$0.id]?.isEmpty == false }
        .sorted { $0.sessionCount > $1.sessionCount }
    }

    private static func residentImpacts(
        residents: [CarePatientProfile],
        records: [CareSessionRecord],
        home: CareHome?,
        now: Date
    ) -> [CareHomeResidentImpact] {
        residents.map { resident in
            let patientRecords = records
                .filter { $0.patientId == resident.id }
                .sorted { $0.date > $1.date }
            let last = patientRecords.first
            let daysSince = last.map { max(0, Int(now.timeIntervalSince($0.date) / 86_400)) }
            let currentScore = last.flatMap { sessionImpactScore($0) }
            let priorScores = patientRecords.dropFirst().prefix(5).compactMap { sessionImpactScore($0) }
            let trend: CareHomeImpactTrend = {
                guard let currentScore else { return .noData }
                guard !priorScores.isEmpty else { return .stable }
                let avg = priorScores.reduce(0, +) / Double(priorScores.count)
                if currentScore - avg >= 0.5 { return .improving }
                if avg - currentScore >= 0.5 { return .declining }
                return .stable
            }()

            let narrative = last.flatMap { sessionImpactLine(for: $0, prior: Array(patientRecords.dropFirst())) }
            let impactText: String = {
                if let daysSince, daysSince >= attentionThresholdDays {
                    if last == nil { return "No sessions on file yet." }
                    return "Last session \(daysSince) day\(daysSince == 1 ? "" : "s") ago."
                }
                if let line = narrative {
                    return line
                }
                if let calm = last?.calmPercent {
                    return "Last visit \(calm)% at ease."
                }
                return "Awaiting first rated session."
            }()

            return CareHomeResidentImpact(
                id: resident.id,
                patientId: resident.id,
                displayName: resident.displayName,
                wingLabel: wingName(home: home, wingId: resident.wingId),
                roomLabel: resident.roomLabel,
                impactLine: impactText,
                trend: trend,
                lastCalmPercent: last?.calmPercent,
                wellbeingScore: currentScore,
                daysSinceLastSession: daysSince
            )
        }
    }

    private static func sessionImpactLine(for record: CareSessionRecord, prior: [CareSessionRecord]) -> String? {
        guard let current = sessionImpactScore(record) else { return nil }
        let priorScores = prior.prefix(5).compactMap { sessionImpactScore($0) }
        guard !priorScores.isEmpty else { return "First rated session — baseline set." }
        let avg = priorScores.reduce(0, +) / Double(priorScores.count)
        let delta = current - avg
        if abs(delta) < 0.4 {
            return String(format: "In line with recent sessions (%.1f/10).", current)
        }
        if delta > 0 {
            return String(format: "↑ vs recent average (%.1f → usual %.1f/10).", current, avg)
        }
        return String(format: "↓ vs recent average (%.1f → usual %.1f/10).", current, avg)
    }

    static func sessionImpactScore(_ record: CareSessionRecord) -> Double? {
        if let rated = CareSessionInsightBuilder.wellbeingScore(for: record) {
            return rated
        }
        return Double(record.calmPercent) / 10.0
    }

    private static func averageCalm(_ records: [CareSessionRecord]) -> Int? {
        guard !records.isEmpty else { return nil }
        return records.map(\.calmPercent).reduce(0, +) / records.count
    }

    private static func averageWellbeing(_ records: [CareSessionRecord]) -> Double? {
        let scores = records.compactMap { sessionImpactScore($0) }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private static func wingName(home: CareHome?, wingId: String) -> String {
        home?.wings.first { $0.id == wingId }?.name ?? wingId
    }
}
