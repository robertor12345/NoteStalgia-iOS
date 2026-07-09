import Foundation

/// Immersive-session vitals, replay snapshot, and IoT scene preferences.
///
/// `mockHeartRateCurrent` ticks every 1.2s while an immersive session is open — the one
/// genuinely continuous, high-frequency publish in the whole flow. Views that only need this
/// domain (`ImmersiveSessionView`, `SessionBottomConfigMenu`) observe this store directly
/// instead of the aggregate `SessionPOCState`, so the HR/IoT ticks don't invalidate screens that
/// don't render them.
final class ImmersiveSessionVitalsStore: ObservableObject {
    @Published var mockHeartRateStart: Double = 78
    @Published var mockHeartRateCurrent: Double = 72
    @Published var calmScore: Double = 0.82

    @Published var sessionHomeLightsSyncEnabled = false

    @Published var replayExperienceAvailable = false
    @Published var replayMoodSnapshot: String?
    @Published var replayCalmPercentSnapshot: Int = 0
    @Published var replayHeartRateSnapshot: Int = 72

    @Published var iotPhilipsHueEnabled = false
    @Published var iotHomeKitEnabled = false
    @Published var iotMatterEnabled = false
    @Published var iotFollowSessionBreath = true
    @Published var iotMaxSceneBrightness: Double = 0.88

    @Published var immersiveMediaSessionID = UUID()
    @Published var sessionAnchoredWithPhoto = false
    @Published var replaySnapshotMediaID: UUID?
    @Published var replaySessionPhotoAnchored = false
}
