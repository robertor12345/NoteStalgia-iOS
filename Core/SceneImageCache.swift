import CryptoKit
import Foundation
import UIKit

/// Memory + disk cache and background prefetch for mood scene stills shown with songs
/// (resident playlist + discovery). Keeps Wikimedia fidelity — stores original bytes on disk.
enum SceneImageCache {
    private static let cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SceneImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 24
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    private static let coordinator = SceneImagePrefetchCoordinator()
    private static let minimumValidBytes = 2048

    // MARK: - Lookup

    static func isCached(_ remote: URL) -> Bool {
        guard !remote.isFileURL else { return true }
        if memory.object(forKey: remote.absoluteString as NSString) != nil { return true }
        return isValidCachedFile(at: cachedFileURL(for: remote))
    }

    /// Instant memory hit only (no disk I/O) — use for first paint decisions on the main thread.
    static func memoryImage(for remote: URL) -> UIImage? {
        memory.object(forKey: remote.absoluteString as NSString)
    }

    /// Synchronous best-effort: memory, then disk decode. Safe for UI path when already warm.
    static func cachedImage(for remote: URL) -> UIImage? {
        let key = remote.absoluteString as NSString
        if let hit = memory.object(forKey: key) { return hit }
        guard !remote.isFileURL else {
            return UIImage(contentsOfFile: remote.path).map { storeInMemory($0, key: key) }
        }
        let local = cachedFileURL(for: remote)
        guard isValidCachedFile(at: local),
              let data = try? Data(contentsOf: local),
              let image = UIImage(data: data)
        else { return nil }
        return storeInMemory(image, key: key)
    }

    /// Async load — returns a cached image immediately when possible, otherwise downloads.
    static func load(_ remote: URL) async -> UIImage? {
        if let hit = cachedImage(for: remote) { return hit }
        if remote.isFileURL {
            return UIImage(contentsOfFile: remote.path).map {
                storeInMemory($0, key: remote.absoluteString as NSString)
            }
        }
        return await coordinator.load(remote)
    }

    // MARK: - Prefetch

    static func prefetch(_ urls: [URL]) {
        let remotes = urls.filter { !$0.isFileURL && !isCached($0) }
        guard !remotes.isEmpty else { return }
        Task { await coordinator.prefetch(remotes) }
    }

    static func prefetch(_ url: URL) {
        prefetch([url])
    }

    /// Warm every known mood scene still (small finite set) — call with audio warm catalog.
    static func prefetchAllMoodScenes() {
        let urls = MusicVisualMood.allCases.flatMap(\.sceneImageURLs)
        prefetch(urls)
    }

    /// Prefetch discovery posters around the current logical snippet index.
    static func prefetchDiscoveryUpcoming(from logicalIndex: Int, order: [Int], lookahead: Int = 2) {
        guard !order.isEmpty else {
            prefetch(DiscoveryEraMediaCatalog.visuals.map(\.posterImageURL))
            return
        }
        var urls: [URL] = []
        for offset in 0 ... lookahead {
            let idx = logicalIndex + offset
            guard idx < order.count else { break }
            let physical = order[idx]
            urls.append(DiscoveryEraMediaCatalog.visual(for: physical).posterImageURL)
        }
        prefetch(urls)
    }

    /// Prefetch resident playlist scene stills around the active track.
    static func prefetchResidentNeighbors(
        genre: ResidentMusicGenre,
        titles: [String],
        index: Int,
        radius: Int = 1
    ) {
        var urls: [URL] = []
        for offset in -radius ... radius {
            let i = index + offset
            guard titles.indices.contains(i) else { continue }
            if let url = ResidentPlaylistVisualCatalog.sceneImageURL(
                for: genre,
                trackTitle: titles[i],
                trackIndex: i
            ) {
                urls.append(url)
            }
        }
        prefetch(urls)
    }

    // MARK: - Disk helpers (shared with coordinator)

    fileprivate static func cachedFileURL(for remote: URL) -> URL {
        let digest = SHA256.hash(data: Data(remote.absoluteString.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let ext = remote.pathExtension.isEmpty ? "jpg" : remote.pathExtension
        return cacheDirectory.appendingPathComponent("\(hash).\(ext)")
    }

    fileprivate static func isValidCachedFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber
        else { return false }
        return size.intValue >= minimumValidBytes
    }

    @discardableResult
    fileprivate static func storeInMemory(_ image: UIImage, key: NSString) -> UIImage {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        memory.setObject(image, forKey: key, cost: max(cost, 1))
        return image
    }

    fileprivate static func storeDownloadedData(_ data: Data, for remote: URL) -> UIImage? {
        guard data.count >= minimumValidBytes, let image = UIImage(data: data) else { return nil }
        let destination = cachedFileURL(for: remote)
        try? data.write(to: destination, options: .atomic)
        return storeInMemory(image, key: remote.absoluteString as NSString)
    }
}

// MARK: - Background downloads

private actor SceneImagePrefetchCoordinator {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private var activeDownloadCount = 0
    private var pending: [URL] = []
    private let maxConcurrent = 3

    func prefetch(_ urls: [URL]) {
        for url in urls { enqueue(url) }
        drainQueue()
    }

    func load(_ remote: URL) async -> UIImage? {
        if let image = SceneImageCache.cachedImage(for: remote) { return image }
        let key = remote.absoluteString
        if let existing = inFlight[key] {
            return await existing.value
        }
        let task = Task<UIImage?, Never> {
            await download(remote)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        return image
    }

    private func enqueue(_ remote: URL) {
        let key = remote.absoluteString
        guard inFlight[key] == nil else { return }
        guard !SceneImageCache.isCached(remote) else { return }
        guard pending.contains(remote) == false else { return }
        pending.append(remote)
    }

    private func drainQueue() {
        while activeDownloadCount < maxConcurrent, pending.isEmpty == false {
            let next = pending.removeFirst()
            start(next)
        }
    }

    private func start(_ remote: URL) {
        let key = remote.absoluteString
        guard inFlight[key] == nil else { return }
        activeDownloadCount += 1
        inFlight[key] = Task {
            let image = await download(remote)
            inFlight[key] = nil
            activeDownloadCount = max(0, activeDownloadCount - 1)
            drainQueue()
            return image
        }
    }

    private func download(_ remote: URL) async -> UIImage? {
        if let image = SceneImageCache.cachedImage(for: remote) { return image }
        do {
            let (data, response) = try await session.data(from: remote)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                return nil
            }
            return SceneImageCache.storeDownloadedData(data, for: remote)
        } catch {
            return nil
        }
    }
}
