import Foundation

/// Roster browsing/filtering UI state — which home, search text, wing filter, display mode,
/// pinned/recently-viewed residents, plus the presentation caches that avoid rebuilding the
/// roster/dashboard on every unrelated state change (see `SessionPOCState.rosterPresentation()`).
final class CareRosterUIStore: ObservableObject {
    @Published var currentHomeId: UUID?
    @Published var rosterSearchQuery = ""
    @Published var rosterSelectedWingId: String?
    @Published var rosterBrowsingAllResidents = false

    /// When true, admin welcome shows a manual continue control instead of auto-advancing.
    @Published var careHomeAdminWelcomeIsManual = false
    @Published var rosterDisplayMode: CareRosterDisplayMode = .cards
    @Published var rosterPinnedResidentIds: Set<UUID> = []
    @Published var rosterRecentlyViewedIds: [UUID] = []

    struct DashboardPresentationCacheKey: Equatable {
        var homeId: UUID?
        /// `CareDataStore.dataRevision` — cheap O(1) stand-in for the residents + records arrays.
        var dataRevision: Int
    }
    var dashboardPresentationCache: (key: DashboardPresentationCacheKey, value: CareHomeDashboardPresentation)?
    /// Same key as the dashboard — the home-wide sentiment card only depends on home + data.
    var homeSentimentOverviewCache: (key: DashboardPresentationCacheKey, value: CareSessionSentimentSummary)?

    struct RosterPresentationCacheKey: Equatable {
        var homeId: UUID
        /// `CareDataStore.dataRevision` — cheap O(1) stand-in for the patients + records arrays.
        var dataRevision: Int
        var pinnedIds: Set<UUID>
        var recentlyViewedIds: [UUID]
        var wingId: String?
        var searchQuery: String
        var browsingAll: Bool
    }
    var rosterPresentationCache: (key: RosterPresentationCacheKey, value: CareRosterPresentation)?
}
