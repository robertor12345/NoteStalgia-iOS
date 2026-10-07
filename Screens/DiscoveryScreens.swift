import SwiftUI

// MARK: - Discovery calibration (timed snippets + traffic-light smileys — no readable copy for participants)

struct DiscoveryCalibrationView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.flowContainerSize) private var flowContainerSize
    @Environment(\.flowOrbShellSize) private var flowOrbShellSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var audio = AmbientAudioSession()
    @State private var sliceStartedAt = Date()
    @State private var sliceDeadlineTask: Task<Void, Never>?
    @State private var clipContentOpacity = 0.0
    /// Cancels superseded fade runs when snippets advance quickly (tap vs timer).
    @State private var clipFadeNonce: UInt = 0
    @State private var affirmationGlowTick: UInt = 0
    /// Bumps snippet after tap: 2s listen + affirmation glow (~0.4s) → commit.
    @State private var postPickAdvanceTask: Task<Void, Never>?
    @State private var discoveryCompletionExitTask: Task<Void, Never>?
    @State private var isClipPlaybackActive = false

    private let clipFadeOut: TimeInterval = 0.20
    private let clipFadeIn: TimeInterval = 0.24

    private var orbSize: CGSize {
        if flowOrbShellSize.width > 1, flowOrbShellSize.height > 1 {
            return flowOrbShellSize
        }
        return BrandLayout.discoveryPanelSize(in: flowContainerSize)
    }

    var body: some View {
        ZStack {
            ScreenFadeIn {
                ZStack {
                    DiscoveryEraListeningOrb(
                        snippetIndex: state.discoveryPhysicalSnippetIndex(logicalIndex: state.discoverySnippetIndex),
                        orbSize: orbSize,
                        pendingPick: state.discoveryPendingPick,
                        affirmationGlowTick: affirmationGlowTick,
                        isClipPlaybackActive: isClipPlaybackActive,
                        onSelectMood: { mood in
                            advanceToNextDiscoveryClip(selected: mood)
                        }
                    )
                    .opacity(clipContentOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack {
                FlowTopBackBar(
                    accessibilityLabel: state.newResidentDiscoveryPatientId != nil ? "Back to roster" : "Back to profile",
                    onLogout: { state.signOutSupervisor() },
                    action: { state.abandonDiscoveryCalibration() }
                )
                Spacer(minLength: 0)
            }
            .zIndex(20)
        }
        .onAppear {
            audio.volumeMultiplier = 1.12
            audio.musicReactiveProfile = .discovery
            clipFadeNonce = 0
            clipContentOpacity = 0
            StreamAudioCache.prefetchDiscoveryUpcoming(
                from: state.discoverySnippetIndex,
                order: state.discoverySnippetOrder
            )
            SceneImageCache.prefetchDiscoveryUpcoming(
                from: state.discoverySnippetIndex,
                order: state.discoverySnippetOrder
            )
            Task { await runDiscoveryClipTransition(skipFadeOut: true) }
        }
        .onChange(of: state.discoverySnippetIndex) { _, newIdx in
            if newIdx >= DiscoveryFlowPOC.snippetCount {
                scheduleDiscoveryCompletionExitSequence()
            } else {
                StreamAudioCache.prefetchDiscoveryUpcoming(
                    from: newIdx,
                    order: state.discoverySnippetOrder
                )
                SceneImageCache.prefetchDiscoveryUpcoming(
                    from: newIdx,
                    order: state.discoverySnippetOrder
                )
                Task { await runDiscoveryClipTransition(skipFadeOut: false) }
            }
        }
        .onChange(of: state.phase) { _, phase in
            if phase != .careDiscoveryCalibration {
                isClipPlaybackActive = false
                audio.musicReactiveProfile = .standard
                cancelPostPickAdvance()
                discoveryCompletionExitTask?.cancel()
                discoveryCompletionExitTask = nil
                sliceDeadlineTask?.cancel()
                sliceDeadlineTask = nil
                audio.stop()
            }
        }
        .onDisappear {
            isClipPlaybackActive = false
            cancelPostPickAdvance()
            discoveryCompletionExitTask?.cancel()
            discoveryCompletionExitTask = nil
            sliceDeadlineTask?.cancel()
            sliceDeadlineTask = nil
            audio.volumeMultiplier = 1
            audio.musicReactiveProfile = .standard
            audio.stop()
        }
    }

    /// After tap: mood shows as selected immediately; streamed clip keeps playing ~2s, then affirmation glow fires, then snippet commits and cross-fades to the next clip.
    private func advanceToNextDiscoveryClip(selected mood: DiscoveryTrafficSentiment) {
        guard state.phase == .careDiscoveryCalibration else { return }
        guard state.discoverySnippetIndex < DiscoveryFlowPOC.snippetCount else { return }
        cancelPostPickAdvance()
        sliceDeadlineTask?.cancel()
        sliceDeadlineTask = nil
        state.setDiscoveryPick(mood)
        let moodCapt = mood
        let idxCapt = state.discoverySnippetIndex
        postPickAdvanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 520_000_000)
            guard !Task.isCancelled else { return }
            guard state.phase == .careDiscoveryCalibration else { return }
            guard state.discoverySnippetIndex == idxCapt else { return }
            guard state.discoveryPendingPick == moodCapt else { return }
            affirmationGlowTick += 1
            try? await Task.sleep(nanoseconds: 140_000_000)
            guard !Task.isCancelled else { return }
            guard state.phase == .careDiscoveryCalibration else { return }
            guard state.discoverySnippetIndex == idxCapt else { return }
            guard state.discoveryPendingPick == moodCapt else { return }
            state.commitDiscoverySnippetSlice()
        }
    }

    private func cancelPostPickAdvance() {
        postPickAdvanceTask?.cancel()
        postPickAdvanceTask = nil
    }

    /// Discovery is complete in `state` (tuning already applied). Fade out, then open the resident playlist surface.
    private func scheduleDiscoveryCompletionExitSequence() {
        discoveryCompletionExitTask?.cancel()
        let prefersReducedMotion = reduceMotion
        discoveryCompletionExitTask = Task { @MainActor in
            guard state.phase == .careDiscoveryCalibration else { return }
            guard state.discoverySnippetIndex >= DiscoveryFlowPOC.snippetCount else { return }

            sliceDeadlineTask?.cancel()
            sliceDeadlineTask = nil
            cancelPostPickAdvance()
            isClipPlaybackActive = false
            audio.stop()

            let contentFade = prefersReducedMotion ? 0.20 : 0.26
            withAnimation(.easeOut(duration: contentFade)) {
                clipContentOpacity = 0
            }
            try? await Task.sleep(nanoseconds: UInt64((contentFade + 0.04) * 1_000_000_000.0))
            guard !Task.isCancelled else { return }
            guard state.phase == .careDiscoveryCalibration else { return }

            state.openResidentProfile()
        }
    }

    /// Cross-fades the equalizer + mood row between clips (`skipFadeOut` for first paint).
    @MainActor
    private func runDiscoveryClipTransition(skipFadeOut: Bool) async {
        clipFadeNonce += 1
        let token = clipFadeNonce

        guard state.phase == .careDiscoveryCalibration else {
            clipContentOpacity = 1
            return
        }
        guard state.discoverySnippetIndex < DiscoveryFlowPOC.snippetCount else {
            clipContentOpacity = 1
            return
        }

        if !skipFadeOut {
            isClipPlaybackActive = false
            withAnimation(.easeOut(duration: clipFadeOut)) {
                clipContentOpacity = 0
            }
            let ns = UInt64((clipFadeOut * 1000 + 35) * 1_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard token == clipFadeNonce else { return }
            guard state.phase == .careDiscoveryCalibration else { return }
            guard state.discoverySnippetIndex < DiscoveryFlowPOC.snippetCount else {
                clipContentOpacity = 1
                return
            }
        }

        beginSlice(resetStartTime: true)

        guard token == clipFadeNonce else { return }
        withAnimation(.easeIn(duration: clipFadeIn)) {
            clipContentOpacity = 1
        }
    }

    private func beginSlice(resetStartTime: Bool) {
        sliceDeadlineTask?.cancel()
        sliceDeadlineTask = nil

        guard state.phase == .careDiscoveryCalibration else { return }
        guard state.discoverySnippetIndex < DiscoveryFlowPOC.snippetCount else { return }

        if resetStartTime {
            sliceStartedAt = Date()
        }

        let idxCapt = state.discoverySnippetIndex

        audio.startFresh(streamURL: DiscoveryFlowPOC.snippetAudioStreamURL(
            snippetIndex: idxCapt,
            order: state.discoverySnippetOrder.isEmpty ? nil : state.discoverySnippetOrder
        ))
        isClipPlaybackActive = true

        sliceDeadlineTask = Task { @MainActor in
            let ns = UInt64(DiscoveryFlowPOC.snippetDurationSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            guard state.phase == .careDiscoveryCalibration else { return }
            guard state.discoverySnippetIndex == idxCapt else { return }
            isClipPlaybackActive = false
            audio.stop()
            state.commitDiscoverySnippetSlice()
        }
    }
}

// MARK: - Era listening panel (archival media + radial bar equalizer + centered mood faces)

private struct DiscoveryEraListeningOrb: View {
    let snippetIndex: Int
    let orbSize: CGSize
    let pendingPick: DiscoveryTrafficSentiment?
    let affirmationGlowTick: UInt
    var isClipPlaybackActive: Bool
    var onSelectMood: (DiscoveryTrafficSentiment) -> Void

    @StateObject private var videoLooper = DiscoverySnippetVideoLooper()
    @State private var eraMediaReady = false
    /// Set when the era still/clip hasn't arrived within `mediaReadyTimeout` — the shimmer gives way
    /// to a mood-coloured fallback with the genre artwork, so an offline iPad never shimmers forever.
    @State private var mediaTimedOut = false
    private let mediaReadyTimeout: TimeInterval = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.flowOrbPulseAnchor) private var flowOrbPulseAnchor
    @Environment(\.flowPanelPulseIntensity) private var flowPanelPulseIntensity
    @Environment(\.flowPanelPulseSpeed) private var flowPanelPulseSpeed
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var pulseAnchor: Date {
        flowOrbPulseAnchor == .distantPast ? Date() : flowOrbPulseAnchor
    }

    private var visual: DiscoverySnippetEraVisual {
        DiscoveryEraMediaCatalog.visual(for: snippetIndex)
    }

    private var visualMood: MusicVisualMood {
        DiscoveryEraMediaCatalog.mood(for: snippetIndex)
    }

    private var faceDiameter: CGFloat {
        min(min(orbSize.width, orbSize.height) * 0.18, BrandLayout.discoveryFaceDiameterCap(for: horizontalSizeClass) * 0.92)
    }

    private var visualsArePlaying: Bool {
        guard eraMediaReady else { return false }
        guard visual.videoURL != nil else { return true }
        return videoLooper.player.rate > 0
    }

    /// Read inside the 60fps tick (not observed): subscribing to the bus here re-rendered this whole
    /// orb — media, gradients, three faces — up to 48 extra times a second on top of the timeline.
    private var showEqualizer: Bool {
        isClipPlaybackActive && visualsArePlaying && MusicReactiveBus.shared.snapshot.isActive
    }

    var body: some View {
        let coreDiameter = min(orbSize.width, orbSize.height)
        let barCanvas = OrbRadialBarEqualizerView.canvasDiameter(for: coreDiameter)
        TimelineView(.animation(minimumInterval: 1 / OrbRenderBudget.contentFramesPerSecond, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(pulseAnchor) * flowPanelPulseSpeed
            let sample = OrbPulseSample.sample(
                at: elapsed,
                mode: .calm,
                reduceMotion: reduceMotion
            )
            let contentScale = sample.shellScale
            let barOrbRadius = OrbRadialBarEqualizerView.orbRadius(for: coreDiameter) * contentScale

            ZStack {
                ZStack {
                    if !eraMediaReady {
                        if mediaTimedOut {
                            DiscoveryMediaFallbackFill(mood: visualMood, diameter: coreDiameter)
                                .frame(width: coreDiameter, height: coreDiameter)
                                .transition(.opacity)
                        } else {
                            DiscoveryMediaLoadingFill(diameter: coreDiameter)
                                .frame(width: coreDiameter, height: coreDiameter)
                                .transition(.opacity)
                        }
                    }

                    DiscoverySnippetMediaFill(
                            visual: visual,
                            player: videoLooper.player,
                            isMediaReady: $eraMediaReady
                        )
                        .frame(width: coreDiameter, height: coreDiameter)

                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.22),
                                Color.black.opacity(0.10),
                                Color.black.opacity(0.32),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    .opacity(eraMediaReady ? 1 : 0)
                    .allowsHitTesting(false)

                        // Mood colour grade so each auditioned clip reads distinctly.
                        LinearGradient(
                            colors: visualMood.tintColors.map { $0.opacity(0.30) },
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .blendMode(.softLight)
                        .opacity(eraMediaReady ? 1 : 0)
                        .allowsHitTesting(false)
                }
                .clipShape(Circle())
                .animation(.easeInOut(duration: 0.5), value: eraMediaReady)
                .animation(.easeInOut(duration: 0.5), value: mediaTimedOut)

                Circle()
                    .fill(Color.black.opacity(0.32))
                    .blur(radius: coreDiameter * 0.07)
                    .frame(width: coreDiameter * 0.58, height: coreDiameter * 0.58)
                    .allowsHitTesting(false)

                HStack(spacing: max(8, coreDiameter * 0.022)) {
                    ForEach(DiscoveryTrafficSentiment.allCases) { mood in
                        TrafficSmileyFaceButton(
                            sentiment: mood,
                            pendingPick: pendingPick,
                            affirmationGlowTick: affirmationGlowTick,
                            diameter: max(68, faceDiameter)
                        ) {
                            onSelectMood(mood)
                        }
                    }
                }
            }
            .scaleEffect(contentScale)
            .frame(width: coreDiameter, height: coreDiameter)
            .background {
                if showEqualizer {
                    OrbRadialBarEqualizerView(
                        canvasDiameter: barCanvas,
                        orbRadius: barOrbRadius,
                        visibleBarCount: OrbRadialBarEqualizerMotion.defaultBarCount,
                        listenProgress: 1,
                        reactsToMusic: true,
                        liveAudioOnly: true,
                        bandLevels: nil,
                        liveAudioGain: OrbRadialBarEqualizerView.LiveMusicTuning.liveAudioGain,
                        liveLevelExponent: OrbRadialBarEqualizerView.LiveMusicTuning.liveLevelExponent,
                        barAmplitudeFloor: OrbRadialBarEqualizerView.LiveMusicTuning.barAmplitudeFloor,
                        barReach: OrbRadialBarEqualizerView.LiveMusicTuning.barReach,
                        neighbourMix: OrbRadialBarEqualizerView.LiveMusicTuning.neighbourMix
                    )
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Music equalizer")
                }
            }
            .animation(CalmMotion.subtle, value: showEqualizer)
        }
        .frame(width: coreDiameter, height: coreDiameter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Listening clip from \(visual.eraYear)")
        .accessibilityValue(visual.eraEvent)
        .onAppear {
            if !SceneImageCache.isCached(visual.posterImageURL) {
                eraMediaReady = false
            }
            restartEraVideo()
            SceneImageCache.prefetch(visual.posterImageURL)
        }
        .onChange(of: snippetIndex) { _, _ in
            // Keep the prior still until the next cached image is ready — only blank when cold.
            if !SceneImageCache.isCached(visual.posterImageURL) {
                eraMediaReady = false
            }
            restartEraVideo()
            SceneImageCache.prefetch(visual.posterImageURL)
        }
        .onDisappear {
            videoLooper.stop()
        }
        // Restarts per clip; cancelled with the view. Only fires if the media is still cold.
        .task(id: snippetIndex) {
            mediaTimedOut = false
            try? await Task.sleep(for: .seconds(mediaReadyTimeout))
            guard !Task.isCancelled, !eraMediaReady else { return }
            mediaTimedOut = true
        }
        .onChange(of: eraMediaReady) { _, ready in
            if ready { mediaTimedOut = false }
        }
    }

    private func restartEraVideo() {
        guard snippetIndex < DiscoveryFlowPOC.snippetCount else {
            videoLooper.stop()
            return
        }
        let urls = visual.videoURLs
        guard urls.isEmpty == false else {
            videoLooper.stop()
            return
        }
        videoLooper.play(urls: urls)
    }
}

/// Warm placeholder inside the listening orb while the streamed era poster/clip buffers, so the
/// interior reads as "warming up" rather than an empty black disc. Kept subtle so it doesn't
/// compete with the smiley faces layered on top.
private struct DiscoveryMediaLoadingFill: View {
    let diameter: CGFloat
    @State private var shimmer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RadialGradient(
            colors: [
                BrandTheme.gold.opacity(0.16),
                BrandTheme.goldDeep.opacity(0.12),
                Color(red: 0.10, green: 0.09, blue: 0.14).opacity(0.55),
            ],
            center: .center,
            startRadius: diameter * 0.04,
            endRadius: diameter * 0.62
        )
        .opacity(shimmer ? 0.9 : 0.62)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// Fallback interior when the era media never arrives: the mood's colour grade over the dark base,
/// with the genre's designer artwork ghosted in the centre so the orb still says what is playing.
/// The smiley faces stay layered on top as usual.
private struct DiscoveryMediaFallbackFill: View {
    let mood: MusicVisualMood
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.09, blue: 0.14)
            LinearGradient(
                colors: mood.tintColors.map { $0.opacity(0.55) },
                startPoint: .top,
                endPoint: .bottom
            )
            if let artwork = Self.genreArtwork(for: mood) {
                Image(artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter * 0.5, height: diameter * 0.5)
                    .clipShape(Circle())
                    .opacity(0.35)
            }
        }
        .accessibilityHidden(true)
    }

    private static func genreArtwork(for mood: MusicVisualMood) -> String? {
        switch mood {
        case .jazzNightclub: return ResidentMusicGenre.jazz.artworkAssetName
        case .classicalBallroom: return ResidentMusicGenre.classical.artworkAssetName
        case .popDanceParty: return ResidentMusicGenre.pop.artworkAssetName
        case .rockEnergetic: return ResidentMusicGenre.rock.artworkAssetName
        case .countryAmericana: return ResidentMusicGenre.country.artworkAssetName
        case .soulSmooth: return ResidentMusicGenre.soul.artworkAssetName
        case .gospelUplift: return ResidentMusicGenre.gospel.artworkAssetName
        case .nostalgic, .openRoad, .ambientCalm: return nil
        }
    }
}

// MARK: - Traffic smiles (minimal)

private struct TrafficSmileyFaceButton: View {
    let sentiment: DiscoveryTrafficSentiment
    let pendingPick: DiscoveryTrafficSentiment?
    let affirmationGlowTick: UInt
    var diameter: CGFloat = 96
    var action: () -> Void

    private var faceSize: CGFloat { diameter * 0.76 }
    private var ringSize: CGFloat { diameter * 0.94 }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressPopScale: CGFloat = 1
    @State private var glowBurst: CGFloat = 0

    /// Transient press / affirmation bloom only — never a persistent selected look.
    private var luminousLevel: CGFloat {
        glowBurst > 0.01 ? glowBurst : 0.42
    }

    var body: some View {
        Button {
            CalmExperienceFeedback.discoveryPick()
            action()
            triggerInstantPressFlash()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                sentiment.ringColor.opacity(0.38 * luminousLevel + 0.12),
                                BrandTheme.logoCyan.opacity(0.22 * luminousLevel),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: ringSize * 0.72
                        )
                    )
                    .frame(width: ringSize * (1.08 + luminousLevel * 0.18), height: ringSize * (1.08 + luminousLevel * 0.18))
                    .blur(radius: 6 + luminousLevel * 16)

                Circle()
                    .strokeBorder(
                        sentiment.ringColor.opacity(0.35 + luminousLevel * 0.55),
                        lineWidth: 2.5 + luminousLevel * 24
                    )
                    .frame(width: ringSize * (1.02 + luminousLevel * 0.1), height: ringSize * (1.02 + luminousLevel * 0.1))
                    .blur(radius: luminousLevel * 14)

                MinimalTrafficFace(sentiment: sentiment)
                    .frame(width: faceSize, height: faceSize)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.18 + luminousLevel * 0.12),
                                        sentiment.ringColor.opacity(0.58),
                                        sentiment.ringColor.opacity(0.82),
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: faceSize * 0.58
                                )
                            )
                            .overlay(
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.88 + luminousLevel * 0.12),
                                            sentiment.ringColor.opacity(0.72 + luminousLevel * 0.28),
                                            BrandTheme.logoCyan.opacity(0.45 + luminousLevel * 0.35),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.4 + luminousLevel * 2.2
                                )
                            )
                            .shadow(color: sentiment.ringColor.opacity(0.28 + luminousLevel * 0.62), radius: 8 + luminousLevel * 36)
                            .shadow(color: BrandTheme.logoCyan.opacity(0.22 + luminousLevel * 0.48), radius: 6 + luminousLevel * 28)
                            .shadow(color: .white.opacity(luminousLevel * 0.35), radius: 4 + luminousLevel * 12)
                    )
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(pressPopScale)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .onChange(of: affirmationGlowTick) { _, _ in
            guard pendingPick == sentiment else { return }
            playAffirmationGlow()
        }
        .accessibilityLabel(sentiment.accessibilitySummary + " mood")
        .accessibilityIdentifier("discovery.face.\(sentiment.accessibilitySummary.lowercased())")
        .accessibilityHint("Confirms mood. The next clip follows a short pause with a bright ring on your choice.")
    }

    private func triggerInstantPressFlash() {
        glowBurst = 1.32
        pressPopScale = 1.12
        if reduceMotion {
            pressPopScale = 1.05
            glowBurst = 1.08
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                glowBurst = 0
                pressPopScale = 1
            }
            return
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 55_000_000)
            withAnimation(.easeOut(duration: 0.10)) {
                glowBurst = 0
                pressPopScale = 1.03
            }
            try? await Task.sleep(nanoseconds: 65_000_000)
            withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
                pressPopScale = 1
            }
        }
    }

    private func playAffirmationGlow() {
        glowBurst = 1.35
        if reduceMotion {
            withAnimation(.linear(duration: 0.08)) { glowBurst = 1.1 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeOut(duration: 0.18)) { glowBurst = 0 }
            }
            return
        }
        withAnimation(.linear(duration: 0.06)) { glowBurst = 1.35 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeOut(duration: 0.16)) {
                glowBurst = 0
            }
        }
    }
}

private extension DiscoveryTrafficSentiment {
    /// Face disc border / emphasis (traffic colours).
    var ringColor: Color {
        switch self {
        case .unpleasant:
            Color(red: 0.92, green: 0.24, blue: 0.22)
        case .neutral:
            Color(red: 1.0, green: 0.72, blue: 0.16)
        case .pleasant:
            Color(red: 0.24, green: 0.72, blue: 0.38)
        }
    }

    /// Saturated traffic-light disc behind white face glyphs.
    var faceBackdrop: Color {
        ringColor.opacity(0.72)
    }
}

private struct MinimalTrafficFace: View {
    let sentiment: DiscoveryTrafficSentiment

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            sentiment.ringColor.opacity(0.88),
                            sentiment.ringColor.opacity(0.68),
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 80
                    )
                )

            MinimalFaceGlyph(sentiment: sentiment)
        }
    }
}

private struct MinimalFaceGlyph: View {
    let sentiment: DiscoveryTrafficSentiment

    private var mouthKind: DiscoveryMouthShape.MouthKind {
        switch sentiment {
        case .unpleasant: return .frown
        case .neutral: return .flat
        case .pleasant: return .smile
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let eyeR = w * 0.062

            ZStack {
                HStack(spacing: w * 0.28) {
                    Circle()
                        .fill(Color.white)
                        .overlay(
                            Circle()
                                .strokeBorder(sentiment.ringColor.opacity(0.55), lineWidth: 1.4)
                        )
                        .frame(width: eyeR * 2, height: eyeR * 2)
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                    Circle()
                        .fill(Color.white)
                        .overlay(
                            Circle()
                                .strokeBorder(sentiment.ringColor.opacity(0.55), lineWidth: 1.4)
                        )
                        .frame(width: eyeR * 2, height: eyeR * 2)
                        .shadow(color: .black.opacity(0.22), radius: 1, y: 0.5)
                }
                .offset(y: -h * 0.12)

                DiscoveryMouthShape(kind: mouthKind)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: sentiment.ringColor.opacity(0.65), radius: 2, y: 1)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, y: 0.5)
                    .frame(width: w * 0.52, height: h * 0.38)
                    .offset(y: h * 0.18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Simple minimalist mouth strokes for discovery traffic faces.
private struct DiscoveryMouthShape: Shape {
    enum MouthKind { case frown, flat, smile }

    var kind: MouthKind

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let midX = rect.midX
        switch kind {
        case .flat:
            let y = rect.midY * 1.06
            p.move(to: CGPoint(x: w * 0.12, y: y))
            p.addLine(to: CGPoint(x: w * 0.88, y: y))

        case .smile:
            let yAnchor = rect.minY + rect.height * 0.35
            p.move(to: CGPoint(x: w * 0.10, y: yAnchor))
            p.addQuadCurve(to: CGPoint(x: w * 0.90, y: yAnchor), control: CGPoint(x: midX, y: rect.maxY))

        case .frown:
            let yAnchor = rect.maxY - rect.height * 0.08
            p.move(to: CGPoint(x: w * 0.10, y: yAnchor))
            p.addQuadCurve(to: CGPoint(x: w * 0.90, y: yAnchor), control: CGPoint(x: midX, y: rect.minY))
        }
        return p
    }
}
