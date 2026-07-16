import CryptoKit
import Foundation

/// Disk cache + background prefetch for streamed ambient / discovery audio.
enum StreamAudioCache {
    private static let cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("StreamAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let coordinator = PrefetchCoordinator()
    private static let minimumValidBytes = 4096

    /// Local file when cached and valid, otherwise the original remote URL.
    static func playbackURL(for remote: URL) -> URL {
        guard !remote.isFileURL else { return remote }
        let local = cachedFileURL(for: remote)
        guard isValidCachedFile(at: local) else {
            removeCachedFile(at: local)
            return remote
        }
        return local
    }

    static func isCached(_ remote: URL) -> Bool {
        guard !remote.isFileURL else { return true }
        return isValidCachedFile(at: cachedFileURL(for: remote))
    }

    static func invalidate(_ remote: URL) {
        guard !remote.isFileURL else { return }
        removeCachedFile(at: cachedFileURL(for: remote))
    }

    /// Prefetch without blocking callers.
    static func prefetch(_ urls: [URL]) {
        let remotes = urls.filter { !$0.isFileURL && !isCached($0) }
        guard !remotes.isEmpty else { return }
        Task { await coordinator.prefetch(remotes) }
    }

    static func prefetch(_ url: URL) {
        prefetch([url])
    }

    /// Primary ambient loop only — avoids saturating the network at launch.
    static func prefetchLaunchEssentials() {
        prefetch(AmbientAudioSession.quickStartStreamURL)
    }

    /// Ambient loops + discovery clips — use once the user reaches roster / welcome.
    /// Also warms mood scene stills so song visuals paint from cache on first play.
    static func prefetchWarmCatalog() {
        prefetch(ambientPlaybackURLs + DiscoveryFlowPOC.snippetAudioStreamURLs)
        SceneImageCache.prefetchAllMoodScenes()
    }

    static func prefetchDiscovery(order: [Int]) {
        if order.isEmpty {
            prefetch(DiscoveryFlowPOC.snippetAudioStreamURLs)
            return
        }
        let ordered = order.indices.map { idx in
            DiscoveryFlowPOC.snippetAudioStreamURL(snippetIndex: idx, order: order)
        }
        prefetch(ordered)
    }

    /// Prefetch upcoming discovery snippets while a clip is playing.
    static func prefetchDiscoveryUpcoming(from logicalIndex: Int, order: [Int], lookahead: Int = 2) {
        guard !order.isEmpty else { return }
        var urls: [URL] = []
        for offset in 0 ... lookahead {
            let idx = logicalIndex + offset
            guard idx < order.count else { break }
            urls.append(DiscoveryFlowPOC.snippetAudioStreamURL(snippetIndex: idx, order: order))
        }
        prefetch(urls)
    }

    static var ambientPlaybackURLs: [URL] {
        [
            AmbientAudioSession.quickStartStreamURL,
            AmbientAudioSession.photoAnchorStreamURL,
        ]
    }

    fileprivate static func cachedFileURL(for remote: URL) -> URL {
        let digest = SHA256.hash(data: Data(remote.absoluteString.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        // Preserve the real extension (e.g. mp3) so AVPlayer can infer the container/codec.
        let ext = remote.pathExtension.isEmpty ? "mp3" : remote.pathExtension
        return cacheDirectory.appendingPathComponent("\(hash).\(ext)")
    }

    private static func isValidCachedFile(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber
        else { return false }
        return size.intValue >= minimumValidBytes
    }

    private static func removeCachedFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Background downloads (max 2 concurrent)

private actor PrefetchCoordinator {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()

    private var inFlight: [String: Task<URL?, Never>] = [:]
    private var activeDownloadCount = 0
    private var pending: [URL] = []
    private let maxConcurrent = 2

    func prefetch(_ urls: [URL]) {
        for url in urls {
            enqueue(url)
        }
        drainQueue()
    }

    private func enqueue(_ remote: URL) {
        let key = remote.absoluteString
        guard inFlight[key] == nil else { return }
        guard !StreamAudioCache.isCached(remote) else { return }
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
            let local = await download(remote)
            inFlight[key] = nil
            activeDownloadCount = max(0, activeDownloadCount - 1)
            drainQueue()
            return local
        }
    }

    private func download(_ remote: URL) async -> URL? {
        let destination = StreamAudioCache.cachedFileURL(for: remote)
        if StreamAudioCache.isCached(remote) {
            return destination
        }

        do {
            let (tempURL, response) = try await session.download(from: remote)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                try? FileManager.default.removeItem(at: tempURL)
                return nil
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: tempURL.path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            guard size >= 4096 else {
                try? FileManager.default.removeItem(at: tempURL)
                return nil
            }

            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
