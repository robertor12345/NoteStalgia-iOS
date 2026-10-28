import Combine
import Foundation

/// What the backend recommended for each resident: per-genre surface queues (cached on disk so a
/// profile that was opened once plays the same songs offline) and the current discovery plan.
/// Read by the calm surface at play time; not forwarded to the coordinator's observers.
final class RecommendationStore: ObservableObject {
    @Published var discoveryPlan: DiscoveryPlan?
    private var queues: [UUID: [ResidentMusicGenre: [ResidentTrackRef]]] = [:]
    private var expandedArtists: Set<String> = []

    /// True the first time an artist is seen this launch — callers expand the catalogue once per artist.
    func markArtistExpanded(_ artist: String) -> Bool {
        expandedArtists.insert(artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).inserted
    }

    func queue(for residentId: UUID, genre: ResidentMusicGenre) -> [ResidentTrackRef]? {
        if let cached = queues[residentId]?[genre] { return cached }
        guard let loaded = Self.load(residentId: residentId) else { return nil }
        queues[residentId] = loaded
        return loaded[genre]
    }

    func store(queues incoming: [APIGenreQueue], for residentId: UUID) {
        var byGenre = queues[residentId] ?? Self.load(residentId: residentId) ?? [:]
        for queue in incoming where !queue.refs.isEmpty {
            byGenre[queue.genre] = queue.refs
        }
        queues[residentId] = byGenre
        Self.save(byGenre, residentId: residentId)
    }

    // MARK: - Disk

    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("NoteStalgia/sync/queues", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func load(residentId: UUID) -> [ResidentMusicGenre: [ResidentTrackRef]]? {
        guard let url = directory?.appendingPathComponent("\(residentId.uuidString).json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [ResidentTrackRef]].self, from: data)
        else { return nil }
        var out: [ResidentMusicGenre: [ResidentTrackRef]] = [:]
        for (key, refs) in raw {
            if let genre = ResidentMusicGenre(rawValue: key) { out[genre] = refs }
        }
        return out
    }

    private static func save(_ queues: [ResidentMusicGenre: [ResidentTrackRef]], residentId: UUID) {
        guard let url = directory?.appendingPathComponent("\(residentId.uuidString).json") else { return }
        let raw = Dictionary(uniqueKeysWithValues: queues.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(raw) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
