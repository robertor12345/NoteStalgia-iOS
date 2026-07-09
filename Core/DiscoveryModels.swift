import Foundation

/// Traffic-light calibrated sentiment **only** for Discovery listening snippets (explicit red / amber / green).
enum DiscoveryTrafficSentiment: Int, CaseIterable, Identifiable {
    /// Red — unpleasant / draining for them.
    case unpleasant = 0
    /// Amber — mixed / unsure.
    case neutral = 1
    /// Green — pleasant / settling for them.
    case pleasant = 2

    var id: Int { rawValue }

    var accessibilitySummary: String {
        switch self {
        case .unpleasant: return "Unpleasant"
        case .neutral: return "Neutral"
        case .pleasant: return "Pleasant"
        }
    }
}

struct DiscoverySnippetResult: Identifiable, Equatable {
    var id: Int { snippetIndex }
    let snippetIndex: Int
    let sentiment: DiscoveryTrafficSentiment
}

enum DiscoveryFlowPOC {
    /// Number of sequential 30s listens — **must match** ``snippetAudioStreamURLs``.
    static var snippetCount: Int { snippetAudioStreamURLs.count }
    static let snippetDurationSeconds: TimeInterval = 30

    /// One **distinct clip** per discovery snippet (indexed `0 ..< snippetCount`).
    ///
    /// Tracks are bundled with the app (`App/Resources/Music`) so discovery calibration runs
    /// offline. Each entry falls back to its previous streamed clip if the bundled file is missing.
    static let snippetAudioStreamURLs: [URL] = [
        BundledAudio.urlOrRemote("Echoes of Yesterday", fallback: URL(string: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Sock%20Hop.mp3")!),
        BundledAudio.urlOrRemote("Velvet Highway", fallback: URL(string: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Malt%20Shop%20Bop.mp3")!),
        BundledAudio.urlOrRemote("Velvet Cadenza", fallback: URL(string: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Vivacity.mp3")!),
        BundledAudio.urlOrRemote("Velvet Afterhours", fallback: URL(string: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Jazz%20Brunch.mp3")!),
        BundledAudio.urlOrRemote("Pine Smoke Drift (1)", fallback: URL(string: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Cool%20Blast.mp3")!),
        BundledAudio.urlOrRemote("Drift Between Rooms", fallback: URL(string: "https://incompetech.com/music/royalty-free/mp3-royaltyfree/Americana.mp3")!),
    ]

    static func snippetAudioStreamURL(snippetIndex: Int, order: [Int]? = nil) -> URL {
        let urls = snippetAudioStreamURLs
        precondition(!urls.isEmpty, "DiscoveryFlowPOC.snippetAudioStreamURLs must not be empty")
        let physical: Int
        if let order, snippetIndex >= 0, snippetIndex < order.count {
            physical = order[snippetIndex]
        } else {
            physical = snippetIndex
        }
        let bounded = physical % urls.count
        return urls[bounded]
    }

    /// Reorders snippets so clips whose era sits closest to the resident’s peak listening years (15–30) play first.
    static func orderedSnippetIndices(forResidentAge age: Int) -> [Int] {
        let count = snippetCount
        guard count > 0 else { return [] }
        let currentYear = Calendar.current.component(.year, from: Date())
        let birthYear = currentYear - max(1, age)
        let peakMidYear = birthYear + 22

        let eraYears: [Int] = (0..<count).map { idx in
            DiscoveryEraMediaCatalog.visual(for: idx).eraYear
        }

        return Array(0..<count).sorted { a, b in
            let distA = abs(eraYears[a] - peakMidYear)
            let distB = abs(eraYears[b] - peakMidYear)
            if distA != distB { return distA < distB }
            return a < b
        }
    }
}
