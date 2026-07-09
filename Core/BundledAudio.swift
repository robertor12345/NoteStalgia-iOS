import Foundation

/// Resolves music bundled inside the app (`App/Resources/Music`).
///
/// The mp3s ship with the app so the POC plays entirely offline. Each lookup keeps a
/// remote URL fallback, so if a file is ever missing from the bundle the app still
/// degrades to the previous streamed clip instead of failing silently.
enum BundledAudio {
    /// Base filenames (without extension) of the bundled tracks.
    static let trackExtension = "mp3"

    /// Bundle subdirectories to probe — covers folder-reference and flattened layouts.
    private static let searchSubdirectories: [String?] = [
        "Resources/Music",
        "Music",
        "Resources",
        nil,
    ]

    /// Local bundled URL for a track base name, if present.
    static func url(_ baseName: String) -> URL? {
        for subdirectory in searchSubdirectories {
            if let found = Bundle.main.url(
                forResource: baseName,
                withExtension: trackExtension,
                subdirectory: subdirectory
            ) {
                return found
            }
        }
        return nil
    }

    /// Local bundled URL when available, otherwise the supplied remote fallback.
    static func urlOrRemote(_ baseName: String, fallback: URL) -> URL {
        url(baseName) ?? fallback
    }
}
