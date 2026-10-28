import AVFoundation

/// Single source of truth for the shared `AVAudioSession` lifecycle.
///
/// Both ambient music (`AVPlayer`) and UI chimes (`AVAudioEngine`) route through here so they
/// never fight over category/activation. Activation is idempotent and only re-applies when needed.
///
/// Callable from any thread: `AVAudioSession` is thread-safe and activation takes hundreds of
/// milliseconds on first use, so the launch warm-up runs it off the main thread.
enum AppAudioSession {
    private static let lock = NSLock()
    private static var categoryConfigured = false
    private static var isActive = false

    /// Ensures the session is configured for mixed playback and active. Safe to call repeatedly.
    @discardableResult
    static func activate() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let session = AVAudioSession.sharedInstance()
        do {
            if !categoryConfigured {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                categoryConfigured = true
            }
            if !isActive {
                try session.setActive(true)
                isActive = true
            }
            return true
        } catch {
            // Reset so the next call retries a full configure + activate.
            categoryConfigured = false
            isActive = false
            return false
        }
    }

    /// Marks the session inactive without tearing down playback ownership.
    /// Rarely needed — kept warm by default so UI chimes always work.
    static func deactivate() {
        lock.lock()
        defer { lock.unlock() }
        guard isActive else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isActive = false
    }
}
