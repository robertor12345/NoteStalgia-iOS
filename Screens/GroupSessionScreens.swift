import SwiftUI

// MARK: - Group session — traditional playlist controls for supervisors

struct GroupSessionView: View {
    @ObservedObject var state: SessionPOCState
    @StateObject private var audio = AmbientAudioSession()
    @State private var isPlaying = true
    @State private var playingTrackID: UUID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var tracks: [GroupSessionTrack] { state.groupSessionTracks }
    private var currentIndex: Int { state.groupSessionTrackIndex }
    /// From Start until the room's playlist is ready to show in one piece (about three seconds).
    private var isPreparing: Bool { state.groupSession.isPreparingGroupPlaylist }

    private var currentTrack: GroupSessionTrack? {
        guard tracks.indices.contains(currentIndex) else { return nil }
        return tracks[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if !isPreparing {
                ScrollViewportWithEdgeFade(coordinateSpace: "groupSessionScroll") {
                    VStack(spacing: 22) {
                        if let plan = state.groupSession.plannedActivity {
                            FadeInLine(
                                text: "\(plan.title) · \(plan.participantIds.count) resident\(plan.participantIds.count == 1 ? "" : "s")",
                                font: BrandTheme.orbHintFont(),
                                muted: true,
                                delay: 0.04
                            )
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .accessibilityIdentifier("group.activityLine")
                        }
                        if let track = currentTrack {
                            nowPlayingCard(track)
                            transportControls
                            trackList
                        } else {
                            FadeInLine(text: "No tracks compiled yet — add residents to the roster first.", delay: 0)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.bottom, BrandLayout.scrollEdgeFadeComfortPadding)
                    // The same centred column and side margin as every other staff page; it used to run edge to edge.
                    .frame(maxWidth: BrandLayout.menuColumnMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
                    .animation(CalmMotion.gentle, value: currentIndex)
                    .animation(CalmMotion.subtle, value: isPlaying)
                }
                .transition(.opacity.combined(with: .offset(y: 10)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The loading ring and its line sit in the middle of the screen, over the whole view (the top
        // bar stays tappable: the card has no background, so taps outside its text fall through).
        .overlay {
            if isPreparing {
                preparingCard
                    .transition(.opacity)
            }
        }
        .animation(CalmMotion.gentle, value: isPreparing)
        .onAppear {
            audio.volumeMultiplier = 1.08
            startCurrentTrack()
        }
        // Index changes and the backend's picks replacing the list both land here.
        .onChange(of: currentTrack?.id) { _, id in
            if id != playingTrackID { startCurrentTrack() }
        }
        .onDisappear {
            audio.stop()
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                audio.stop()
                state.endGroupSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPreparing ? "chevron.left.circle.fill" : "stop.circle.fill")
                    Text(isPreparing ? "Back" : "End session")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(BrandTheme.textPrimary)
                .frame(minWidth: FlowStaffNavChrome.buttonMinWidth)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(BrandTheme.cream.opacity(0.94))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(BrandTheme.gold.opacity(0.35), lineWidth: 1))
            }
            .accessibilityIdentifier("group.end")
            .buttonStyle(ChimingPlainButtonStyle())

            Spacer()

            Text("Group mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
                .orbOverlayTextStyle(intensity: 0.7)

            FlowSmallLogoutButton {
                audio.stop()
                state.signOutSupervisor()
            }
        }
        .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
        .padding(.top, 0)
        .padding(.bottom, 8)
    }

    /// Shown while `prepareGroupPlaylist` runs: the list arrives finished, songs and sleeves together.
    private var preparingCard: some View {
        VStack(spacing: 18) {
            CalmCircularLoader(diameter: 64)
                .padding(.bottom, 6)
            // Over the orb, so the text takes the overlay treatment the roster's loading line uses.
            Text("Choosing songs for the room…")
                .font(BrandTheme.orbHintFont())
                .orbOverlayText()
                .multilineTextAlignment(.center)
            Text("Ranked for everyone taking part: their ages, where they are from, the genres they respond to, and songs like the ones they love.")
                .font(.caption)
                .orbOverlayText(muted: true)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group.preparing")
    }

    private func nowPlayingCard(_ track: GroupSessionTrack) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(title: "Now playing", systemImage: "music.note")

                HStack(spacing: 14) {
                    // The sleeve for a catalogue song, the genre glyph for a bundled stem.
                    TrackArtworkView(ref: track.ref, size: 64, cornerRadius: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(track.genre.accessibilityLabel) · \(track.ref.artist.map { "\($0) · " } ?? "")for \(track.sourceResidentName)")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let reason = track.reason {
                            Label {
                                Text(reason)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.goldDeep)
                            .accessibilityIdentifier("group.reason")
                        }
                    }
                }

                Text("Track \(currentIndex + 1) of \(tracks.count) · ranked for everyone in the room: their ages, where they are from, the genres they respond to, and songs like the ones they love.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var transportControls: some View {
        HStack(spacing: 16) {
            GroupTransportButton(systemImage: "backward.fill", label: "Previous") {
                state.groupSessionPreviousTrack()
            }
            .accessibilityIdentifier("group.previous")
            .disabled(tracks.isEmpty)

            GroupTransportButton(
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "Pause" : "Play",
                diameter: 72,
                prominent: true
            ) {
                togglePlayback()
            }
            .accessibilityIdentifier("group.playPause")
            .disabled(tracks.isEmpty)

            GroupTransportButton(systemImage: "forward.fill", label: "Next") {
                state.groupSessionNextTrack()
            }
            .accessibilityIdentifier("group.next")
            .disabled(tracks.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var trackList: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(title: "Group playlist", systemImage: "list.bullet")

                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        state.groupSessionSelectTrack(at: index)
                        isPlaying = true
                    } label: {
                        HStack(spacing: 12) {
                            TrackArtworkView(ref: track.ref, size: 34, cornerRadius: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.body.weight(index == currentIndex ? .semibold : .regular))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text(track.sourceResidentName)
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                            if index == currentIndex {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.goldDeep)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("group.track.\(track.title)")
                    .accessibilityLabel("\(track.title), \(track.sourceResidentName)\(index == currentIndex ? ", now playing" : "")")
                    .accessibilityAddTraits(index == currentIndex ? .isSelected : [])
                    .buttonStyle(ChimingPlainButtonStyle())

                    if index < tracks.count - 1 {
                        BrandHairline()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func togglePlayback() {
        guard currentTrack != nil else { return }
        if isPlaying {
            audio.stop()
            isPlaying = false
        } else {
            startCurrentTrack()
        }
    }

    private func startCurrentTrack() {
        guard let track = currentTrack else { return }
        audio.stop()
        // Catalogue previews play once and move the room along; bundled stems loop as before.
        audio.logTitle = track.title
        audio.loops = track.ref.isBundled
        audio.onItemEnd = { if !track.ref.isBundled { state.groupSessionNextTrack() } }
        audio.onFailure = { state.groupSessionNextTrack() }
        audio.startFresh(streamURL: track.ref.audioURL, fallbackURL: track.ref.isBundled ? AmbientAudioSession.quickStartStreamURL : nil)
        if tracks.indices.contains(currentIndex + 1), let next = tracks[currentIndex + 1].ref.previewURL {
            StreamAudioCache.prefetch([next])
        }
        isPlaying = true
        playingTrackID = track.id
        state.markGroupTrackPlayed()
    }
}

private struct GroupTransportButton: View {
    let systemImage: String
    let label: String
    var diameter: CGFloat = 52
    var prominent: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if prominent {
                        NoteStalgiaOrbBackdrop(diameter: diameter + 8, pulse: 0.5, glowPulse: 0.62)
                    }
                    Circle()
                        .fill(prominent ? BrandTheme.goldSoft.opacity(0.55) : BrandTheme.cream.opacity(0.94))
                        .frame(width: diameter, height: diameter)
                        .overlay(
                            Circle().stroke(BrandTheme.gold.opacity(prominent ? 0.5 : 0.28), lineWidth: 1.5)
                        )
                    Image(systemName: systemImage)
                        .font(prominent ? .title2.weight(.semibold) : .body.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                }
                // One slot height for all three buttons, so "Previous", "Pause" and "Next" share a baseline.
                .frame(height: 80)
                Text(label)
                    .font(.caption.weight(.medium))
                    .orbOverlayText(muted: true)
            }
            .frame(width: 88)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Group session feedback (end of session)

struct GroupSessionFeedbackView: View {
    @ObservedObject var state: SessionPOCState
    @State private var autoAdvanceToken = 0

    private static let autoAdvanceDelay: TimeInterval = 0.42

    private var currentStep: GroupSessionFeedbackStep {
        GroupSessionFeedbackStep(rawValue: state.groupSessionFeedbackStep) ?? .morale
    }

    private var isLastStep: Bool {
        state.groupSessionFeedbackStep >= GroupSessionFeedbackStep.allCases.count - 1
    }

    private var currentSelection: Int? {
        switch currentStep {
        case .morale: return state.groupSessionFeedbackDraft.morale
        case .alertness: return state.groupSessionFeedbackDraft.alertness
        case .lucidity: return state.groupSessionFeedbackDraft.lucidity
        case .engagement: return state.groupSessionFeedbackDraft.engagement
        }
    }

    var body: some View {
        ScreenFadeIn {
            // Top-aligned: the step card grows (note field on the last step), and a centred
            // layout would slide the rating buttons out from under the carer's finger.
            CenteredScrollScreen(
                backTitle: state.groupSessionFeedbackStep > 0 ? "Back" : "Skip",
                backAccessibilityLabel: backLabel,
                onBack: handleBack,
                onLogout: { state.signOutSupervisor() },
                logoutWarning: "This check-in hasn’t been saved yet.",
                topAligned: true
            ) {
                VStack(spacing: 24) {
                    FadeInTitle(text: "Group check-in", delay: 0)
                    FadeInLine(
                        text: "How did the room feel by the end of the session?",
                        delay: 0.06
                    )

                    if let summary = state.groupSessionDurationSummary() {
                        BrandCard {
                            VStack(alignment: .leading, spacing: 12) {
                                BrandSectionHeader(title: "Session captured", systemImage: "waveform")
                                BrandInsetTile {
                                    Text(summary)
                                        .font(.body)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)
                    }

                    stepProgress

                    BrandCard {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Step \(state.groupSessionFeedbackStep + 1) of \(GroupSessionFeedbackStep.allCases.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.textSecondary)
                            Text(currentStep.title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text(currentStep.prompt)
                                .font(.body)
                                .foregroundStyle(BrandTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            SentimentScalePicker(
                                selection: state.groupSessionFeedbackBinding(for: currentStep),
                                lowCaption: currentStep.lowCaption,
                                highCaption: currentStep.highCaption,
                                onValueSelected: { _ in
                                    scheduleAutoAdvanceIfNeeded()
                                }
                            )

                            if isLastStep {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Optional note")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BrandTheme.textSecondary)
                                    TextField("Note", text: $state.groupSessionFeedbackDraft.note, prompt: BrandTheme.fieldPrompt("Anything else about the group?"), axis: .vertical)
                                    .accessibilityIdentifier("group.note")
                                        .lineLimit(1 ... 4)
                                        .font(.body)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                        .padding(12)
                                        .background(BrandTheme.creamMid.opacity(0.95))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(BrandTheme.gold.opacity(0.25), lineWidth: 1)
                                        )
                                }
                                .padding(.top, 4)

                                participantsSection
                                    .padding(.top, 6)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(state.groupSessionFeedbackStep)
                        .transition(.etherealAppear)
                    }
                    .padding(.horizontal, 4)
                    .animation(CalmMotion.gentle, value: state.groupSessionFeedbackStep)
                    .onChange(of: state.groupSessionFeedbackStep) { _, _ in
                        autoAdvanceToken += 1
                    }

                    PrimaryButton(title: isLastStep ? "Save & return to roster" : "Next") {
                        if isLastStep {
                            state.saveGroupSessionFeedback()
                            CalmExperienceFeedback.signInSuccess()
                        } else {
                            state.advanceGroupSessionFeedbackStep()
                        }
                    }
                    .accessibilityIdentifier("group.save")
                    .disabled(currentSelection == nil)
                    .opacity(currentSelection == nil ? 0.45 : 1)
                    .animation(CalmMotion.subtle, value: currentSelection)
                    .padding(.horizontal, 24)

                    SecondaryButton(title: "Skip — back to roster") {
                        state.skipGroupSessionFeedback()
                    }
                    .accessibilityIdentifier("group.skip")
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
    }

    private var stepProgress: some View {
        HStack(spacing: 8) {
            ForEach(GroupSessionFeedbackStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= state.groupSessionFeedbackStep ? BrandTheme.gold : BrandTheme.meterTrack)
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, 4)
        .animation(CalmMotion.subtle, value: state.groupSessionFeedbackStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("Step \(state.groupSessionFeedbackStep + 1) of \(GroupSessionFeedbackStep.allCases.count)")
    }

    /// Optional, on the last step: one tap per resident — engaged, unsettled, left early — so the
    /// profile line and the planner get a per-person signal, not only the room's score.
    private var participantsSection: some View {
        let participants = state.groupSessionParticipantsForCheckIn()
        return VStack(alignment: .leading, spacing: 10) {
            BrandSectionHeader(
                title: "Who stood out?",
                systemImage: "person.2",
                subtitle: "Optional. Tap a name to note engaged, unsettled or left early; tap again to change or clear."
            )
            InsightChipFlow(spacing: 8) {
                ForEach(participants) { resident in
                    participantChip(resident)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func participantChip(_ resident: CarePatientProfile) -> some View {
        let note = state.groupSessionFeedbackDraft.participantNote(for: resident.id)
        let tint = note.map(participantTint) ?? BrandTheme.textSecondary
        return Button {
            state.cycleGroupParticipantNote(for: resident.id)
        } label: {
            HStack(spacing: 6) {
                if let note {
                    Image(systemName: note.systemImage)
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(resident.displayName)
                    .font(.subheadline.weight(.medium))
                if let note {
                    Text("· \(note.label)")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(note == nil ? BrandTheme.textPrimary : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(Capsule().fill(note == nil ? BrandTheme.surfaceInset : tint.opacity(0.18)))
            .overlay(Capsule().stroke(note == nil ? BrandTheme.insetBorder : tint.opacity(0.65), lineWidth: 1))
            .expandedHitArea(vertical: 4)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel("\(resident.displayName), \(note?.label ?? "no note")")
        .accessibilityHint("Cycles engaged, unsettled, left early, then clears")
        .accessibilityIdentifier("group.participant.\(resident.displayName)")
    }

    private func participantTint(_ note: GroupParticipantState) -> Color {
        switch note {
        case .engaged: return BrandTheme.statusPositive
        case .unsettled: return BrandTheme.statusAttention
        case .leftEarly: return BrandTheme.statusCaution
        }
    }

    private var backLabel: String {
        state.groupSessionFeedbackStep > 0
            ? "Previous question"
            : "Skip feedback — saves the group session without ratings"
    }

    private func handleBack() {
        autoAdvanceToken += 1
        if state.groupSessionFeedbackStep > 0 {
            state.retreatGroupSessionFeedbackStep()
        } else {
            state.skipGroupSessionFeedback()
        }
    }

    private func scheduleAutoAdvanceIfNeeded() {
        let step = state.groupSessionFeedbackStep
        guard step < GroupSessionFeedbackStep.allCases.count - 1 else { return }
        autoAdvanceToken += 1
        let token = autoAdvanceToken
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoAdvanceDelay) {
            guard token == autoAdvanceToken, state.groupSessionFeedbackStep == step else { return }
            state.advanceGroupSessionFeedbackStep()
        }
    }
}
