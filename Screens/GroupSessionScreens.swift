import SwiftUI

// MARK: - Group session — traditional playlist controls for supervisors

struct GroupSessionView: View {
    @ObservedObject var state: SessionPOCState
    @StateObject private var audio = AmbientAudioSession()
    @State private var isPlaying = true

    private var tracks: [GroupSessionTrack] { state.groupSessionTracks }
    private var currentIndex: Int { state.groupSessionTrackIndex }

    private var currentTrack: GroupSessionTrack? {
        guard tracks.indices.contains(currentIndex) else { return nil }
        return tracks[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollViewportWithEdgeFade(coordinateSpace: "groupSessionScroll") {
                VStack(spacing: 22) {
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
                .animation(CalmMotion.gentle, value: currentIndex)
                .animation(CalmMotion.subtle, value: isPlaying)
            }
        }
        .onAppear {
            audio.volumeMultiplier = 1.08
            startCurrentTrack()
        }
        .onChange(of: state.groupSessionTrackIndex) { _, _ in
            startCurrentTrack()
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
                    Image(systemName: "stop.circle.fill")
                    Text("End session")
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
            .buttonStyle(ChimingPlainButtonStyle())

            FlowSmallLogoutButton {
                audio.stop()
                state.signOutSupervisor()
            }

            Spacer()

            Text("Group mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
        }
        .padding(.horizontal, BrandTheme.contentGutter)
        .padding(.top, 0)
        .padding(.bottom, 8)
    }

    private func nowPlayingCard(_ track: GroupSessionTrack) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Now playing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(track.genre.accent.opacity(0.45))
                            .frame(width: 56, height: 56)
                        Image(track.genre.artworkAssetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(track.genre.accessibilityLabel) · drawn from \(track.sourceResidentName)")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("Track \(currentIndex + 1) of \(tracks.count) · playlist compiled from resident listening data across your home.")
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private var transportControls: some View {
        HStack(spacing: 28) {
            GroupTransportButton(systemImage: "backward.fill", label: "Previous") {
                state.groupSessionPreviousTrack()
            }
            .disabled(tracks.isEmpty)

            GroupTransportButton(
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "Pause" : "Play",
                diameter: 72,
                prominent: true
            ) {
                togglePlayback()
            }
            .disabled(tracks.isEmpty)

            GroupTransportButton(systemImage: "forward.fill", label: "Next") {
                state.groupSessionNextTrack()
            }
            .disabled(tracks.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var trackList: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Group playlist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)

                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        state.groupSessionSelectTrack(at: index)
                        isPlaying = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(track.genre.artworkAssetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.body.weight(index == currentIndex ? .semibold : .regular))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                Text(track.sourceResidentName)
                                    .font(.caption2)
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
                    }
                    .buttonStyle(ChimingPlainButtonStyle())

                    if index < tracks.count - 1 {
                        Divider().opacity(0.25)
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
        guard currentTrack != nil else { return }
        audio.stop()
        audio.startFresh(photoAnchored: false)
        isPlaying = true
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
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
            }
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
            CenteredScrollScreen(
                backAccessibilityLabel: backLabel,
                onBack: handleBack,
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 24) {
                    FadeInTitle(text: "Group check-in", delay: 0)
                    FadeInLine(
                        text: "How did the room feel by the end of the session?",
                        delay: 0.06
                    )

                    if let summary = state.groupSessionDurationSummary() {
                        BrandCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Session captured")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
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
                                    TextField("Anything else about the group?", text: $state.groupSessionFeedbackDraft.note, axis: .vertical)
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
                    .disabled(currentSelection == nil)
                    .opacity(currentSelection == nil ? 0.45 : 1)
                    .animation(CalmMotion.subtle, value: currentSelection)
                    .padding(.horizontal, 24)

                    SecondaryButton(title: "Skip — back to roster") {
                        state.skipGroupSessionFeedback()
                    }
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
                    .fill(step.rawValue <= state.groupSessionFeedbackStep ? BrandTheme.gold : BrandTheme.brown.opacity(0.12))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 4)
        .animation(CalmMotion.subtle, value: state.groupSessionFeedbackStep)
    }

    private var backLabel: String {
        state.groupSessionFeedbackStep > 0 ? "Previous question" : "Skip feedback"
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
