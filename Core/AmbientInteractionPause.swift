import Foundation

/// Coordinates pausing always-on ambient TimelineViews (sparkles + orb shell) during
/// interaction that needs the full frame budget — typing and scrolling — and while an opaque
/// full-page layer (resident playlist media) completely covers them.
///
/// Pausing freezes the current frame; it does not lower particle count, blur quality, or
/// nebula fidelity. When interaction ends, the 60fps loops resume unchanged.
///
/// Scroll activity and full-page cover are **reference-counted** so overlapping scroll views
/// (or a view that disappears while another is still scrolling) cannot leave ambient stuck
/// paused or resume too early.
enum AmbientInteractionPause {
    static let didChangeNotification = Notification.Name("NoteStalgia.AmbientInteractionPause.didChange")
    static let isPausedKey = "isPaused"

    private static let lock = NSLock()
    private static var scrollActiveCount = 0
    private static var coverActiveCount = 0

    /// True while at least one tracked scroll view is interacting / decelerating.
    static var isScrollActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return scrollActiveCount > 0
    }

    /// Call when a scroll view begins interacting (or transitions to a scrolling phase).
    static func beginScroll() {
        update { scrollActiveCount += 1 }
    }

    /// Call when a scroll view becomes idle, or when a holder is torn down while still active.
    static func endScroll() {
        update { scrollActiveCount = max(0, scrollActiveCount - 1) }
    }

    /// Call once an opaque full-page layer has finished covering the ambient backdrop — nothing
    /// behind it is visible, so there is no reason to keep drawing it.
    static func beginFullPageCover() {
        update { coverActiveCount += 1 }
    }

    /// Call as soon as the covering layer starts to reveal the backdrop again.
    static func endFullPageCover() {
        update { coverActiveCount = max(0, coverActiveCount - 1) }
    }

    private static func update(_ change: () -> Void) {
        lock.lock()
        let wasPaused = scrollActiveCount > 0 || coverActiveCount > 0
        change()
        let isPaused = scrollActiveCount > 0 || coverActiveCount > 0
        lock.unlock()
        guard isPaused != wasPaused else { return }
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: [isPausedKey: isPaused]
        )
    }
}
