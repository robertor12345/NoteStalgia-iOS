import SwiftUI
import Combine

/// In-memory state for the **care-home one-to-one** session POC (corporate sign-in).
///
/// Storage for each domain (auth, roster, resident surface, discovery, group sessions, session
/// vitals, ...) lives in its own small `ObservableObject` — see `Core/*Store.swift`. This class
/// is the coordinator: it owns those stores, forwards their `objectWillChange` so existing
/// `@ObservedObject var state: SessionPOCState` views keep working unmodified, and holds the
/// cross-domain orchestration (phase transitions, resets, and methods that touch more than one
/// domain at once). Views that only care about one domain (e.g. `ImmersiveSessionView` and
/// session vitals) can observe that store directly instead, to avoid re-rendering on unrelated
/// changes — see `vitals`.
final class SessionPOCState: ObservableObject {
    let auth = SupervisorAuthStore()
    let careData = CareDataStore()
    let rosterUI = CareRosterUIStore()
    let residentSurface = ResidentSurfaceStore()
    let newResidentDiscovery = NewResidentDiscoveryStore()
    let discoveryCalibration = DiscoveryCalibrationStore()
    let sessionSentiment = SessionSentimentStore()
    let carePrep = CareSessionPrepStore()
    let captureMood = CaptureMoodStore()
    let groupSession = GroupSessionStore()
    let vitals = ImmersiveSessionVitalsStore()

    private var storeSubscriptions: [AnyCancellable] = []

    init() {
        // NOTE: `auth` is deliberately NOT forwarded. Its fields change on every sign-in / PIN
        // keystroke, and forwarding would re-render every view observing this coordinator (including
        // `FlowRootView` and its expensive orb/sparkle canvases) on each character. The only views
        // that need live auth updates are the sign-in + PIN-reset UI, which observe `auth` directly.
        // Navigation still works because it is driven by `phase` (published on this coordinator).
        forward(careData)
        forward(rosterUI)
        forward(residentSurface)
        forward(newResidentDiscovery)
        forward(discoveryCalibration)
        forward(sessionSentiment)
        forward(carePrep)
        forward(captureMood)
        forward(groupSession)
        forward(vitals)
    }

    /// Re-publishes a store's `objectWillChange` as this coordinator's own, so existing
    /// `@ObservedObject var state: SessionPOCState` views keep refreshing exactly as before.
    private func forward<Store: ObservableObject>(_ store: Store) where Store.ObjectWillChangePublisher == ObservableObjectPublisher {
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &storeSubscriptions)
    }

    @Published var phase: FlowPhase = .home {
        didSet {
            if phase != oldValue { DemoAudioLog.record("phase", ["phase": "\(phase)"]) }
        }
    }
    @Published private(set) var phaseContentVisible = true
    private var phaseTransitionTask: Task<Void, Never>?

    // MARK: - Supervisor auth (passthrough — storage lives in `auth`)

    var supervisorEmail: String {
        get { auth.supervisorEmail }
        set { auth.supervisorEmail = newValue }
    }
    var supervisorPIN: String {
        get { auth.supervisorPIN }
        set { auth.supervisorPIN = newValue }
    }
    var isSignedIn: Bool {
        get { auth.isSignedIn }
        set { auth.isSignedIn = newValue }
    }
    private(set) var pendingCareRosterAfterSignIn: Bool {
        get { auth.pendingCareRosterAfterSignIn }
        set { auth.pendingCareRosterAfterSignIn = newValue }
    }
    var supervisorSignInError: String? {
        get { auth.supervisorSignInError }
        set { auth.supervisorSignInError = newValue }
    }
    private(set) var signedInSupervisorId: UUID? {
        get { auth.signedInSupervisorId }
        set { auth.signedInSupervisorId = newValue }
    }

    // MARK: - Supervisor PIN reset (POC, passthrough — storage lives in `auth`)

    var supervisorPinResetActive: Bool {
        get { auth.pinResetActive }
        set { auth.pinResetActive = newValue }
    }
    var supervisorPinResetStep: SupervisorPinResetStep {
        get { auth.pinResetStep }
        set { auth.pinResetStep = newValue }
    }
    var supervisorPinResetEmail: String {
        get { auth.pinResetEmail }
        set { auth.pinResetEmail = newValue }
    }
    var supervisorPinResetCode: String {
        get { auth.pinResetCode }
        set { auth.pinResetCode = newValue }
    }
    var supervisorPinResetNewPIN: String {
        get { auth.pinResetNewPIN }
        set { auth.pinResetNewPIN = newValue }
    }
    var supervisorPinResetConfirmPIN: String {
        get { auth.pinResetConfirmPIN }
        set { auth.pinResetConfirmPIN = newValue }
    }
    var supervisorPinResetError: String? {
        get { auth.pinResetError }
        set { auth.pinResetError = newValue }
    }
    var supervisorPinResetSuccessMessage: String? {
        get { auth.pinResetSuccessMessage }
        set { auth.pinResetSuccessMessage = newValue }
    }

    // MARK: - Roster UI (passthrough — storage lives in `rosterUI`)

    var currentHomeId: UUID? {
        get { rosterUI.currentHomeId }
        set { rosterUI.currentHomeId = newValue }
    }
    var rosterSearchQuery: String {
        get { rosterUI.rosterSearchQuery }
        set { rosterUI.rosterSearchQuery = newValue }
    }
    var rosterSelectedWingId: String? {
        get { rosterUI.rosterSelectedWingId }
        set { rosterUI.rosterSelectedWingId = newValue }
    }
    var rosterBrowsingAllResidents: Bool {
        get { rosterUI.rosterBrowsingAllResidents }
        set { rosterUI.rosterBrowsingAllResidents = newValue }
    }
    /// When true, admin welcome shows a manual continue control instead of auto-advancing.
    var careHomeAdminWelcomeIsManual: Bool {
        get { rosterUI.careHomeAdminWelcomeIsManual }
        set { rosterUI.careHomeAdminWelcomeIsManual = newValue }
    }
    var rosterDisplayMode: CareRosterDisplayMode {
        get { rosterUI.rosterDisplayMode }
        set { rosterUI.rosterDisplayMode = newValue }
    }
    private(set) var rosterPinnedResidentIds: Set<UUID> {
        get { rosterUI.rosterPinnedResidentIds }
        set { rosterUI.rosterPinnedResidentIds = newValue }
    }
    private(set) var rosterRecentlyViewedIds: [UUID] {
        get { rosterUI.rosterRecentlyViewedIds }
        set { rosterUI.rosterRecentlyViewedIds = newValue }
    }

    // MARK: - Care data (passthrough — storage lives in `careData`)

    var carePatients: [CarePatientProfile] {
        get { careData.carePatients }
        set { careData.carePatients = newValue }
    }
    var careSessionRecords: [CareSessionRecord] {
        get { careData.careSessionRecords }
        set { careData.careSessionRecords = newValue }
    }
    /// Custom portraits keyed by patient id (captured during profile setup).
    var carePatientPortraitImages: [UUID: UIImage] {
        get { careData.carePatientPortraitImages }
        set { careData.carePatientPortraitImages = newValue }
    }

    @Published var selectedCarePatientId: UUID?
    @Published var activeCarePatientId: UUID?
    @Published var isCareStaffSession: Bool = false

    // MARK: - Care session prep (passthrough — storage lives in `carePrep`)

    var carePlannedDurationMinutes: Int {
        get { carePrep.carePlannedDurationMinutes }
        set { carePrep.carePlannedDurationMinutes = newValue }
    }
    var carePrepVRImmersiveRoute: Bool {
        get { carePrep.carePrepVRImmersiveRoute }
        set { carePrep.carePrepVRImmersiveRoute = newValue }
    }
    var carePrepRoomDisplayMirroring: Bool {
        get { carePrep.carePrepRoomDisplayMirroring }
        set { carePrep.carePrepRoomDisplayMirroring = newValue }
    }

    /// Where `leaveResidentProfileToStaff()` returns after a resident session.
    @Published var residentStaffReturnPhase: FlowPhase = .carePatientList

    /// Staff handoff veil before resident calm surface opens.
    @Published var residentHandoffActive = false

    // MARK: - New-resident discovery (passthrough — storage lives in `newResidentDiscovery`)

    private(set) var newResidentDiscoveryPatientId: UUID? {
        get { newResidentDiscovery.newResidentDiscoveryPatientId }
        set { newResidentDiscovery.newResidentDiscoveryPatientId = newValue }
    }
    var newResidentAgeDraft: String {
        get { newResidentDiscovery.newResidentAgeDraft }
        set { newResidentDiscovery.newResidentAgeDraft = newValue }
    }
    var newResidentNationalityDraft: ResidentNationality {
        get { newResidentDiscovery.newResidentNationalityDraft }
        set { newResidentDiscovery.newResidentNationalityDraft = newValue }
    }
    private(set) var discoverySnippetOrder: [Int] {
        get { newResidentDiscovery.discoverySnippetOrder }
        set { newResidentDiscovery.discoverySnippetOrder = newValue }
    }
    var newResidentProfileNameDraft: String {
        get { newResidentDiscovery.newResidentProfileNameDraft }
        set { newResidentDiscovery.newResidentProfileNameDraft = newValue }
    }
    var newResidentProfileAgeDraft: String {
        get { newResidentDiscovery.newResidentProfileAgeDraft }
        set { newResidentDiscovery.newResidentProfileAgeDraft = newValue }
    }
    var newResidentProfileNationalityDraft: ResidentNationality {
        get { newResidentDiscovery.newResidentProfileNationalityDraft }
        set { newResidentDiscovery.newResidentProfileNationalityDraft = newValue }
    }
    var newResidentProfilePhoto: UIImage? {
        get { newResidentDiscovery.newResidentProfilePhoto }
        set { newResidentDiscovery.newResidentProfilePhoto = newValue }
    }

    // MARK: - Sequential post-session sentiment capture (passthrough — storage lives in `sessionSentiment`)

    var sessionSentimentStep: Int {
        get { sessionSentiment.sessionSentimentStep }
        set { sessionSentiment.sessionSentimentStep = newValue }
    }
    var sessionSentimentDraft: SessionSentimentDraft {
        get { sessionSentiment.sessionSentimentDraft }
        set { sessionSentiment.sessionSentimentDraft = newValue }
    }
    var sessionContextDraft: SessionContextDraft {
        get { sessionSentiment.sessionContextDraft }
        set { sessionSentiment.sessionContextDraft = newValue }
    }
    private(set) var pendingSessionInsight: CareSessionInsightPack? {
        get { sessionSentiment.pendingSessionInsight }
        set { sessionSentiment.pendingSessionInsight = newValue }
    }

    // MARK: - Resident calm surface (passthrough — storage lives in `residentSurface`)

    var isResidentSession: Bool {
        get { residentSurface.isResidentSession }
        set { residentSurface.isResidentSession = newValue }
    }
    var residentSessionGenre: ResidentMusicGenre? {
        get { residentSurface.residentSessionGenre }
        set { residentSurface.residentSessionGenre = newValue }
    }
    var residentTraffic: ResidentTrafficMood? {
        get { residentSurface.residentTraffic }
        set { residentSurface.residentTraffic = newValue }
    }
    var residentFace: ResidentFaceMood? {
        get { residentSurface.residentFace }
        set { residentSurface.residentFace = newValue }
    }
    var residentVoiceLine: String {
        get { residentSurface.residentVoiceLine }
        set { residentSurface.residentVoiceLine = newValue }
    }
    /// Short “living playlist” segment index (POC: ~10s × 10 loops).
    var residentLivingLoopIndex: Int {
        get { residentSurface.residentLivingLoopIndex }
        set { residentSurface.residentLivingLoopIndex = newValue }
    }
    var residentLivingTickInSegment: Int {
        get { residentSurface.residentLivingTickInSegment }
        set { residentSurface.residentLivingTickInSegment = newValue }
    }

    /// Custom portraits + captured image stay near the top for readability of intent.
    var capturedImage: UIImage? {
        get { captureMood.capturedImage }
        set { captureMood.capturedImage = newValue }
    }
    private(set) var selectedMoods: Set<String> {
        get { captureMood.selectedMoods }
        set { captureMood.selectedMoods = newValue }
    }

    /// Telemetry while the resident uses the instrument surface (until supervisor handoff).
    private(set) var residentSurfaceMetrics: ResidentSurfaceSessionMetrics {
        get { residentSurface.residentSurfaceMetrics }
        set { residentSurface.residentSurfaceMetrics = newValue }
    }
    private(set) var residentSurfaceFeedbackPending: Bool {
        get { residentSurface.residentSurfaceFeedbackPending }
        set { residentSurface.residentSurfaceFeedbackPending = newValue }
    }

    // Live audio-reactive levels are published on `MusicReactiveBus` (isolated from navigation
    // state) so the orb + equalizer rings can react at ~24fps without re-rendering the whole flow.

    // MARK: - Group session (passthrough — storage lives in `groupSession`)

    var groupSessionTracks: [GroupSessionTrack] {
        get { groupSession.groupSessionTracks }
        set { groupSession.groupSessionTracks = newValue }
    }
    var groupSessionTrackIndex: Int {
        get { groupSession.groupSessionTrackIndex }
        set { groupSession.groupSessionTrackIndex = newValue }
    }
    private(set) var groupSessionStartedAt: Date? {
        get { groupSession.groupSessionStartedAt }
        set { groupSession.groupSessionStartedAt = newValue }
    }
    private(set) var groupSessionTracksPlayed: Int {
        get { groupSession.groupSessionTracksPlayed }
        set { groupSession.groupSessionTracksPlayed = newValue }
    }
    var groupSessionRecords: [GroupSessionRecord] {
        get { groupSession.groupSessionRecords }
        set { groupSession.groupSessionRecords = newValue }
    }
    var groupSessionFeedbackStep: Int {
        get { groupSession.groupSessionFeedbackStep }
        set { groupSession.groupSessionFeedbackStep = newValue }
    }
    var groupSessionFeedbackDraft: GroupSessionFeedbackDraft {
        get { groupSession.groupSessionFeedbackDraft }
        set { groupSession.groupSessionFeedbackDraft = newValue }
    }
    private(set) var isGroupSessionActive: Bool {
        get { groupSession.isGroupSessionActive }
        set { groupSession.isGroupSessionActive = newValue }
    }

    // MARK: - Discovery calibration (passthrough — storage lives in `discoveryCalibration`)

    private(set) var discoverySnippetIndex: Int {
        get { discoveryCalibration.discoverySnippetIndex }
        set { discoveryCalibration.discoverySnippetIndex = newValue }
    }
    private(set) var discoveryResults: [DiscoverySnippetResult] {
        get { discoveryCalibration.discoveryResults }
        set { discoveryCalibration.discoveryResults = newValue }
    }
    var discoveryPendingPick: DiscoveryTrafficSentiment? {
        get { discoveryCalibration.discoveryPendingPick }
        set { discoveryCalibration.discoveryPendingPick = newValue }
    }

    func portraitImage(for patientId: UUID) -> UIImage? {
        carePatientPortraitImages[patientId]
    }

    /// Maps logical discovery clip index → physical snippet (era / audio).
    func discoveryPhysicalSnippetIndex(logicalIndex: Int) -> Int {
        guard logicalIndex >= 0, logicalIndex < discoverySnippetOrder.count else {
            return max(0, logicalIndex)
        }
        return discoverySnippetOrder[logicalIndex]
    }

    var selectedMoodsOrdered: [String] {
        moodOptions.filter { selectedMoods.contains($0) }
    }

    func replaceSelectedMoods(_ moods: Set<String>) {
        selectedMoods = moods
    }

    func openResidentProfile() {
        guard selectedCarePatientId != nil else { return }
        residentStaffReturnPhase = .carePatientList
        withAnimation(.easeOut(duration: 0.38)) {
            phaseContentVisible = false
        }
        withAnimation(CalmMotion.softFade) {
            residentHandoffActive = true
        }
    }

    /// Resident calm surface after immersive / settling — always restore visibility.
    func returnToResidentProfile() {
        phaseContentVisible = true
        phase = .residentProfile
    }

    /// Defensive: transition tasks can occasionally leave content hidden.
    func reaffirmPhaseContentVisible() {
        guard phaseContentVisible == false else { return }
        phaseContentVisible = true
    }

    func completeResidentHandoffTransition() {
        guard residentHandoffActive, let pid = selectedCarePatientId else { return }
        residentHandoffActive = false
        enterResidentInstrumentSurface(patientId: pid, setPhase: false)
        phase = .residentProfile
        withAnimation(CalmMotion.softFade) {
            phaseContentVisible = true
        }
    }

    /// Fades out current screen content, swaps phase, then fades in — avoids overlapping UI during loads.
    func transitionToPhase(_ newPhase: FlowPhase) {
        guard phase != newPhase else { return }
        phaseTransitionTask?.cancel()
        phaseTransitionTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 0.38)) {
                phaseContentVisible = false
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            phase = newPhase
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(CalmMotion.softFade) {
                phaseContentVisible = true
            }
        }
    }

    func leaveResidentProfileToStaff() {
        var metricsSnapshot = residentSurfaceMetrics
        metricsSnapshot.recordStaffHandoff()
        if let pid = selectedCarePatientId ?? activeCarePatientId {
            applyResidentSessionPreferences(from: metricsSnapshot, patientId: pid)
        }
        clearResidentSessionSurfaceState()

        if newResidentDiscoveryPatientId != nil {
            residentSurfaceMetrics = metricsSnapshot
            prepareNewResidentProfileForm()
            phase = .careNewResidentProfile
            return
        }

        if residentSurfaceFeedbackPending, shouldOfferSessionSentimentFeedback() {
            residentSurfaceMetrics = metricsSnapshot
            beginSessionSentimentFeedback()
            return
        }

        resetResidentSurfaceMetrics()
        phase = residentStaffReturnPhase
    }

    func recordResidentGenrePlay(_ genre: ResidentMusicGenre) {
        residentSurfaceMetrics.recordGenrePlay(genre)
    }

    func recordResidentTrackChange(direction: String? = nil) {
        residentSurfaceMetrics.recordTrackChange(direction: direction)
    }

    func recordResidentImmersiveEntry() {
        residentSurfaceMetrics.recordImmersiveEntry()
    }

    func recordResidentPlaylistComfort(_ choice: ResidentPlaylistComfortChoice) {
        residentSurfaceMetrics.recordComfortChoice(choice)
    }

    /// Sun tap — keep playing and raise this track's preference weight for future playlist ordering.
    func recordResidentTrackLike(_ title: String) {
        residentSurfaceMetrics.recordTrackLike(title)
    }

    /// Cloud tap — skip and remove the track from the session playlist.
    func recordResidentTrackSkip(_ title: String) {
        residentSurfaceMetrics.recordTrackSkip(title)
    }

    /// Begin dwell timing for the audible track (ends the previous track's listen window).
    func noteResidentTrackStarted(_ title: String) {
        residentSurfaceMetrics.beginTrackListen(title: title)
    }

    func noteResidentTrackEnded() {
        residentSurfaceMetrics.endTrackListen()
    }

    /// Ordered remaining titles for a genre: intentional sun-likes, listen dwell, and supervisor
    /// suggested likes float first; session-skipped titles are filtered out.
    ///
    /// When every catalog title for the genre was cloud-skipped this session, those skips are
    /// cleared so re-tapping the glyph can start a fresh queue (not a silent dead end).
    func residentPlaylistTitles(for genre: ResidentMusicGenre) -> [String] {
        let catalog = ResidentPlaybackTrackCatalog.titles(for: genre)
        if !catalog.isEmpty,
           catalog.allSatisfy({ residentSurfaceMetrics.skippedTrackTitles.contains($0) }) {
            residentSurfaceMetrics.clearSkippedTracks(matching: catalog)
        }

        let skipped = residentSurfaceMetrics.skippedTrackTitles
        let suggested = Set(residentSurfacePatient()?.suggestedLikedTrackTitles ?? [])
        let suggestedBoost = 2
        let metrics = residentSurfaceMetrics
        return catalog
            .filter { !skipped.contains($0) }
            .sorted { a, b in
                let scoreA = metrics.preferenceScore(
                    for: a,
                    suggestedBoost: suggested.contains(a) ? suggestedBoost : 0
                )
                let scoreB = metrics.preferenceScore(
                    for: b,
                    suggestedBoost: suggested.contains(b) ? suggestedBoost : 0
                )
                if scoreA != scoreB { return scoreA > scoreB }
                return a < b
            }
    }

    /// Persist durable preference hints from a finished resident surface session.
    /// Rage bursts are recorded for staff but never promote a track or genre.
    func applyResidentSessionPreferences(from metrics: ResidentSurfaceSessionMetrics, patientId: UUID) {
        for (title, count) in metrics.trackLikeCounts where count >= 1 {
            addSuggestedLikedTrack(for: patientId, title: title)
        }

        guard let label = metrics.preferredGenreLabel(),
              let genre = ResidentMusicGenre.allCases.first(where: { $0.accessibilityLabel == label }),
              let intentional = metrics.intentionalGenrePlayCounts[label],
              intentional >= 2
        else { return }

        let secondBest = metrics.intentionalGenrePlayCounts
            .filter { $0.key != label }
            .map(\.value)
            .max() ?? 0
        // Require a clear lead so a single exploratory tap does not flip favourite genre.
        if intentional >= secondBest + 1 {
            setFavouriteGenre(for: patientId, genre: genre)
        }
    }

    /// Patient for the open resident surface — prefers selection, falls back to active session id.
    func residentSurfacePatient() -> CarePatientProfile? {
        carePatient(id: selectedCarePatientId ?? activeCarePatientId)
    }

    func addSuggestedLikedTrack(for patientId: UUID, title: String) {
        guard ResidentPlaybackTrackCatalog.allUniqueTitles.contains(title),
              let i = carePatients.firstIndex(where: { $0.id == patientId })
        else { return }
        var patients = carePatients
        guard !patients[i].suggestedLikedTrackTitles.contains(title) else { return }
        patients[i].suggestedLikedTrackTitles.append(title)
        carePatients = patients
    }

    func removeSuggestedLikedTrack(for patientId: UUID, title: String) {
        guard let i = carePatients.firstIndex(where: { $0.id == patientId }) else { return }
        var patients = carePatients
        patients[i].suggestedLikedTrackTitles.removeAll { $0 == title }
        carePatients = patients
    }

    private func resetResidentSurfaceMetrics() {
        residentSurfaceMetrics = ResidentSurfaceSessionMetrics()
        residentSurfaceFeedbackPending = false
    }

    /// After choosing a genre symbol and playlist, jump into the existing calm-room pipeline.
    func prepareResidentImmersiveFromPlaylist(genre: ResidentMusicGenre) {
        recordResidentImmersiveEntry()
        residentSessionGenre = genre
        if residentTraffic == nil { residentTraffic = .mid }
        if residentFace == nil { residentFace = .neutral }
        beginResidentSessionFromMood()
        phase = .processingFast
    }

    private func enterResidentInstrumentSurface(patientId: UUID, setPhase: Bool = true) {
        isResidentSession = true
        isCareStaffSession = false
        selectedCarePatientId = patientId
        activeCarePatientId = patientId
        residentSessionGenre = nil
        residentTraffic = nil
        residentFace = nil
        residentVoiceLine = ""
        residentLivingLoopIndex = 0
        residentLivingTickInSegment = 0
        capturedImage = nil
        replaceSelectedMoods([])
        residentSurfaceMetrics = ResidentSurfaceSessionMetrics(startedAt: Date())
        residentSurfaceFeedbackPending = true
        if setPhase {
            phaseContentVisible = true
            phase = .residentProfile
        }
    }

    func syncResidentMoodPickToMoods() {
        let t = residentTraffic ?? .mid
        let f = residentFace ?? .neutral
        var moods: Set<String> = []
        switch (t, f) {
        case (.low, .sad): moods = ["Overwhelmed", "Stressed"]
        case (.low, .neutral): moods = ["Anxious", "Tired"]
        case (.low, .happy): moods = ["Tired", "Calm"]
        case (.mid, .sad): moods = ["Down", "Anxious"]
        case (.mid, .neutral): moods = ["Tired"]
        case (.mid, .happy): moods = ["Calm", "Tired"]
        case (.high, .sad): moods = ["Down", "Calm"]
        case (.high, .neutral): moods = ["Calm"]
        case (.high, .happy): moods = ["Calm"]
        }
        replaceSelectedMoods(moods)
    }

    func beginResidentSessionFromMood() {
        syncResidentMoodPickToMoods()
        if selectedMoods.isEmpty { replaceSelectedMoods(["Calm"]) }
        isCareStaffSession = true
        isResidentSession = true
        residentLivingLoopIndex = 0
        residentLivingTickInSegment = 0
        beginSession()
    }

    func setResidentAge(for patientId: UUID, age: Int) {
        guard let i = carePatients.firstIndex(where: { $0.id == patientId }) else { return }
        var patients = carePatients
        patients[i].residentAgeYears = age
        carePatients = patients
    }

    func setResidentNationality(for patientId: UUID, nationality: ResidentNationality) {
        guard let i = carePatients.firstIndex(where: { $0.id == patientId }) else { return }
        var patients = carePatients
        patients[i].nationality = nationality
        carePatients = patients
    }

    func setFavouriteGenre(for patientId: UUID, genre: ResidentMusicGenre) {
        guard let i = carePatients.firstIndex(where: { $0.id == patientId }) else { return }
        var patients = carePatients
        patients[i].favouriteMusicGenre = genre
        carePatients = patients
    }

    func tickLivingPlaylistSegment() {
        residentLivingTickInSegment += 1
        if residentLivingTickInSegment > 9 {
            residentLivingTickInSegment = 0
            residentLivingLoopIndex = min(9, residentLivingLoopIndex + 1)
        }
    }

    func resetLivingPlaylistCounters() {
        residentLivingLoopIndex = 0
        residentLivingTickInSegment = 0
    }

    func toggleMoodSelection(_ mood: String) {
        var next = selectedMoods
        if next.contains(mood) {
            next.remove(mood)
        } else {
            next.insert(mood)
        }
        selectedMoods = next
    }

    func carePatient(id: UUID?) -> CarePatientProfile? {
        guard let id else { return nil }
        return carePatients.first { $0.id == id }
    }

    func recordsForPatient(_ patientId: UUID) -> [CareSessionRecord] {
        careData.records(for: patientId)
    }

    func enterOneToOneCalmFlow() {
        guard isSignedIn else { return }
        pendingCareRosterAfterSignIn = false
        phase = .carePatientList
    }

    func completeSupervisorSignIn() -> String? {
        let result = SupervisorAuth.validate(email: supervisorEmail, pin: supervisorPIN)
        if let error = result.error {
            supervisorSignInError = error
            return error
        }
        guard let account = result.account else {
            supervisorSignInError = "Sign-in failed."
            return supervisorSignInError
        }
        supervisorSignInError = nil
        isSignedIn = true
        signedInSupervisorId = account.id
        pendingCareRosterAfterSignIn = false
        loadRosterPrefs(for: account.id)
        rosterSearchQuery = ""
        rosterSelectedWingId = nil
        rosterBrowsingAllResidents = false
        careHomeAdminWelcomeIsManual = false
        phaseTransitionTask?.cancel()

        if account.homeIds.count == 1, let homeId = account.homeIds.first {
            currentHomeId = homeId
            phase = account.role.isHomeAdmin ? .careHomeAdminWelcome : .supervisorWelcome
        } else {
            currentHomeId = nil
            phase = .careHomePicker
        }
        withAnimation(CalmMotion.softFade) {
            phaseContentVisible = true
        }
        return nil
    }

    func beginSupervisorPinReset() {
        supervisorSignInError = nil
        supervisorPinResetActive = true
        supervisorPinResetStep = .email
        supervisorPinResetEmail = supervisorEmail
        supervisorPinResetCode = ""
        supervisorPinResetNewPIN = ""
        supervisorPinResetConfirmPIN = ""
        supervisorPinResetError = nil
        supervisorPinResetSuccessMessage = nil
        auth.pinResetAccountId = nil
    }

    func cancelSupervisorPinReset() {
        supervisorPinResetActive = false
        supervisorPinResetStep = .email
        supervisorPinResetCode = ""
        supervisorPinResetNewPIN = ""
        supervisorPinResetConfirmPIN = ""
        supervisorPinResetError = nil
        supervisorPinResetSuccessMessage = nil
        auth.pinResetAccountId = nil
    }

    func submitSupervisorPinResetEmail() {
        let result = SupervisorAuth.beginPinReset(email: supervisorPinResetEmail)
        if let error = result.error {
            supervisorPinResetError = error
            return
        }
        guard let accountId = result.accountId else {
            supervisorPinResetError = "No account found for that email."
            return
        }
        supervisorPinResetError = nil
        auth.pinResetAccountId = accountId
        supervisorPinResetStep = .verificationCode
        supervisorPinResetCode = ""
    }

    func submitSupervisorPinResetCode() {
        if let error = SupervisorAuth.verifyPinResetCode(supervisorPinResetCode) {
            supervisorPinResetError = error
            return
        }
        supervisorPinResetError = nil
        supervisorPinResetStep = .newPIN
        supervisorPinResetNewPIN = ""
        supervisorPinResetConfirmPIN = ""
    }

    func submitSupervisorPinResetNewPIN() {
        let sanitized = String(supervisorPinResetNewPIN.filter(\.isWholeNumber).prefix(SupervisorAuth.pinDigitCount))
        supervisorPinResetNewPIN = sanitized
        guard sanitized.count == SupervisorAuth.pinDigitCount else {
            supervisorPinResetError = "Choose a new \(SupervisorAuth.pinDigitCount)-digit PIN."
            return
        }
        supervisorPinResetError = nil
        supervisorPinResetStep = .confirmPIN
        supervisorPinResetConfirmPIN = ""
    }

    func submitSupervisorPinResetConfirm() {
        guard let accountId = auth.pinResetAccountId else {
            supervisorPinResetError = "Reset session expired. Start again."
            supervisorPinResetStep = .email
            return
        }
        if let error = SupervisorAuth.completePinReset(
            accountId: accountId,
            newPIN: supervisorPinResetNewPIN,
            confirmPIN: supervisorPinResetConfirmPIN
        ) {
            supervisorPinResetError = error
            return
        }
        supervisorPinResetError = nil
        supervisorEmail = supervisorPinResetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        supervisorPIN = ""
        supervisorPinResetSuccessMessage = "PIN updated. Sign in with your new PIN."
        supervisorPinResetStep = .complete
    }

    func finishSupervisorPinReset() {
        cancelSupervisorPinReset()
    }

    func currentSupervisorAccount() -> SupervisorAccount? {
        guard let signedInSupervisorId else { return nil }
        return CareTenancyMockData.supervisor(id: signedInSupervisorId)
    }

    func currentHome() -> CareHome? {
        guard let currentHomeId else { return nil }
        return CareTenancyMockData.home(id: currentHomeId)
    }

    func assignedHomes() -> [CareHome] {
        guard let account = currentSupervisorAccount() else { return [] }
        return account.homeIds.compactMap { CareTenancyMockData.home(id: $0) }
    }

    func selectHome(_ homeId: UUID) {
        guard assignedHomes().contains(where: { $0.id == homeId }) else { return }
        currentHomeId = homeId
        rosterSearchQuery = ""
        rosterSelectedWingId = nil
        rosterBrowsingAllResidents = false
        careHomeAdminWelcomeIsManual = false
        let isAdmin = currentSupervisorAccount()?.role.isHomeAdmin == true
        transitionToPhase(isAdmin ? .careHomeAdminWelcome : .supervisorWelcome)
    }

    func returnFromAdminDashboard() {
        careHomeAdminWelcomeIsManual = false
        transitionToPhase(.careHomePicker)
    }

    func openAdminDashboardFromWelcome() {
        careHomeAdminWelcomeIsManual = false
        transitionToPhase(.careHomeAdminDashboard)
    }

    var isCareHomeAdmin: Bool {
        currentSupervisorAccount()?.role.isHomeAdmin == true
    }

    /// `body` re-evaluates this on every unrelated `@Published` change on this state object —
    /// cache the result and only rebuild the (filter/aggregate-heavy) dashboard when the
    /// residents, records, or selected home actually changed.
    func careHomeDashboardPresentation() -> CareHomeDashboardPresentation {
        let key = CareRosterUIStore.DashboardPresentationCacheKey(homeId: currentHomeId, dataRevision: careData.dataRevision)
        if let cache = rosterUI.dashboardPresentationCache, cache.key == key {
            return cache.value
        }
        let value = CareHomeAnalytics.buildDashboard(
            home: currentHome(),
            residents: residentsInCurrentHome(),
            records: careSessionRecords
        )
        rosterUI.dashboardPresentationCache = (key, value)
        return value
    }

    func switchHome() {
        guard let account = currentSupervisorAccount(), account.homeIds.count > 1 else { return }
        rosterSearchQuery = ""
        rosterSelectedWingId = nil
        rosterBrowsingAllResidents = false
        transitionToPhase(.careHomePicker)
    }

    func signOutSupervisor() {
        phaseTransitionTask?.cancel()
        isSignedIn = false
        signedInSupervisorId = nil
        currentHomeId = nil
        supervisorEmail = ""
        supervisorPIN = ""
        supervisorSignInError = nil
        cancelSupervisorPinReset()
        rosterSearchQuery = ""
        rosterSelectedWingId = nil
        rosterBrowsingAllResidents = false
        rosterPinnedResidentIds = []
        rosterRecentlyViewedIds = []
        careHomeAdminWelcomeIsManual = false
        selectedCarePatientId = nil
        phase = .home
        withAnimation(CalmMotion.softFade) {
            phaseContentVisible = true
        }
    }

    func residentsInCurrentHome() -> [CarePatientProfile] {
        guard let homeId = currentHomeId else { return [] }
        return CareRosterEngine.activeResidents(in: homeId, from: carePatients)
    }

    /// Building this presentation walks every resident against every record (sentiment
    /// summaries, last-session lookups, section grouping) — expensive to redo on every
    /// unrelated `@Published` change, including each keystroke elsewhere in the flow. Cache by
    /// the actual inputs so repeat calls with unchanged roster state are a cheap equality check.
    func rosterPresentation() -> CareRosterPresentation {
        guard let home = currentHome() else {
            return CareRosterPresentation(
                homeName: "Care home",
                totalActiveResidents: 0,
                sections: [],
                isSearching: false,
                isBrowsingAll: false
            )
        }
        let key = CareRosterUIStore.RosterPresentationCacheKey(
            homeId: home.id,
            dataRevision: careData.dataRevision,
            pinnedIds: rosterPinnedResidentIds,
            recentlyViewedIds: rosterRecentlyViewedIds,
            wingId: rosterSelectedWingId,
            searchQuery: rosterSearchQuery,
            browsingAll: rosterBrowsingAllResidents
        )
        if let cache = rosterUI.rosterPresentationCache, cache.key == key {
            return cache.value
        }
        let value = CareRosterEngine.buildPresentation(
            home: home,
            allResidents: carePatients,
            records: careSessionRecords,
            pinnedIds: rosterPinnedResidentIds,
            recentlyViewedIds: rosterRecentlyViewedIds,
            preferredWingId: rosterSelectedWingId,
            searchQuery: rosterSearchQuery,
            browsingAll: rosterBrowsingAllResidents
        )
        rosterUI.rosterPresentationCache = (key, value)
        return value
    }

    func recordResidentRosterView(_ patientId: UUID) {
        rosterRecentlyViewedIds.removeAll { $0 == patientId }
        rosterRecentlyViewedIds.insert(patientId, at: 0)
        if rosterRecentlyViewedIds.count > 30 {
            rosterRecentlyViewedIds = Array(rosterRecentlyViewedIds.prefix(30))
        }
        saveRosterPrefs()
    }

    func toggleRosterPin(_ patientId: UUID) {
        if rosterPinnedResidentIds.contains(patientId) {
            rosterPinnedResidentIds.remove(patientId)
        } else {
            rosterPinnedResidentIds.insert(patientId)
        }
        saveRosterPrefs()
    }

    private func loadRosterPrefs(for supervisorId: UUID) {
        let key = "care.roster.\(supervisorId.uuidString)"
        if let data = UserDefaults.standard.data(forKey: "\(key).pins"),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            rosterPinnedResidentIds = Set(ids)
        } else {
            rosterPinnedResidentIds = []
        }
        if let data = UserDefaults.standard.data(forKey: "\(key).recent"),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            rosterRecentlyViewedIds = ids
        } else {
            rosterRecentlyViewedIds = []
        }
    }

    private func saveRosterPrefs() {
        guard let signedInSupervisorId else { return }
        let key = "care.roster.\(signedInSupervisorId.uuidString)"
        if let data = try? JSONEncoder().encode(Array(rosterPinnedResidentIds)) {
            UserDefaults.standard.set(data, forKey: "\(key).pins")
        }
        if let data = try? JSONEncoder().encode(rosterRecentlyViewedIds) {
            UserDefaults.standard.set(data, forKey: "\(key).recent")
        }
    }

    func abandonSupervisorSignIn() {
        supervisorSignInError = nil
        cancelSupervisorPinReset()
        if !isSignedIn {
            supervisorEmail = ""
            supervisorPIN = ""
        }
    }

    /// Supervisor tapped home from roster.
    func navigateStaffToHome() {
        phase = .home
        selectedCarePatientId = nil
    }

    func beginNewResidentDiscovery() {
        guard isSignedIn else {
            phase = .home
            return
        }
        selectedCarePatientId = nil
        newResidentAgeDraft = ""
        newResidentNationalityDraft = .default
        newResidentDiscoveryPatientId = nil
        StreamAudioCache.prefetch(DiscoveryFlowPOC.snippetAudioStreamURLs)
        transitionToPhase(.careDiscoveryAgeInput)
    }

    func continueNewResidentDiscoveryFromAgeInput() -> String? {
        let trimmed = newResidentAgeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let age = Int(trimmed), (55 ... 105).contains(age) else {
            return "Enter an age between 55 and 105."
        }
        let nationality = newResidentNationalityDraft
        let seedGenre = nationality.preferredGenres.first ?? .classical
        let patientId = UUID()
        let homeId = currentHomeId ?? CareTenancyMockData.mapleLodgeId
        let provisional = CarePatientProfile(
            id: patientId,
            displayName: "New resident",
            careContextLabel: "Discovery in progress",
            likes: [],
            dislikes: [],
            preferredLight: "Soft, indirect — avoid overhead glare.",
            scentGuidance: "Unscented room unless familiar and agreed.",
            touchComfortNotes: "Ask before touch; go slowly.",
            comfortThemes: [],
            prefersGentleSoundOnsets: true,
            musicTempoBias: 0.35,
            natureVsAbstract: 0.3,
            voiceVsInstrumental: 0.4,
            residentAgeYears: age,
            nationality: nationality,
            favouriteMusicGenre: seedGenre,
            stockPortraitAssetName: nil,
            isProvisional: true,
            genrePlaylistGroups: [],
            homeId: homeId,
            wingId: CareTenancyMockData.wingResidential,
            roomLabel: "Discovery in progress",
            isActive: true
        )
        carePatients.append(provisional)
        newResidentDiscoveryPatientId = patientId
        selectedCarePatientId = patientId
        activeCarePatientId = patientId
        discoverySnippetOrder = DiscoveryFlowPOC.orderedSnippetIndices(
            forResidentAge: age,
            nationality: nationality
        )
        discoverySnippetIndex = 0
        discoveryResults = []
        discoveryPendingPick = nil
        StreamAudioCache.prefetchDiscovery(order: discoverySnippetOrder)
        transitionToPhase(.careDiscoveryCalibration)
        return nil
    }

    func abandonNewResidentAgeInput() {
        newResidentAgeDraft = ""
        newResidentNationalityDraft = .default
        transitionToPhase(.carePatientList)
    }

    private func prepareNewResidentProfileForm() {
        guard let pid = newResidentDiscoveryPatientId,
              let patient = carePatient(id: pid) else { return }
        newResidentProfileNameDraft = ""
        newResidentProfileAgeDraft = String(patient.residentAgeYears)
        newResidentProfileNationalityDraft = patient.nationality
        newResidentProfilePhoto = carePatientPortraitImages[pid]
    }

    func saveNewResidentProfile() -> String? {
        guard let pid = newResidentDiscoveryPatientId,
              let idx = carePatients.firstIndex(where: { $0.id == pid }) else {
            return "That profile is no longer available."
        }
        let name = newResidentProfileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Enter the resident’s name." }
        let ageTrim = newResidentProfileAgeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let age = Int(ageTrim), (55 ... 105).contains(age) else {
            return "Enter an age between 55 and 105."
        }
        guard newResidentProfilePhoto != nil else {
            return "Add a photo so future supervisors can recognise them."
        }

        var patients = carePatients
        patients[idx].displayName = name
        patients[idx].residentAgeYears = age
        patients[idx].nationality = newResidentProfileNationalityDraft
        patients[idx].careContextLabel = "New on roster"
        patients[idx].isProvisional = false
        // The captured photo is mandatory and always wins; the bundled portrait is the fallback.
        patients[idx].stockPortraitAssetName = ResidentPortraitCatalog.assetName(displayName: name)
        if patients[idx].genrePlaylistGroups.isEmpty {
            patients[idx].genrePlaylistGroups = [
                DiscoveryPlaylistTuning.stubGenreGroup(for: patients[idx].favouriteMusicGenre),
            ]
        }
        carePatients = patients
        if let photo = newResidentProfilePhoto {
            carePatientPortraitImages[pid] = photo
        }

        if residentSurfaceFeedbackPending {
            appendCareSessionRecord(patientId: pid, staffNote: nil, surfaceMetrics: residentSurfaceMetrics)
        }

        newResidentDiscoveryPatientId = nil
        newResidentProfileNameDraft = ""
        newResidentProfileAgeDraft = ""
        newResidentProfileNationalityDraft = .default
        newResidentProfilePhoto = nil
        selectedCarePatientId = pid
        resetResidentSurfaceMetrics()
        // A search left over from before the discovery would otherwise hide the new resident.
        rosterSearchQuery = ""
        phase = .carePatientList
        return nil
    }

    func cancelNewResidentProfileSave() {
        if let pid = newResidentDiscoveryPatientId {
            carePatients.removeAll { $0.id == pid && $0.isProvisional }
            carePatientPortraitImages.removeValue(forKey: pid)
        }
        newResidentDiscoveryPatientId = nil
        newResidentProfileNameDraft = ""
        newResidentProfileAgeDraft = ""
        newResidentProfileNationalityDraft = .default
        newResidentProfilePhoto = nil
        selectedCarePatientId = nil
        phase = .carePatientList
    }

    func goBackFromEntryMode() {
        phase = .careSessionPrep
    }

    func resetCarePrepForNewSession() {
        carePlannedDurationMinutes = 15
        carePrepVRImmersiveRoute = false
        carePrepRoomDisplayMirroring = false
    }

    func openCareSessionPrep() {
        guard isSignedIn else {
            phase = .home
            return
        }
        resetCarePrepForNewSession()
        phase = .careSessionPrep
    }

    func continueCareSessionFromPrep() {
        guard let pid = selectedCarePatientId else { return }
        startCareGuidedSession(for: pid)
    }

    func startCareGuidedSession(for patientId: UUID) {
        guard isSignedIn else {
            phase = .home
            return
        }
        selectedCarePatientId = patientId
        activeCarePatientId = patientId
        isCareStaffSession = true
        phase = .entryMode
    }

    @discardableResult
    private func appendCareSessionRecord(
        patientId: UUID,
        staffNote: String?,
        settledness: Int? = nil,
        engagement: Int? = nil,
        comfortTolerance: Int? = nil,
        moodRating: Int? = nil,
        alertnessRating: Int? = nil,
        emotionalStateRating: Int? = nil,
        lucidityRating: Int? = nil,
        surfaceMetrics: ResidentSurfaceSessionMetrics? = nil,
        context: SessionContextDraft? = nil
    ) -> CareSessionRecord {
        let metrics = surfaceMetrics ?? (residentSurfaceFeedbackPending ? residentSurfaceMetrics : nil)
        let ctx = context ?? sessionContextDraft
        var rec = CareSessionRecord(
            id: UUID(),
            patientId: patientId,
            date: Date(),
            moodSummary: replayMoodSnapshot ?? "—",
            calmPercent: Int(calmScore * 100),
            staffNote: staffNote,
            settledness: settledness,
            engagement: engagement,
            comfortTolerance: comfortTolerance,
            moodRating: moodRating,
            alertnessRating: alertnessRating,
            emotionalStateRating: emotionalStateRating,
            lucidityRating: lucidityRating,
            sessionDurationSeconds: metrics?.durationSeconds,
            residentGenrePlayCount: metrics.map(\.totalGenrePlays).flatMap { $0 > 0 ? $0 : nil },
            residentTrackChangeCount: metrics.map(\.trackChangeCount).flatMap { $0 > 0 ? $0 : nil },
            residentImmersiveEntryCount: metrics.map(\.immersiveEntryCount).flatMap { $0 > 0 ? $0 : nil },
            residentGenresPlayedSummary: metrics?.genresPlayedSummary(),
            residentInteractionCollation: metrics?.interactionSummary(),
            residentLikedTracksSummary: metrics?.likedTracksSummary(),
            residentSkippedTracksSummary: metrics?.skippedTracksSummary(),
            residentTopDwellTracksSummary: metrics?.topDwellTracksSummary(),
            residentRageBurstCount: metrics.map(\.rageBurstCount).flatMap { $0 > 0 ? $0 : nil },
            sessionTimeOfDay: ctx.timeOfDay.label,
            preSessionState: ctx.priorState?.label,
            sessionContextSummary: ctx.formattedContextLine(),
            residentLedSession: ctx.residentLedSession,
            distressOrPRNNearby: ctx.distressOrPRNNearby,
            insightNarrative: nil,
            insightSuggestedNextStep: nil,
            insightHandoverText: nil,
            insightFamilyText: nil,
            lightsDimmed: ctx.environmentTags.contains(.lightsDimmed)
        )

        if let patient = carePatient(id: patientId) {
            let prior = recordsForPatient(patientId)
            let pack = CareSessionInsightBuilder.build(patient: patient, record: rec, priorRecords: prior)
            rec.insightNarrative = pack.narrative
            rec.insightSuggestedNextStep = pack.suggestedNextStep
            rec.insightHandoverText = pack.handoverText
            rec.insightFamilyText = pack.familyText
        }

        careSessionRecords.insert(rec, at: 0)
        return rec
    }

    func shouldOfferSessionSentimentFeedback() -> Bool {
        guard newResidentDiscoveryPatientId == nil,
              let pid = activeCarePatientId ?? selectedCarePatientId,
              let patient = carePatient(id: pid),
              !patient.isProvisional
        else { return false }
        return residentSurfaceFeedbackPending || isCareStaffSession
    }

    func beginSessionSentimentFeedback() {
        sessionSentimentStep = 0
        sessionSentimentDraft = SessionSentimentDraft()
        sessionContextDraft = SessionContextDraft()
        phase = .careSessionSentimentFeedback
    }

    func sessionSentimentBinding(for step: CareSessionSentimentStep) -> Binding<Int?> {
        switch step {
        case .mood:
            return Binding(
                get: { self.sessionSentimentDraft.mood },
                set: { self.sessionSentimentDraft.mood = $0 }
            )
        case .alertness:
            return Binding(
                get: { self.sessionSentimentDraft.alertness },
                set: { self.sessionSentimentDraft.alertness = $0 }
            )
        case .emotionalState:
            return Binding(
                get: { self.sessionSentimentDraft.emotionalState },
                set: { self.sessionSentimentDraft.emotionalState = $0 }
            )
        case .lucidity:
            return Binding(
                get: { self.sessionSentimentDraft.lucidity },
                set: { self.sessionSentimentDraft.lucidity = $0 }
            )
        }
    }

    func advanceSessionSentimentStep() {
        sessionSentimentStep = min(sessionSentimentStep + 1, CareSessionSentimentStep.allCases.count - 1)
    }

    func retreatSessionSentimentStep() {
        sessionSentimentStep = max(sessionSentimentStep - 1, 0)
    }

    func saveSessionSentimentFeedback() {
        guard let pid = activeCarePatientId ?? selectedCarePatientId,
              let mood = sessionSentimentDraft.mood,
              let alertness = sessionSentimentDraft.alertness,
              let emotional = sessionSentimentDraft.emotionalState,
              let lucidity = sessionSentimentDraft.lucidity
        else { return }

        let note = sessionSentimentDraft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let metricsSnapshot = residentSurfaceMetrics
        let rec = appendCareSessionRecord(
            patientId: pid,
            staffNote: note.isEmpty ? nil : note,
            moodRating: mood,
            alertnessRating: alertness,
            emotionalStateRating: emotional,
            lucidityRating: lucidity,
            surfaceMetrics: metricsSnapshot,
            context: sessionContextDraft
        )
        sessionSentimentStep = 0
        sessionSentimentDraft = SessionSentimentDraft()
        presentSessionInsight(for: pid, record: rec)
    }

    func skipSessionSentimentFeedback() {
        let pid = activeCarePatientId ?? selectedCarePatientId
        if let pid {
            let metricsSnapshot = residentSurfaceMetrics
            let rec = appendCareSessionRecord(
                patientId: pid,
                staffNote: nil,
                surfaceMetrics: metricsSnapshot,
                context: sessionContextDraft
            )
            if shouldPresentInsight(for: rec) {
                presentSessionInsight(for: pid, record: rec)
            } else {
                finishAfterSessionFeedback(patientId: pid)
            }
        } else {
            phase = .carePatientList
        }
    }

    func completeSessionInsightReview() {
        guard let pid = activeCarePatientId ?? selectedCarePatientId else {
            pendingSessionInsight = nil
            phase = .carePatientList
            return
        }
        pendingSessionInsight = nil
        finishAfterSessionFeedback(patientId: pid)
    }

    private func shouldPresentInsight(for record: CareSessionRecord) -> Bool {
        record.insightNarrative != nil
            || record.residentInteractionSummaryLine() != nil
            || record.moodRating != nil
    }

    private func presentSessionInsight(for patientId: UUID, record: CareSessionRecord) {
        guard let patient = carePatient(id: patientId) else {
            finishAfterSessionFeedback(patientId: patientId)
            return
        }
        let prior = recordsForPatient(patientId).filter { $0.id != record.id }
        pendingSessionInsight = CareSessionInsightBuilder.build(
            patient: patient,
            record: record,
            priorRecords: prior
        )
        phase = .careSessionInsight
    }

    private func finishAfterSessionFeedback(patientId: UUID) {
        sessionSentimentStep = 0
        sessionSentimentDraft = SessionSentimentDraft()
        sessionContextDraft = SessionContextDraft()
        pendingSessionInsight = nil
        isCareStaffSession = false
        activeCarePatientId = nil
        selectedCarePatientId = patientId
        clearResidentSessionSurfaceState()
        resetResidentSurfaceMetrics()
        phase = .carePatientList
    }

    func sentimentSummary(for patientId: UUID) -> CareSessionSentimentSummary {
        CareSessionSentimentAnalytics.summary(for: recordsForPatient(patientId))
    }

    /// Read by the roster body on every pass (including each search keystroke) — cached so it
    /// only re-walks every session record when the home or the underlying data changes.
    func careHomeSentimentOverview() -> CareSessionSentimentSummary {
        let key = CareRosterUIStore.DashboardPresentationCacheKey(homeId: currentHomeId, dataRevision: careData.dataRevision)
        if let cache = rosterUI.homeSentimentOverviewCache, cache.key == key {
            return cache.value
        }
        let value = CareSessionSentimentAnalytics.homeOverview(for: residentsInCurrentHome(), records: careSessionRecords)
        rosterUI.homeSentimentOverviewCache = (key, value)
        return value
    }

    // MARK: - Group session

    func beginGroupSession() {
        guard isSignedIn else {
            phase = .home
            return
        }
        groupSessionTracks = GroupSessionPlaylistCompiler.compile(
            patients: residentsInCurrentHome(),
            sessionRecords: careSessionRecords
        )
        groupSessionTrackIndex = 0
        groupSessionStartedAt = Date()
        groupSessionTracksPlayed = 0
        groupSession.groupSessionPlayedTrackIDs = []
        groupSessionFeedbackStep = 0
        groupSessionFeedbackDraft = GroupSessionFeedbackDraft()
        isGroupSessionActive = true
        phase = .careGroupSession
    }

    func endGroupSession() {
        guard isGroupSessionActive else { return }
        isGroupSessionActive = false
        groupSessionFeedbackStep = 0
        groupSessionFeedbackDraft = GroupSessionFeedbackDraft()
        phase = .careGroupSessionFeedback
    }

    func groupSessionNextTrack() {
        guard !groupSessionTracks.isEmpty else { return }
        groupSessionTrackIndex = (groupSessionTrackIndex + 1) % groupSessionTracks.count
    }

    func groupSessionPreviousTrack() {
        guard !groupSessionTracks.isEmpty else { return }
        groupSessionTrackIndex = (groupSessionTrackIndex - 1 + groupSessionTracks.count) % groupSessionTracks.count
    }

    func groupSessionSelectTrack(at index: Int) {
        guard groupSessionTracks.indices.contains(index) else { return }
        groupSessionTrackIndex = index
    }

    func markGroupTrackPlayed() {
        guard groupSessionTracks.indices.contains(groupSessionTrackIndex) else { return }
        let id = groupSessionTracks[groupSessionTrackIndex].id
        guard !groupSession.groupSessionPlayedTrackIDs.contains(id) else { return }
        groupSession.groupSessionPlayedTrackIDs.insert(id)
        groupSessionTracksPlayed += 1
    }

    func groupSessionDurationSummary() -> String? {
        var parts: [String] = []
        if let startedAt = groupSessionStartedAt {
            let seconds = max(1, Int(Date().timeIntervalSince(startedAt).rounded()))
            let mins = seconds / 60
            let secs = seconds % 60
            if mins > 0 {
                parts.append(String(format: "%dm %ds", mins, secs))
            } else {
                parts.append("\(secs)s")
            }
        }
        if groupSessionTracksPlayed > 0 {
            parts.append("\(groupSessionTracksPlayed) track\(groupSessionTracksPlayed == 1 ? "" : "s") played")
        }
        if !groupSessionTracks.isEmpty {
            parts.append("\(groupSessionTracks.count) in compiled playlist")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func groupSessionFeedbackBinding(for step: GroupSessionFeedbackStep) -> Binding<Int?> {
        switch step {
        case .morale:
            return Binding(get: { self.groupSessionFeedbackDraft.morale }, set: { self.groupSessionFeedbackDraft.morale = $0 })
        case .alertness:
            return Binding(get: { self.groupSessionFeedbackDraft.alertness }, set: { self.groupSessionFeedbackDraft.alertness = $0 })
        case .lucidity:
            return Binding(get: { self.groupSessionFeedbackDraft.lucidity }, set: { self.groupSessionFeedbackDraft.lucidity = $0 })
        case .engagement:
            return Binding(get: { self.groupSessionFeedbackDraft.engagement }, set: { self.groupSessionFeedbackDraft.engagement = $0 })
        }
    }

    func advanceGroupSessionFeedbackStep() {
        groupSessionFeedbackStep = min(groupSessionFeedbackStep + 1, GroupSessionFeedbackStep.allCases.count - 1)
    }

    func retreatGroupSessionFeedbackStep() {
        groupSessionFeedbackStep = max(groupSessionFeedbackStep - 1, 0)
    }

    func saveGroupSessionFeedback() {
        guard let morale = groupSessionFeedbackDraft.morale,
              let alertness = groupSessionFeedbackDraft.alertness,
              let lucidity = groupSessionFeedbackDraft.lucidity,
              let engagement = groupSessionFeedbackDraft.engagement
        else { return }

        let note = groupSessionFeedbackDraft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = groupSessionStartedAt.map { max(1, Int(Date().timeIntervalSince($0).rounded())) } ?? 0
        let snapshot = groupSessionTracks.map(\.title)

        let rec = GroupSessionRecord(
            id: UUID(),
            date: Date(),
            durationSeconds: duration,
            tracksPlayed: groupSessionTracksPlayed,
            moraleRating: morale,
            alertnessRating: alertness,
            lucidityRating: lucidity,
            engagementRating: engagement,
            staffNote: note.isEmpty ? nil : note,
            playlistSnapshot: snapshot
        )
        groupSessionRecords.insert(rec, at: 0)
        resetGroupSessionState()
        phase = .carePatientList
    }

    func skipGroupSessionFeedback() {
        let duration = groupSessionStartedAt.map { max(1, Int(Date().timeIntervalSince($0).rounded())) } ?? 0
        let rec = GroupSessionRecord(
            id: UUID(),
            date: Date(),
            durationSeconds: duration,
            tracksPlayed: groupSessionTracksPlayed,
            moraleRating: nil,
            alertnessRating: nil,
            lucidityRating: nil,
            engagementRating: nil,
            staffNote: nil,
            playlistSnapshot: groupSessionTracks.map(\.title)
        )
        groupSessionRecords.insert(rec, at: 0)
        resetGroupSessionState()
        phase = .carePatientList
    }

    private func resetGroupSessionState() {
        groupSessionTracks = []
        groupSessionTrackIndex = 0
        groupSessionStartedAt = nil
        groupSessionTracksPlayed = 0
        groupSession.groupSessionPlayedTrackIDs = []
        groupSessionFeedbackStep = 0
        groupSessionFeedbackDraft = GroupSessionFeedbackDraft()
        isGroupSessionActive = false
    }

    func latestGroupSessionSummaryLine() -> String? {
        guard let last = groupSessionRecords.first,
              let morale = last.moraleRating,
              let alertness = last.alertnessRating,
              let lucidity = last.lucidityRating,
              let engagement = last.engagementRating
        else { return nil }
        return String(format: "Last group: morale/affect %d · alertness %d · orientation %d · engagement %d", morale, alertness, lucidity, engagement)
    }

    func saveCareFeedback(
        tempoBias: Double,
        natureVsAbstract: Double,
        voiceVsInstrumental: Double,
        settledness: Int,
        engagement: Int,
        comfortTolerance: Int,
        staffNote: String
    ) {
        guard let pid = activeCarePatientId ?? selectedCarePatientId,
              let idx = carePatients.firstIndex(where: { $0.id == pid }) else { return }
        var patients = carePatients
        patients[idx].musicTempoBias = tempoBias
        patients[idx].natureVsAbstract = natureVsAbstract
        patients[idx].voiceVsInstrumental = voiceVsInstrumental
        carePatients = patients
        let note = staffNote.trimmingCharacters(in: .whitespacesAndNewlines)
        appendCareSessionRecord(
            patientId: pid,
            staffNote: note.isEmpty ? nil : note,
            settledness: settledness,
            engagement: engagement,
            comfortTolerance: comfortTolerance,
            surfaceMetrics: residentSurfaceFeedbackPending ? residentSurfaceMetrics : nil
        )
        resetResidentSurfaceMetrics()
        isCareStaffSession = false
        activeCarePatientId = nil
        selectedCarePatientId = pid
        clearResidentSessionSurfaceState()
        phase = .carePatientDetail
    }

    func skipCareFeedback() {
        let pid = activeCarePatientId ?? selectedCarePatientId
        if let pid {
            appendCareSessionRecord(patientId: pid, staffNote: nil)
        }
        isCareStaffSession = false
        activeCarePatientId = nil
        if let pid { selectedCarePatientId = pid }
        clearResidentSessionSurfaceState()
        phase = .carePatientDetail
    }

    private func clearResidentSessionSurfaceState() {
        isResidentSession = false
        residentSessionGenre = nil
        residentTraffic = nil
        residentFace = nil
        residentVoiceLine = ""
        resetLivingPlaylistCounters()
    }

    private func resetCareSessionFlags() {
        isCareStaffSession = false
        activeCarePatientId = nil
    }

    // MARK: - Immersive session vitals (passthrough — storage lives in `vitals`)
    //
    // `ImmersiveSessionView` and `SessionBottomConfigMenu` observe `state.vitals` directly
    // instead of reading through these passthrough properties, so the 1.2s heart-rate tick
    // doesn't invalidate the rest of the flow. These accessors remain for the handful of
    // orchestration methods below (`beginSession`, `endSession`, resets) that touch vitals
    // alongside other domains.

    var mockHeartRateStart: Double {
        get { vitals.mockHeartRateStart }
        set { vitals.mockHeartRateStart = newValue }
    }
    var mockHeartRateCurrent: Double {
        get { vitals.mockHeartRateCurrent }
        set { vitals.mockHeartRateCurrent = newValue }
    }
    var calmScore: Double {
        get { vitals.calmScore }
        set { vitals.calmScore = newValue }
    }
    var sessionHomeLightsSyncEnabled: Bool {
        get { vitals.sessionHomeLightsSyncEnabled }
        set { vitals.sessionHomeLightsSyncEnabled = newValue }
    }
    var replayExperienceAvailable: Bool {
        get { vitals.replayExperienceAvailable }
        set { vitals.replayExperienceAvailable = newValue }
    }
    var replayMoodSnapshot: String? {
        get { vitals.replayMoodSnapshot }
        set { vitals.replayMoodSnapshot = newValue }
    }
    var replayCalmPercentSnapshot: Int {
        get { vitals.replayCalmPercentSnapshot }
        set { vitals.replayCalmPercentSnapshot = newValue }
    }
    var replayHeartRateSnapshot: Int {
        get { vitals.replayHeartRateSnapshot }
        set { vitals.replayHeartRateSnapshot = newValue }
    }
    var iotPhilipsHueEnabled: Bool {
        get { vitals.iotPhilipsHueEnabled }
        set { vitals.iotPhilipsHueEnabled = newValue }
    }
    var iotHomeKitEnabled: Bool {
        get { vitals.iotHomeKitEnabled }
        set { vitals.iotHomeKitEnabled = newValue }
    }
    var iotMatterEnabled: Bool {
        get { vitals.iotMatterEnabled }
        set { vitals.iotMatterEnabled = newValue }
    }
    var iotFollowSessionBreath: Bool {
        get { vitals.iotFollowSessionBreath }
        set { vitals.iotFollowSessionBreath = newValue }
    }
    var iotMaxSceneBrightness: Double {
        get { vitals.iotMaxSceneBrightness }
        set { vitals.iotMaxSceneBrightness = newValue }
    }
    var immersiveMediaSessionID: UUID {
        get { vitals.immersiveMediaSessionID }
        set { vitals.immersiveMediaSessionID = newValue }
    }
    private(set) var sessionAnchoredWithPhoto: Bool {
        get { vitals.sessionAnchoredWithPhoto }
        set { vitals.sessionAnchoredWithPhoto = newValue }
    }
    private(set) var replaySnapshotMediaID: UUID? {
        get { vitals.replaySnapshotMediaID }
        set { vitals.replaySnapshotMediaID = newValue }
    }
    private(set) var replaySessionPhotoAnchored: Bool {
        get { vitals.replaySessionPhotoAnchored }
        set { vitals.replaySessionPhotoAnchored = newValue }
    }

    let moodOptions = ["Stressed", "Anxious", "Down", "Overwhelmed", "Tired", "Calm"]

    func beginSession() {
        immersiveMediaSessionID = UUID()
        sessionAnchoredWithPhoto = capturedImage != nil
        mockHeartRateStart = Double.random(in: 72 ... 88)
        mockHeartRateCurrent = mockHeartRateStart
        sessionHomeLightsSyncEnabled = false
        replayExperienceAvailable = false
        replayMoodSnapshot = nil
        replaySnapshotMediaID = nil
        replaySessionPhotoAnchored = false
        if isResidentSession {
            resetLivingPlaylistCounters()
        }
    }

    func endSession() {
        mockHeartRateCurrent = max(58, mockHeartRateStart - Double.random(in: 4 ... 12))
        calmScore = min(0.98, calmScore + 0.05)
        replayMoodSnapshot = selectedMoodsOrdered.isEmpty
            ? nil
            : selectedMoodsOrdered.joined(separator: ", ")
        replayCalmPercentSnapshot = Int(calmScore * 100)
        replayHeartRateSnapshot = Int(mockHeartRateCurrent)
        replaySnapshotMediaID = immersiveMediaSessionID
        replaySessionPhotoAnchored = sessionAnchoredWithPhoto
        replayExperienceAvailable = true
    }

    /// Gentle pause before insight or returning to resident playlists.
    func finishSessionWithSettling() {
        endSession()
        phase = .sessionSettling
    }

    func resetToHome() {
        phase = .home
        capturedImage = nil
        selectedMoods = []
        replayExperienceAvailable = false
        replayMoodSnapshot = nil
        replaySnapshotMediaID = nil
        replaySessionPhotoAnchored = false
        resetCareSessionFlags()
        clearResidentSessionSurfaceState()
        resetDiscoveryState()
        selectedCarePatientId = nil
        resetCarePrepForNewSession()
    }

    func resetAllForFreshAppLaunch() {
        phaseTransitionTask?.cancel()
        phaseContentVisible = true
        phase = .home
        supervisorEmail = ""
        supervisorPIN = ""
        supervisorSignInError = nil
        cancelSupervisorPinReset()
        isSignedIn = false
        signedInSupervisorId = nil
        currentHomeId = nil
        pendingCareRosterAfterSignIn = false
        rosterSearchQuery = ""
        rosterSelectedWingId = nil
        rosterBrowsingAllResidents = false
        rosterDisplayMode = .cards
        rosterPinnedResidentIds = []
        rosterRecentlyViewedIds = []
        carePatientPortraitImages = [:]
        capturedImage = nil
        selectedMoods = []
        mockHeartRateStart = 78
        mockHeartRateCurrent = 72
        calmScore = 0.82
        sessionHomeLightsSyncEnabled = false
        replayExperienceAvailable = false
        replayMoodSnapshot = nil
        replaySnapshotMediaID = nil
        replaySessionPhotoAnchored = false
        immersiveMediaSessionID = UUID()
        sessionAnchoredWithPhoto = false
        seedCareDataOffMain()
        selectedCarePatientId = nil
        resetCareSessionFlags()
        clearResidentSessionSurfaceState()
        resetDiscoveryState()
        resetNewResidentFlowState()
        resetGroupSessionState()
        resetCarePrepForNewSession()
        resetIoTDefaults()
    }

    /// Builds the deterministic roster + demo history on a background thread and publishes it on the
    /// main actor. Costs are paid once (cached snapshots in `CareTenancyMockData`) and off the main
    /// thread; the launch overlay covers the brief window before the roster is populated, and the
    /// roster itself isn't reachable until after sign-in.
    private func seedCareDataOffMain() {
        Task.detached(priority: .userInitiated) { [weak self] in
            let patients = CareTenancyMockData.allPatients()
            let records = CareStaffMockData.initialRecords + CareTenancyMockData.supplementalRecords()
            await MainActor.run {
                guard let self else { return }
                self.careData.carePatients = patients
                self.careData.careSessionRecords = records
            }
        }
    }

    private func resetIoTDefaults() {
        iotPhilipsHueEnabled = false
        iotHomeKitEnabled = false
        iotMatterEnabled = false
        iotFollowSessionBreath = true
        iotMaxSceneBrightness = 0.88
    }

    func startDiscoveryCalibration(for patientId: UUID) {
        guard isSignedIn else {
            phase = .home
            return
        }
        selectedCarePatientId = patientId
        activeCarePatientId = patientId
        if let patient = carePatient(id: patientId) {
            discoverySnippetOrder = DiscoveryFlowPOC.orderedSnippetIndices(
                forResidentAge: patient.residentAgeYears,
                nationality: patient.nationality
            )
        } else {
            discoverySnippetOrder = Array(0..<DiscoveryFlowPOC.snippetCount)
        }
        discoverySnippetIndex = 0
        discoveryResults = []
        discoveryPendingPick = nil
        phase = .careDiscoveryCalibration
    }

    func setDiscoveryPick(_ sentiment: DiscoveryTrafficSentiment) {
        discoveryPendingPick = sentiment
    }

    func commitDiscoverySnippetSlice() {
        let pick = discoveryPendingPick ?? .neutral
        discoveryResults.append(DiscoverySnippetResult(snippetIndex: discoverySnippetIndex, sentiment: pick))
        discoveryPendingPick = nil
        discoverySnippetIndex += 1
        if discoverySnippetIndex >= DiscoveryFlowPOC.snippetCount {
            if let pid = selectedCarePatientId ?? activeCarePatientId,
               let ix = carePatients.firstIndex(where: { $0.id == pid }) {
                var patient = carePatients[ix]
                DiscoveryPlaylistTuning.applyDiscoveryResults(discoveryResults, to: &patient)
                carePatients[ix] = patient
            }
            /// Resident instrument surface opens from `DiscoveryCalibrationView` after the exit typography animation completes.
        }
    }

    func abandonDiscoveryCalibration() {
        discoverySnippetIndex = 0
        discoveryResults = []
        discoveryPendingPick = nil
        if newResidentDiscoveryPatientId != nil {
            phase = .carePatientList
        } else {
            phase = .carePatientDetail
        }
    }

    private func resetDiscoveryState() {
        discoverySnippetIndex = 0
        discoveryResults = []
        discoveryPendingPick = nil
        discoverySnippetOrder = []
    }

    private func resetNewResidentFlowState() {
        newResidentDiscoveryPatientId = nil
        newResidentAgeDraft = ""
        newResidentNationalityDraft = .default
        newResidentProfileNameDraft = ""
        newResidentProfileAgeDraft = ""
        newResidentProfileNationalityDraft = .default
        newResidentProfilePhoto = nil
        resetResidentSurfaceMetrics()
    }
}

enum FlowPhase: Int, CaseIterable, Identifiable {
    case home = 0
    case entryMode = 1
    case captureMoment = 2
    case moodSelect = 3
    case processingFast = 4
    case immersive = 5
    case insight = 6
    case carePatientList = 7
    case carePatientDetail = 8
    case careSessionFeedback = 9
    case careSessionPrep = 10
    case residentProfile = 11
    case careFaceLinkedPick = 12
    /// Timed calm snippets — patient picks traffic-light minimalist face per snippet.
    case careDiscoveryCalibration = 13
    /// Quiet breath before insight or resident return.
    case sessionSettling = 14
    /// Resident age before a new-resident discovery pass.
    case careDiscoveryAgeInput = 17
    /// Supervisor captures name, age, and photo after a new-resident session.
    case careNewResidentProfile = 18
    /// Sequential 1–10 sentiment ratings after sessions with existing residents.
    case careSessionSentimentFeedback = 19
    /// Supervisor-led group listening with compiled cross-resident playlist.
    case careGroupSession = 20
    /// Group morale / alertness / lucidity / engagement after group session ends.
    case careGroupSessionFeedback = 21
    /// Brief welcome after supervisor sign-in before the resident roster.
    case supervisorWelcome = 22
    /// Auto-generated session summary, handover export, and next-step hints.
    case careSessionInsight = 23
    /// Multi-home supervisors pick which care home to open today.
    case careHomePicker = 24
    /// Brief welcome before home admin insights dashboard.
    case careHomeAdminWelcome = 25
    /// Home admin analytics — session impact across the home.
    case careHomeAdminDashboard = 26

    var id: Int { rawValue }
}
