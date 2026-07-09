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
    var groupSessionPlayedTrackIDs: Set<UUID> = []
}
