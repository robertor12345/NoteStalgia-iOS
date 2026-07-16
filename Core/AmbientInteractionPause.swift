import Foundation

/// Coordinates pausing always-on ambient TimelineViews (sparkles + orb shell) during
/// interaction that needs the full frame budget — typing and scrolling.
///
/// Pausing freezes the current frame; it does not lower particle count, blur quality, or
/// nebula fidelity. When interaction ends, the 60fps loops resume unchanged.
///
/// Scroll activity is **reference-counted** so overlapping scroll views (or a view that
/// disappears while another is still scrolling) cannot leave ambient stuck paused or
/// resume too early.
enum AmbientInteractionPause {
    static let didChangeNotification = Notification.Name("NoteStalgia.AmbientInteractionPause.didChange")
    static let isPausedKey = "isPaused"

    private static let lock = NSLock()
    private static var scrollActiveCount = 0

    /// True while at least one tracked scroll view is interacting / decelerating.
    static var isScrollActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return scrollActiveCount > 0
    }

    /// Call when a scroll view begins interacting (or transitions to a scrolling phase).
    static func beginScroll() {
        lock.lock()
        scrollActiveCount += 1
        let becameActive = scrollActiveCount == 1
        lock.unlock()
        guard becameActive else { return }
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: [isPausedKey: true]
        )
    }

    /// Call when a scroll view becomes idle, or when a holder is torn down while still active.
    static func endScroll() {
        lock.lock()
        guard scrollActiveCount > 0 else {
            lock.unlock()
            return
        }
        scrollActiveCount -= 1
        let becameIdle = scrollActiveCount == 0
        lock.unlock()
        guard becameIdle else { return }
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: [isPausedKey: false]
        )
    }
}
