import Foundation

/// Where the backend is. Resolved once at launch from the `-NoteStalgiaAPIBaseURL` launch argument
/// (`http://localhost:8787` for `wrangler dev` in the simulator, or a deployed `workers.dev` URL).
/// With no base URL the app runs exactly as before: in-memory demo seed, nothing leaves the device.
enum APIConfig {
    static let launchArgumentKey = "NoteStalgiaAPIBaseURL"

    /// Base URL including the API version path, e.g. `http://localhost:8787/v1`.
    static let baseURL: URL? = {
        guard let raw = UserDefaults.standard.string(forKey: launchArgumentKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            var url = URL(string: raw)
        else { return nil }
        if url.lastPathComponent != "v1" {
            url = url.appendingPathComponent("v1")
        }
        return url
    }()

    /// True when the app should talk to a backend at all.
    static var isConfigured: Bool { baseURL != nil }
}
