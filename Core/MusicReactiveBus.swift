import SwiftUI

/// Dedicated high-frequency channel for live music levels.
///
/// Audio analysis updates ~24×/sec. Routing that through the global navigation state would
/// re-render the entire flow (including the heavy resident calm surface) on every update and
/// starve its layout. Only the orb shell and the equalizer rings observe this bus, so the
/// rest of the UI is untouched by the rapid updates.
@MainActor
final class MusicReactiveBus: ObservableObject {
    static let shared = MusicReactiveBus()

    @Published private(set) var snapshot: MusicReactiveSnapshot = .idle

    private init() {}

    func publish(_ snapshot: MusicReactiveSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }

    func clear() {
        if snapshot.isActive {
            snapshot = .idle
        }
    }
}
