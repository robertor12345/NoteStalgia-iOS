import Foundation

/// Compact interaction kind for collation / handover summaries.
enum ResidentInteractionKind: String, Equatable {
    case genreTap
    case trackSwipe
    case sunLike
    case cloudSkip
    case trackListen
    case rageBurst
    case staffHandoff
}

struct ResidentInteractionEvent: Equatable {
    var at: Date
    var kind: ResidentInteractionKind
    var genre: String? = nil
    var trackTitle: String? = nil
    var meta: String? = nil
}

/// Interaction telemetry while a resident uses the calm instrument surface.
/// Recorded interactions are collated into summaries and preference weights
/// (intentional likes/dwell raise preference; rage bursts do not).
struct ResidentSurfaceSessionMetrics: Equatable {
    var startedAt: Date?
    /// When staff took the device back. Freezes `durationSeconds`, so time spent on the
    /// post-session form is not counted as resident time on the surface.
    var endedAt: Date?
    var genrePlayCounts: [String: Int] = [:]
    /// Genre taps that were not part of a rage burst — used for favourite-genre preference.
    var intentionalGenrePlayCounts: [String: Int] = [:]
    var trackChangeCount: Int = 0
    var immersiveEntryCount: Int = 0
    var comfortFeelsGoodCount: Int = 0
    var comfortTryElseCount: Int = 0
    var comfortImplicitNeutralCount: Int = 0
    /// Intentional sun-likes per title (rage-mashed sun taps are excluded).
    var trackLikeCounts: [String: Int] = [:]
    /// Track titles the resident cloud-skipped (removed for the rest of the session).
    var skippedTrackTitles: Set<String> = []
    /// Accumulated listen seconds per track title this session.
    var trackListenSeconds: [String: Int] = [:]
    /// Rapid repeated taps on the same control (≥3 within the rage window).
    var rageBurstCount: Int = 0
    var frustratedTapCount: Int = 0

    /// Capped event log for collation (newest last).
    var interactionEvents: [ResidentInteractionEvent] = []
    /// Recent tap timestamps per control key (genre:Jazz, sun:Title, cloud, swipe).
    var controlTapTimestamps: [String: [Date]] = [:]

    var currentTrackTitle: String?
    var currentTrackStartedAt: Date?

    // MARK: - Rage detection

    private static let rageWindowSeconds: TimeInterval = 1.2
    private static let rageTapThreshold = 3
    private static let maxEvents = 200
    private static let maxTimestampsPerControl = 10

    /// Returns `true` when this tap is part of a rage burst (should not drive preference).
    @discardableResult
    mutating func recordControlTap(key: String, at date: Date = Date()) -> Bool {
        var stamps = controlTapTimestamps[key, default: []]
        stamps.append(date)
        if stamps.count > Self.maxTimestampsPerControl {
            stamps = Array(stamps.suffix(Self.maxTimestampsPerControl))
        }
        controlTapTimestamps[key] = stamps

        let recent = stamps.filter { date.timeIntervalSince($0) <= Self.rageWindowSeconds }
        guard recent.count >= Self.rageTapThreshold else { return false }

        rageBurstCount += 1
        frustratedTapCount += 1
        appendEvent(
            ResidentInteractionEvent(
                at: date,
                kind: .rageBurst,
                meta: "\(key)×\(recent.count)"
            )
        )
        return true
    }

    // MARK: - Recorders

    mutating func recordGenrePlay(_ genre: ResidentMusicGenre) {
        let key = genre.accessibilityLabel
        let rage = recordControlTap(key: "genre:\(key)")
        genrePlayCounts[key, default: 0] += 1
        if !rage {
            intentionalGenrePlayCounts[key, default: 0] += 1
        }
        appendEvent(
            ResidentInteractionEvent(
                at: Date(),
                kind: .genreTap,
                genre: key,
                meta: rage ? "frustrated" : nil
            )
        )
    }

    mutating func recordTrackChange(direction: String? = nil) {
        let rage = recordControlTap(key: "swipe")
        trackChangeCount += 1
        appendEvent(
            ResidentInteractionEvent(
                at: Date(),
                kind: .trackSwipe,
                trackTitle: currentTrackTitle,
                meta: [direction, rage ? "frustrated" : nil].compactMap { $0 }.joined(separator: "|").nilIfEmpty
            )
        )
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
        let rage = recordControlTap(key: "sun:\(title)")
        comfortFeelsGoodCount += 1
        // Rage-mashed sun taps are logged but do not raise preference weight.
        if !rage {
            trackLikeCounts[title, default: 0] += 1
        }
        appendEvent(
            ResidentInteractionEvent(
                at: Date(),
                kind: .sunLike,
                trackTitle: title,
                meta: rage ? "frustrated" : nil
            )
        )
    }

    mutating func recordTrackSkip(_ title: String) {
        let rage = recordControlTap(key: "cloud:\(title)")
        skippedTrackTitles.insert(title)
        comfortTryElseCount += 1
        trackChangeCount += 1
        appendEvent(
            ResidentInteractionEvent(
                at: Date(),
                kind: .cloudSkip,
                trackTitle: title,
                meta: rage ? "frustrated" : nil
            )
        )
    }

    mutating func beginTrackListen(title: String) {
        endTrackListen()
        currentTrackTitle = title
        currentTrackStartedAt = Date()
    }

    mutating func endTrackListen() {
        guard let title = currentTrackTitle, let start = currentTrackStartedAt else {
            currentTrackTitle = nil
            currentTrackStartedAt = nil
            return
        }
        let secs = max(0, Int(Date().timeIntervalSince(start).rounded()))
        if secs > 0 {
            trackListenSeconds[title, default: 0] += secs
            appendEvent(
                ResidentInteractionEvent(
                    at: Date(),
                    kind: .trackListen,
                    trackTitle: title,
                    meta: "\(secs)s"
                )
            )
        }
        currentTrackTitle = nil
        currentTrackStartedAt = nil
    }

    mutating func recordStaffHandoff() {
        endTrackListen()
        if endedAt == nil { endedAt = Date() }
        appendEvent(ResidentInteractionEvent(at: Date(), kind: .staffHandoff))
    }

    /// Clears session skips for the given titles so a genre glyph can be restarted after every
    /// track was cloud-skipped (skips still apply for the remainder of the current queue).
    mutating func clearSkippedTracks(matching titles: [String]) {
        guard !titles.isEmpty else { return }
        skippedTrackTitles.subtract(titles)
    }

    // MARK: - Preference helpers

    func likeCount(for title: String) -> Int {
        trackLikeCounts[title, default: 0]
    }

    /// Soft dwell boost for playlist ordering (0…3).
    func dwellPreferenceBoost(for title: String) -> Int {
        min(3, trackListenSeconds[title, default: 0] / 30)
    }

    /// Combined in-session preference score for a catalog title.
    func preferenceScore(for title: String, suggestedBoost: Int) -> Int {
        likeCount(for: title) + suggestedBoost + dwellPreferenceBoost(for: title)
    }

    /// Genre with the strongest intentional (non-rage) exploration this session.
    func preferredGenreLabel() -> String? {
        intentionalGenrePlayCounts
            .filter { $0.value > 0 }
            .max { $0.value < $1.value }
            .map(\.key)
    }

    func likedTracksSummary() -> String? {
        guard !trackLikeCounts.isEmpty else { return nil }
        return trackLikeCounts
            .sorted { $0.value > $1.value }
            .map { "\($0.key) ×\($0.value)" }
            .joined(separator: ", ")
    }

    func skippedTracksSummary() -> String? {
        guard !skippedTrackTitles.isEmpty else { return nil }
        return skippedTrackTitles.sorted().joined(separator: ", ")
    }

    func topDwellTracksSummary(limit: Int = 3) -> String? {
        let ranked = trackListenSeconds
            .filter { $0.value >= 8 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
        guard !ranked.isEmpty else { return nil }
        return ranked.map { "\($0.key) \($0.value)s" }.joined(separator: ", ")
    }

    // MARK: - Totals / summaries

    var durationSeconds: Int? {
        guard let startedAt else { return nil }
        return max(1, Int((endedAt ?? Date()).timeIntervalSince(startedAt).rounded()))
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

    /// Collated live summary for staff feedback / handover.
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
        if let dwell = topDwellTracksSummary() {
            parts.append("listened: \(dwell)")
        }
        if rageBurstCount > 0 {
            parts.append("\(rageBurstCount) rapid-tap burst\(rageBurstCount == 1 ? "" : "s")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Private

    private mutating func appendEvent(_ event: ResidentInteractionEvent) {
        interactionEvents.append(event)
        if interactionEvents.count > Self.maxEvents {
            interactionEvents.removeFirst(interactionEvents.count - Self.maxEvents)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension CareSessionRecord {
    func residentInteractionSummaryLine() -> String? {
        if let collation = residentInteractionCollation, !collation.isEmpty {
            return collation
        }
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
        if let likes = residentLikedTracksSummary, !likes.isEmpty {
            parts.append("liked \(likes)")
        }
        if let skipped = residentSkippedTracksSummary, !skipped.isEmpty {
            parts.append("skipped \(skipped)")
        }
        if let rage = residentRageBurstCount, rage > 0 {
            parts.append("\(rage) rapid-tap burst\(rage == 1 ? "" : "s")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
