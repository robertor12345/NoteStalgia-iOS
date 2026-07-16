import Foundation

/// Coordinates pausing always-on ambient TimelineViews (sparkles + orb shell) during
/// interaction that needs the full frame budget — typing and scrolling.
///
/// Pausing freezes the current frame; it does not lower particle count, blur quality, or
/// nebula fidelity. When interaction ends, the 60fps loops resume unchanged.
enum AmbientInteractionPause {
    static let didChangeNotification = Notification.Name("NoteStalgia.AmbientInteractionPause.didChange")
    static let isPausedKey = "isPaused"

    private static let lock = NSLock()
    private static var scrollActive = false

    /// True while any tracked scroll view is interacting / decelerating.
    static var isScrollActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return scrollActive
    }

    static func setScrollActive(_ active: Bool) {
        lock.lock()
        let changed = scrollActive != active
        scrollActive = active
        lock.unlock()
        guard changed else { return }
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: [isPausedKey: active]
        )
    }
}
