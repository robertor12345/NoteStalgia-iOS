import Foundation
import UIKit

/// Per-home on-disk mirror of what the backend last sent, so a signed-in home paints instantly
/// (and offline) before the next delta pull. `Application Support/NoteStalgia/sync/homes/<homeId>/`.
enum LocalCache {
    struct HomeSnapshot: Codable {
        var schemaVersion: Int = WireSchema.version
        var cursor: Int = 0
        var residents: [CarePatientProfile] = []
        var sessions: [CareSessionRecord] = []
        var groupSessions: [GroupSessionRecord] = []
        var portraitEtags: [String: String] = [:]
        var lastPulledAt: Date?
    }

    static var root: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("NoteStalgia/sync/homes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func homeDirectory(_ homeId: UUID) -> URL? {
        guard let root else { return nil }
        let dir = root.appendingPathComponent(homeId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("portraits", isDirectory: true), withIntermediateDirectories: true)
        return dir
    }

    static func load(homeId: UUID) -> HomeSnapshot? {
        guard let url = homeDirectory(homeId)?.appendingPathComponent("cache.json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? APIClient.shared.decoder.decode(HomeSnapshot.self, from: data)
    }

    static func save(_ snapshot: HomeSnapshot, homeId: UUID) {
        guard let url = homeDirectory(homeId)?.appendingPathComponent("cache.json"),
              let data = try? APIClient.shared.encoder.encode(snapshot)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func portraitURL(homeId: UUID, residentId: UUID) -> URL? {
        homeDirectory(homeId)?.appendingPathComponent("portraits/\(residentId.uuidString).jpg")
    }

    static func loadPortrait(homeId: UUID, residentId: UUID) -> UIImage? {
        guard let url = portraitURL(homeId: homeId, residentId: residentId),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    static func savePortrait(_ data: Data, homeId: UUID, residentId: UUID) {
        guard let url = portraitURL(homeId: homeId, residentId: residentId) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Demo recordings (`-NoteStalgiaDemoResetHouseholds`) and tests: forget every cached home.
    static func wipe() {
        guard let root else { return }
        try? FileManager.default.removeItem(at: root)
    }
}
