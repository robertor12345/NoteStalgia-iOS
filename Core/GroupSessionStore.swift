import Foundation

/// Supervisor-led group session — roster-compiled playlist, playback position, and post-session
/// group feedback. Self-contained aside from reading the roster/records to compile the playlist
/// and returning to the roster phase when it ends (both stay as orchestration on `SessionPOCState`).
final class GroupSessionStore: ObservableObject {
    @Published var groupSessionTracks: [GroupSessionTrack] = []
    @Published var groupSessionTrackIndex: Int = 0
    @Published var groupSessionStartedAt: Date?
    @Published var groupSessionTracksPlayed: Int = 0
    @Published var groupSessionRecords: [GroupSessionRecord] = []
    @Published var groupSessionFeedbackStep: Int = 0
    @Published var groupSessionFeedbackDraft = GroupSessionFeedbackDraft()
    @Published var isGroupSessionActive = false
    /// True from the staff's Start until the room's playlist is ready to show in one piece (the
    /// backend's picks merged in, sleeves fetched) — the group screen shows a loading ring meanwhile.
    @Published var isPreparingGroupPlaylist = false
    /// Changes on every start/cancel so a preparation that finishes late is discarded.
    var groupSessionPreparationID = UUID()
    var groupSessionPlayedTrackIDs: Set<UUID> = []

    // Group activity planner (`GroupActivityPlanner`): staff selection + the chosen activity.
    @Published var plannerSelectedIds: Set<UUID> = []
    @Published var plannerActivityId: String?
    /// The activity the running session was started from (nil = whole-home playlist).
    @Published var plannedActivity: GroupActivityPlan?

    // "Log an activity" (`ActivityLogDraft`): an activity held outside the app, written up afterwards.
    @Published var activityDraft = ActivityLogDraft()
    @Published var activityErrors: [String: String] = [:]
}
