import Foundation

/// Resident low-text calm-surface session state — the iPad instrument surface a resident
/// interacts with directly, plus telemetry captured until the supervisor handoff.
final class ResidentSurfaceStore: ObservableObject {
    @Published var isResidentSession = false
    @Published var residentSessionGenre: ResidentMusicGenre?
    @Published var residentTraffic: ResidentTrafficMood?
    @Published var residentFace: ResidentFaceMood?
    @Published var residentVoiceLine: String = ""
    /// Short “living playlist” segment index (POC: ~10s × 10 loops).
    @Published var residentLivingLoopIndex: Int = 0
    @Published var residentLivingTickInSegment: Int = 0

    /// Telemetry while the resident uses the instrument surface (until supervisor handoff).
    @Published var residentSurfaceMetrics = ResidentSurfaceSessionMetrics()
    @Published var residentSurfaceFeedbackPending = false
}
