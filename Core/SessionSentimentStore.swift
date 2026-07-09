import UIKit

/// Sequential post-session sentiment capture (existing residents).
final class SessionSentimentStore: ObservableObject {
    @Published var sessionSentimentStep: Int = 0
    @Published var sessionSentimentDraft = SessionSentimentDraft()
    @Published var sessionContextDraft = SessionContextDraft()
    @Published var pendingSessionInsight: CareSessionInsightPack?
}

/// Care-session prep choices set before a guided (staff-led) session begins.
final class CareSessionPrepStore: ObservableObject {
    @Published var carePlannedDurationMinutes: Int = 15
    @Published var carePrepVRImmersiveRoute: Bool = false
    @Published var carePrepRoomDisplayMirroring: Bool = false
}

/// Captured photo + mood picks for the (legacy) quick-start flow.
final class CaptureMoodStore: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var selectedMoods: Set<String> = []
}
