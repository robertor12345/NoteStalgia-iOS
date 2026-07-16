import Foundation

/// Interaction telemetry while a resident uses the calm instrument surface.
struct ResidentSurfaceSessionMetrics: Equatable {
    var startedAt: Date?
    var genrePlayCounts: [String: Int] = [:]
    var trackChangeCount: Int = 0
    var immersiveEntryCount: Int = 0
    var comfortFeelsGoodCount: Int = 0
    var comfortTryElseCount: Int = 0
    var comfortImplicitNeutralCount: Int = 0
    /// How many times the resident sun-liked each track title this session (drives playlist bias).
    var trackLikeCounts: [String: Int] = [:]
    /// Track titles the resident cloud-skipped (removed for the rest of the session).
    var skippedTrackTitles: Set<String> = []

    mutating func recordGenrePlay(_ genre: ResidentMusicGenre) {
        let key = genre.accessibilityLabel
        genrePlayCounts[key, default: 0] += 1
    }

    mutating func recordTrackChange() {
        trackChangeCount += 1
    }

    mutating func recordImmersiveEntry() {
        immersiveEntryCount += 1
    }

    mutating func recordComfortChoice(_ choice: ResidentPlaylistComfortChoice) {
        switch choice {
        case .feelsGood: comfortFeelsGoodCount += 1
        case .trySomethingElse: comfortTryElseCount += 1
        case .implicitNeutral: comfortImplicitNeutralCount += 1
        }
    }

    mutating func recordTrackLike(_ title: String) {
        trackLikeCounts[title, default: 0] += 1
        comfortFeelsGoodCount += 1
    }

    mutating func recordTrackSkip(_ title: String) {
        skippedTrackTitles.insert(title)
        comfortTryElseCount += 1
        trackChangeCount += 1
    }

    func likeCount(for title: String) -> Int {
        trackLikeCounts[title, default: 0]
    }

    var durationSeconds: Int? {
        guard let startedAt else { return nil }
        return max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
    }

    var totalGenrePlays: Int {
        genrePlayCounts.values.reduce(0, +)
    }

    var uniqueGenresPlayed: Int {
        genrePlayCounts.count
    }

    func genresPlayedSummary() -> String? {
        guard !genrePlayCounts.isEmpty else { return nil }
        return genrePlayCounts
            .sorted { $0.value > $1.value }
            .map { "\($0.key) ×\($0.value)" }
            .joined(separator: ", ")
    }

    func interactionSummary() -> String? {
        var parts: [String] = []
        if let seconds = durationSeconds {
            let mins = seconds / 60
            let secs = seconds % 60
            if mins > 0 {
                parts.append(String(format: "%dm %ds on surface", mins, secs))
            } else {
                parts.append("\(secs)s on surface")
            }
        }
        if totalGenrePlays > 0 {
            parts.append("\(totalGenrePlays) genre tap\(totalGenrePlays == 1 ? "" : "s")")
        }
        if uniqueGenresPlayed > 0 {
            parts.append("\(uniqueGenresPlayed) genre\(uniqueGenresPlayed == 1 ? "" : "s") explored")
        }
        if trackChangeCount > 0 {
            parts.append("\(trackChangeCount) track change\(trackChangeCount == 1 ? "" : "s")")
        }
        if immersiveEntryCount > 0 {
            parts.append("\(immersiveEntryCount) calm room visit\(immersiveEntryCount == 1 ? "" : "s")")
        }
        let likes = trackLikeCounts.values.reduce(0, +)
        if likes > 0 {
            parts.append("\(likes) liked track\(likes == 1 ? "" : "s")")
        }
        if skippedTrackTitles.isEmpty == false {
            parts.append("\(skippedTrackTitles.count) skipped")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension CareSessionRecord {
    func residentInteractionSummaryLine() -> String? {
        var parts: [String] = []
        if let seconds = sessionDurationSeconds {
            let mins = seconds / 60
            let secs = seconds % 60
            if mins > 0 {
                parts.append(String(format: "%dm %ds", mins, secs))
            } else {
                parts.append("\(secs)s")
            }
        }
        if let genres = residentGenresPlayedSummary, !genres.isEmpty {
            parts.append(genres)
        }
        if let plays = residentGenrePlayCount, plays > 0, residentGenresPlayedSummary == nil {
            parts.append("\(plays) genre tap\(plays == 1 ? "" : "s")")
        }
        if let changes = residentTrackChangeCount, changes > 0 {
            parts.append("\(changes) track change\(changes == 1 ? "" : "s")")
        }
        if let visits = residentImmersiveEntryCount, visits > 0 {
            parts.append("\(visits) calm room visit\(visits == 1 ? "" : "s")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
