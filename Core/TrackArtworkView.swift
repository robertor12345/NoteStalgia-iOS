import SwiftUI
import UIKit

/// Apple cover art for catalogue tracks on *staff-facing* surfaces only (song search rows, the
/// discovery caption). The resident calm surface never shows it: the designer genre glyphs and
/// mood scenes stay the resident's visual. The Worker stores Apple's 600×600 artwork URL with every
/// track; this downsamples each one once to the tile size and keeps it in a small memory cache so
/// list rows never re-decode a full JPEG. No artwork, or a failed fetch, falls back to the genre glyph.
@MainActor
enum TrackArtworkCache {
    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 80
        return cache
    }()
    private static var inFlight: [URL: Task<UIImage?, Never>] = [:]

    static func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    static func image(for url: URL, pixelSize: CGFloat) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        if let task = inFlight[url] { return await task.value }
        let task = Task<UIImage?, Never> {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 12
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse).map({ (200 ..< 300).contains($0.statusCode) }) ?? true,
                  let full = UIImage(data: data)
            else { return nil }
            let side = max(pixelSize, 64)
            return await full.byPreparingThumbnail(ofSize: CGSize(width: side, height: side)) ?? full
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}

/// Rounded artwork tile for a track reference; the genre glyph while loading or when there is none.
struct TrackArtworkView: View {
    let ref: ResidentTrackRef
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 12
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(BrandTheme.creamMid.opacity(0.95))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Image(ref.genre.artworkAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.16)
                    .opacity(0.92)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(BrandTheme.gold.opacity(0.25), lineWidth: 1))
        .animation(.easeOut(duration: 0.25), value: image != nil)
        .task(id: ref.artworkURL) {
            guard let url = ref.artworkURL(side: 200) else { image = nil; return }
            if let hit = TrackArtworkCache.cached(url) { image = hit; return }
            let fetched = await TrackArtworkCache.image(for: url, pixelSize: size * displayScale)
            guard !Task.isCancelled else { return }
            image = fetched
        }
        .accessibilityHidden(true)
    }
}
