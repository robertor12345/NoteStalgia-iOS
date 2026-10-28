import Foundation

// MARK: - Coordinator: catalogue queues, discovery through the backend, listening signals
//
// Everything here degrades to the existing offline behaviour (seven bundled stems, the
// red/green heuristic in `DiscoveryPlaylistTuning`) when no backend is configured or reachable.

extension SessionPOCState {
    // MARK: Queues for the calm surface

    /// Playable queue for a genre glyph: the profile playlists' own tracks followed by the backend's
    /// recommendation queue for this resident, else the bundled stem. Session preferences
    /// (sun-likes, dwell, staff suggestions) order it; cloud-skipped titles drop out.
    func residentPlaylistQueue(for genre: ResidentMusicGenre) -> [ResidentTrackRef] {
        guard let patient = residentSurfacePatient() else { return ResidentTrackRef.bundledQueue(for: genre) }
        // Songs filed on the profile (family/staff picks, discovery playlists) lead, then the
        // backend's queue for the genre; the bundled stem only when there is nothing else.
        var refs: [ResidentTrackRef] = []
        if let group = patient.genrePlaylistGroups.first(where: { $0.genre == genre }) {
            refs += group.playlists.flatMap { $0.tracks ?? [] }
        }
        if APIConfig.isConfigured, let queue = recommendations.queue(for: patient.id, genre: genre) {
            refs += queue
        }
        if refs.isEmpty {
            refs = ResidentTrackRef.bundledQueue(for: genre)
        }
        // One entry per title, bundled stems only when nothing else exists.
        var seen = Set<String>()
        refs = refs.filter { seen.insert($0.title).inserted }

        if refs.allSatisfy({ residentSurfaceMetrics.skippedTrackTitles.contains($0.title) }) {
            residentSurface.residentSurfaceMetrics.clearSkippedTracks(matching: refs.map(\.title))
        }
        let skipped = residentSurfaceMetrics.skippedTrackTitles
        let suggested = Set(patient.suggestedLikedTrackTitles)
        let metrics = residentSurfaceMetrics
        return refs
            .filter { !skipped.contains($0.title) }
            .enumerated()
            .sorted { a, b in
                let scoreA = metrics.preferenceScore(for: a.element.title, suggestedBoost: suggested.contains(a.element.title) ? 2 : 0)
                let scoreB = metrics.preferenceScore(for: b.element.title, suggestedBoost: suggested.contains(b.element.title) ? 2 : 0)
                if scoreA != scoreB { return scoreA > scoreB }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    func noteResidentTrackStarted(_ ref: ResidentTrackRef) {
        residentSurface.residentSurfaceMetrics.trackIdsByTitle[ref.title] = ref.id
        if let artist = ref.artist, !ref.isBundled {
            residentSurface.residentSurfaceMetrics.trackArtistsByTitle[ref.title] = artist
        }
        noteResidentTrackStarted(ref.title)
    }

    func noteTrackPreviewFailed(_ ref: ResidentTrackRef) {
        residentSurface.residentSurfaceMetrics.previewFailedTrackIds.append(ref.id)
    }

    /// Refreshes the cached surface queues for a resident from the backend (best effort).
    func refreshRecommendations(for patientId: UUID) async {
        guard APIConfig.isConfigured, let patient = carePatient(id: patientId), !patient.isProvisional else { return }
        if let queues = try? await MusicCatalogClient.recommendations(residentId: patientId) {
            recommendations.store(queues: queues, for: patientId)
        }
    }

    // MARK: Suggested songs from search

    /// Adds a catalogue song the family or staff know: it is a suggested like *and* joins the
    /// resident's playlist for its genre so the glyph can play it.
    func addSuggestedLikedTrack(for patientId: UUID, ref: ResidentTrackRef) {
        guard let i = carePatients.firstIndex(where: { $0.id == patientId }) else { return }
        var patients = carePatients
        var patient = patients[i]
        if !patient.suggestedLikedTrackTitles.contains(ref.title) {
            patient.suggestedLikedTrackTitles.append(ref.title)
        }
        var ids = patient.suggestedLikedTrackIds ?? [:]
        ids[ref.title] = ref.id
        patient.suggestedLikedTrackIds = ids

        if let g = patient.genrePlaylistGroups.firstIndex(where: { $0.genre == ref.genre }) {
            var group = patient.genrePlaylistGroups[g]
            if group.playlists.isEmpty {
                group.playlists.append(CarePlaylistEntry(id: UUID(), title: "Family & staff picks · \(ref.genre.accessibilityLabel)", trackCount: 0, durationMinutes: 0, trackTitles: [], tracks: []))
            }
            var entry = group.playlists[0]
            var tracks = entry.tracks ?? []
            if !tracks.contains(where: { $0.id == ref.id }) {
                tracks.append(ref)
                entry.tracks = tracks
                if !entry.trackTitles.contains(ref.title) { entry.trackTitles.append(ref.title) }
                entry.trackCount = max(entry.trackCount, tracks.count)
                entry.durationMinutes = max(entry.durationMinutes, tracks.count * 3)
            }
            group.playlists[0] = entry
            patient.genrePlaylistGroups[g] = group
        } else {
            patient.genrePlaylistGroups.append(
                CareGenrePlaylistGroup(genre: ref.genre, playlists: [
                    CarePlaylistEntry(id: UUID(), title: "Family & staff picks · \(ref.genre.accessibilityLabel)", trackCount: 1, durationMinutes: 3, trackTitles: [ref.title], tracks: [ref]),
                ])
            )
        }
        patients[i] = patient
        carePatients = patients
        noteStaffPick(trackId: ref.id, genre: ref.genre, artist: ref.artist, isBundled: ref.isBundled, for: patientId, removed: false)
    }

    // MARK: Staff picks → the model, in real time

    /// A song filed on (or removed from) the profile is strong evidence. It goes to the backend as a
    /// `staffPick` signal straight away; the catalogue grows around the artist so there are similar
    /// songs to offer; and the glyph queues refresh once the backend has applied it (the sync engine
    /// calls `refreshRecommendations` after every delivered signals batch).
    func noteStaffPick(trackId: String, genre: ResidentMusicGenre?, artist: String?, isBundled: Bool, for patientId: UUID, removed: Bool) {
        guard APIConfig.isConfigured, !isBundled else { return }
        let event = SignalBatch.Event(kind: removed ? "staffPickRemoved" : "staffPick", at: Date(), trackId: trackId, genre: genre, value: nil, sentiment: nil, frustrated: nil)
        MainActor.assumeIsolated {
            sync.enqueueSignals(residentId: patientId, batch: SignalBatch(batchId: UUID(), sessionId: nil, deviceId: AuthSession.deviceId, at: Date(), events: [event]))
        }
        if !removed, let artist {
            Task { @MainActor in
                await expandCatalogue(aroundArtists: [artist])
                await refreshRecommendations(for: patientId)
            }
        }
    }

    /// "More songs by someone they love." Best effort, once per artist per launch; the Worker
    /// answers from its catalogue when it has already expanded that artist this week.
    func expandCatalogue(aroundArtists artists: [String]) async {
        guard APIConfig.isConfigured else { return }
        for artist in artists where recommendations.markArtistExpanded(artist) {
            _ = try? await MusicCatalogClient.expandArtist(artist)
        }
    }

    // MARK: Group sessions through the backend

    /// The room's playlist, ready to show in one piece. With a backend it is ranked by every
    /// participant's taste profile at once — age, origin, the genres they responded to, songs like the
    /// ones they love — and those picks lead the roster-compiled list; offline, the roster-compiled
    /// list goes out alone. Sleeves for the card and the list and the first preview are fetched before
    /// the list is returned, and the whole wait lasts at least `minimumSeconds`, so staff see one calm
    /// loading ring rather than songs and artwork landing in the list one by one. The backend gets
    /// `serverTimeout` before the local list goes out without it.
    @MainActor
    func prepareGroupPlaylist(
        local: [GroupSessionTrack],
        participants: [CarePatientProfile],
        minimumSeconds: TimeInterval = 3,
        serverTimeout: TimeInterval = 8
    ) async -> [GroupSessionTrack] {
        let clock = ContinuousClock()
        let started = clock.now
        let serverPicks = await fetchGroupPlaylistFromBackend(participants: participants, timeout: serverTimeout)
        let tracks = GroupSessionPlaylistCompiler.merge(serverPicks: serverPicks, into: local, keepingFirst: nil)
        if let first = tracks.first?.ref.previewURL { StreamAudioCache.prefetch([first]) }
        await prefetchGroupPlaylistArtwork(tracks, timeout: 4)
        let elapsed = clock.now - started
        if elapsed < .seconds(minimumSeconds) {
            try? await Task.sleep(for: .seconds(minimumSeconds) - elapsed)
        }
        return tracks
    }

    private func fetchGroupPlaylistFromBackend(participants: [CarePatientProfile], timeout: TimeInterval) async -> [GroupSessionTrack] {
        guard APIConfig.isConfigured, let homeId = currentHomeId else { return [] }
        let ids = participants.filter { !$0.isProvisional }.map(\.id)
        guard !ids.isEmpty else { return [] }
        var genres: [ResidentMusicGenre] = []
        if case .genre(let genre)? = groupSession.plannedActivity?.theme { genres = [genre] }
        let picks = await withTaskGroup(of: MusicCatalogClient.GroupPlaylist?.self) { group -> MusicCatalogClient.GroupPlaylist? in
            group.addTask { try? await MusicCatalogClient.groupPlaylist(homeId: homeId, residentIds: ids, genres: genres) }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        guard let picks else { return [] }
        return picks.tracks.map { ref -> GroupSessionTrack in
            let names = picks.champions[ref.id] ?? []
            let source = names.isEmpty ? "the whole room" : names.count == 1 ? names[0] : "\(names[0]) and \(names.count - 1) other\(names.count == 2 ? "" : "s")"
            return GroupSessionTrack(id: UUID(), title: ref.title, genre: ref.genre, sourceResidentName: source, score: 10, ref: ref, reason: picks.reasons[ref.id])
        }
    }

    /// Sleeves for the now-playing card and the first screen of the list, decoded at the card's size
    /// so the list rows share the thumbnail. Bounded by `timeout`: a slow CDN delays the reveal, it
    /// does not hold it, and anything still in flight lands in the cache for the rows to pick up.
    @MainActor
    private func prefetchGroupPlaylistArtwork(_ tracks: [GroupSessionTrack], timeout: TimeInterval) async {
        let urls = tracks.prefix(8).compactMap { $0.ref.artworkURL(side: 200) }
        guard !urls.isEmpty else { return }
        await withTaskGroup(of: Bool.self) { group in
            for url in urls {
                group.addTask { @MainActor in
                    _ = await TrackArtworkCache.image(for: url, pixelSize: 192)
                    return true
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return false
            }
            var remaining = urls.count
            while remaining > 0, let fetched = await group.next() {
                if !fetched { break }
                remaining -= 1
            }
            group.cancelAll()
        }
    }

    // MARK: Discovery through the backend

    /// Asks the backend for the seven snippets (cold-start for a resident the server does not know
    /// yet). Falls back to the bundled clips (plan stays nil) when offline or on any failure.
    func ensureDiscoveryPlan(for patientId: UUID) async {
        recommendations.discoveryPlan = nil
        guard APIConfig.isConfigured, let patient = carePatient(id: patientId) else { return }
        let plan: DiscoveryPlan?
        if patient.isProvisional || newResidentDiscoveryPatientId == patientId {
            plan = try? await MusicCatalogClient.coldDiscoveryPlan(age: patient.residentAgeYears, nationality: patient.nationality, favourite: patient.favouriteMusicGenre)
        } else {
            if let known = try? await MusicCatalogClient.discoveryPlan(residentId: patientId) {
                plan = known
            } else {
                plan = try? await MusicCatalogClient.coldDiscoveryPlan(age: patient.residentAgeYears, nationality: patient.nationality, favourite: patient.favouriteMusicGenre)
            }
        }
        guard let plan, plan.snippets.count >= 3, discoverySnippetIndex == 0 else { return }
        recommendations.discoveryPlan = plan
        StreamAudioCache.prefetch(plan.snippets.prefix(2).map(\.audioURL))
        SceneImageCache.prefetch(plan.snippets.prefix(2).compactMap { $0.artworkURL(side: 1200) })
    }

    /// Number of snippets in the current pass (plan or bundled).
    var discoverySnippetTotal: Int {
        recommendations.discoveryPlan?.snippets.count ?? DiscoveryFlowPOC.snippetCount
    }

    /// Sends the faces tapped to the backend and writes its playlists into the resident; offline the
    /// existing heuristic has already run. Called once per pass by `commitDiscoverySnippetSlice`.
    func finishDiscoveryOnline(for patientId: UUID, plan: DiscoveryPlan) async {
        guard let patient = carePatient(id: patientId) else { return }
        let picks = discoveryResults.compactMap { result -> MusicCatalogClient.Pick? in
            guard let trackId = result.trackId else { return nil }
            let sentiment: String
            switch result.sentiment {
            case .unpleasant: sentiment = "red"
            case .neutral: sentiment = "amber"
            case .pleasant: sentiment = "green"
            }
            return MusicCatalogClient.Pick(trackId: trackId, sentiment: sentiment)
        }
        let outcome: DiscoveryOutcome?
        if patient.isProvisional || newResidentDiscoveryPatientId == patientId {
            outcome = try? await MusicCatalogClient.coldDiscoveryResults(age: patient.residentAgeYears, nationality: patient.nationality, favourite: patient.favouriteMusicGenre, picks: picks)
            // Re-sent as a signals batch once the resident has been saved and pushed.
            let events = picks.map { SignalBatch.Event(kind: "discoveryPick", at: Date(), trackId: $0.trackId, genre: nil, value: nil, sentiment: $0.sentiment, frustrated: nil) }
            MainActor.assumeIsolated {
                sync.enqueueSignals(residentId: patientId, batch: SignalBatch(batchId: UUID(), sessionId: nil, deviceId: AuthSession.deviceId, at: Date(), events: events))
            }
        } else {
            outcome = try? await MusicCatalogClient.discoveryResults(residentId: patientId, planId: plan.planId, picks: picks)
        }
        guard let outcome else {
            // Backend unavailable at the end of the pass: keep the on-device heuristic's result.
            if let ix = carePatients.firstIndex(where: { $0.id == patientId }) {
                var fallback = carePatients[ix]
                DiscoveryPlaylistTuning.applyDiscoveryResults(discoveryResults, to: &fallback)
                carePatients[ix] = fallback
            }
            return
        }
        apply(outcome, to: patientId)
    }

    private func apply(_ outcome: DiscoveryOutcome, to patientId: UUID) {
        recommendations.store(queues: outcome.surfaceQueues, for: patientId)
        guard let ix = carePatients.firstIndex(where: { $0.id == patientId }) else { return }
        var patients = carePatients
        var patient = patients[ix]
        var groups: [CareGenrePlaylistGroup] = []
        for queue in outcome.profilePlaylists {
            let refs = queue.refs
            guard !refs.isEmpty else { continue }
            let entry = CarePlaylistEntry(
                id: UUID(),
                title: "Discovery · \(queue.genre.accessibilityLabel)",
                trackCount: refs.count,
                durationMinutes: refs.count * 3,
                trackTitles: refs.map(\.title),
                tracks: refs
            )
            // Keep any family/staff picks already filed under this genre.
            let kept = patient.genrePlaylistGroups.first(where: { $0.genre == queue.genre })?.playlists.filter { $0.title.hasPrefix("Family & staff picks") } ?? []
            groups.append(CareGenrePlaylistGroup(genre: queue.genre, playlists: [entry] + kept))
        }
        if !groups.isEmpty {
            patient.genrePlaylistGroups = groups
            patient.favouriteMusicGenre = outcome.taste.favourite
        }
        patients[ix] = patient
        carePatients = patients
    }

    // MARK: Listening signals (one batch per calm-surface session)

    func enqueueListeningSignals(from metrics: ResidentSurfaceSessionMetrics, patientId: UUID) {
        guard APIConfig.isConfigured else { return }
        let now = Date()
        var events: [SignalBatch.Event] = []
        func trackId(_ title: String) -> String? { metrics.trackIdsByTitle[title] }
        func genre(_ title: String) -> ResidentMusicGenre? { ResidentPlaybackTrackCatalog.primaryGenre(for: title) }
        for (title, count) in metrics.trackLikeCounts {
            for _ in 0 ..< count { events.append(.init(kind: "sunLike", at: now, trackId: trackId(title), genre: genre(title), value: nil, sentiment: nil, frustrated: nil)) }
        }
        for title in metrics.skippedTrackTitles {
            events.append(.init(kind: "cloudSkip", at: now, trackId: trackId(title), genre: genre(title), value: Double(metrics.skipSecondsByTitle[title] ?? 10), sentiment: nil, frustrated: nil))
        }
        for (title, seconds) in metrics.trackListenSeconds where seconds >= 20 {
            events.append(.init(kind: "dwell", at: now, trackId: trackId(title), genre: genre(title), value: Double(seconds), sentiment: nil, frustrated: nil))
        }
        for (label, count) in metrics.intentionalGenrePlayCounts {
            guard let g = ResidentMusicGenre.allCases.first(where: { $0.accessibilityLabel == label }) else { continue }
            for _ in 0 ..< count { events.append(.init(kind: "genreTap", at: now, trackId: nil, genre: g, value: nil, sentiment: nil, frustrated: nil)) }
        }
        for id in metrics.previewFailedTrackIds {
            events.append(.init(kind: "previewFailed", at: now, trackId: id, genre: nil, value: nil, sentiment: nil, frustrated: nil))
        }
        // Grow the catalogue around what they sun-liked (at most two artists per session), then
        // refresh the queues so the next session already offers the similar songs.
        let likedArtists = Array(Set(metrics.trackLikeCounts.keys.compactMap { metrics.trackArtistsByTitle[$0] })).sorted().prefix(2)
        if !likedArtists.isEmpty {
            Task { @MainActor in
                await expandCatalogue(aroundArtists: Array(likedArtists))
                await refreshRecommendations(for: patientId)
            }
        }
        guard !events.isEmpty else { return }
        let batch = SignalBatch(batchId: UUID(), sessionId: nil, deviceId: AuthSession.deviceId, at: now, events: events)
        MainActor.assumeIsolated { sync.enqueueSignals(residentId: patientId, batch: batch) }
    }
}
