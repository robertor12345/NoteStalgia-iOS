import SwiftUI

// MARK: - Fast load — brief interstitial (~1s), subtle AI lines

struct ProcessingFastView: View {
    @ObservedObject var state: SessionPOCState
    @State private var tick = 0
    private let messages = [
        "Finding the right tone…",
        "Letting the sound soften…",
        "Letting movement match your breath…",
    ]

    var body: some View {
        ScreenFadeIn {
            Group {
                if state.isResidentSession {
                    VStack(spacing: 28) {
                        Spacer(minLength: 80)
                        BreathingCalmProgressView(diameter: 72)
                        Spacer()
                    }
                } else {
                    CenteredScrollScreen {
                        VStack(spacing: 28) {
                            if state.isCareStaffSession, let p = state.carePatient(id: state.activeCarePatientId) {
                                Text("With \(p.displayName)")
                                    .font(BrandTheme.orbHintFont())
                                    .orbOverlayText(muted: true)
                            }

                            BreathingCalmProgressView(diameter: 72)

                            Text(messages[tick % messages.count])
                                .font(BrandTheme.orbLineFont())
                                .multilineTextAlignment(.center)
                                .orbOverlayText()
                                .padding(.horizontal)
                                .animation(.easeInOut(duration: 0.45), value: tick)
                                .id(tick)
                        }
                        .padding(.vertical, 28)
                    }
                }
            }
        }
        .task {
            let totalSeconds: Double = 3.2 / 3
            let steps = messages.count
            let per = UInt64((totalSeconds / Double(steps)) * 1_000_000_000)
            for i in 0..<steps {
                tick = i
                try? await Task.sleep(nanoseconds: per)
            }
            tick = steps - 1
            try? await Task.sleep(nanoseconds: UInt64(Double(200_000_000) / 3))
            state.phase = .immersive
        }
    }
}

// MARK: - Immersive — real-time adaptation

struct ImmersiveSessionView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.flowContainerSize) private var flowContainerSize
    @Environment(\.flowOrbShellSize) private var flowOrbShellSize
    @StateObject private var ambientAudio = AmbientAudioSession()
    @State private var hrTimer: Timer?
    @State private var holdsFullPageCover = false

    private var orbSize: CGSize {
        if flowOrbShellSize.width > 1, flowOrbShellSize.height > 1 {
            return flowOrbShellSize
        }
        return BrandLayout.discoveryPanelSize(in: flowContainerSize)
    }

    var body: some View {
        ZStack {
            if state.isResidentSession {
                OrbInteriorMediaPanel(orbSize: orbSize) {
                    NatureVideoCompilationView(
                        mediaSessionID: state.immersiveMediaSessionID,
                        photoAnchored: state.sessionAnchoredWithPhoto
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.animation(.easeInOut(duration: 0.55)))
            } else {
                NatureVideoCompilationView(
                    mediaSessionID: state.immersiveMediaSessionID,
                    photoAnchored: state.sessionAnchoredWithPhoto
                )

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.14), location: 0),
                        .init(color: .clear, location: 0.38),
                        .init(color: .clear, location: 0.62),
                        .init(color: .black.opacity(0.22), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                HStack {
                    OrbIconNavButton(
                        systemImage: ambientAudio.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        accessibilityLabel: ambientAudio.isMuted ? "Unmute audio" : "Mute audio",
                        diameter: 44
                    ) {
                        ambientAudio.isMuted.toggle()
                    }
                    .accessibilityIdentifier("immersive.mute")
                    Spacer()
                }
                .padding(.horizontal, BrandTheme.contentGutter)
                .padding(.top, 8)

                Spacer()

                if !state.isResidentSession {
                    ImmersiveVitalsReadout(vitals: state.vitals)
                        .frame(maxWidth: BrandLayout.isRegularWidth(horizontalSizeClass) ? BrandLayout.menuColumnMaxWidth : .infinity)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

                    SessionBottomConfigMenu(state: state)
                        .padding(.horizontal, BrandTheme.contentGutter)
                        .padding(.top, 10)

                    PrimaryButton(title: "End session") {
                        state.finishSessionWithSettling()
                    }
                    .accessibilityIdentifier("immersive.end")
                    .padding(.horizontal, BrandTheme.contentGutter)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    .safeAreaPadding(.bottom, 16)
                } else {
                    Spacer()
                    OrbIconNavButton(
                        systemImage: "square.grid.2x2.fill",
                        accessibilityLabel: "Return to playlists",
                        diameter: 58
                    ) {
                        state.finishSessionWithSettling()
                    }
                    .accessibilityIdentifier("immersive.returnToPlaylists")
                    .padding(.horizontal, BrandTheme.contentGutter)
                    .padding(.bottom, 28)
                    .safeAreaPadding(.bottom, 16)
                }
            }
            .onAppear {
                ambientAudio.volumeMultiplier = 1
                // Distinct Mixkit reel + ambient stream when session is photo-anchored vs Quick Start.
                ambientAudio.startFresh(photoAnchored: state.sessionAnchoredWithPhoto)
                hrTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 1.0)) {
                        // Mutate the vitals store directly — `ImmersiveVitalsReadout` observes it
                        // alone, so this 1.2s tick only invalidates that small readout, not the
                        // rest of this screen (video backdrop, config menu chrome, etc.).
                        let vitals = state.vitals
                        vitals.mockHeartRateCurrent = max(58, vitals.mockHeartRateCurrent - Double.random(in: 0.2 ... 0.8))
                    }
                }
            }
        }
        .onAppear {
            // The staff branch is covered edge-to-edge by the video, its loading poster or the
            // offline fallback — all opaque — so the orb + sparkles behind it are invisible for the
            // whole session. Pause their draw loops; nothing on screen changes.
            if !state.isResidentSession { setFullPageCover(true) }
        }
        .onChange(of: state.phaseContentVisible) { _, visible in
            // Release as the screen starts fading out so the shell is already moving when the
            // next screen appears.
            if !visible { setFullPageCover(false) }
        }
        .onDisappear {
            hrTimer?.invalidate()
            hrTimer = nil
            ambientAudio.stop()
            setFullPageCover(false)
        }
    }

    private func setFullPageCover(_ covers: Bool) {
        guard covers != holdsFullPageCover else { return }
        holdsFullPageCover = covers
        if covers {
            AmbientInteractionPause.beginFullPageCover()
        } else {
            AmbientInteractionPause.endFullPageCover()
        }
    }
}

/// HR/Calm readout — observes only `ImmersiveSessionVitalsStore`, not the full `SessionPOCState`,
/// so the 1.2s heart-rate tick only re-renders this small card instead of all of `ImmersiveSessionView`.
private struct ImmersiveVitalsReadout: View {
    @ObservedObject var vitals: ImmersiveSessionVitalsStore

    var body: some View {
        VStack(spacing: 12) {
            Text("Music · nature video · heart rate")
                .font(.caption2)
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("HR")
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.textSecondary)
                    Text("\(Int(vitals.mockHeartRateCurrent))")
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(BrandTheme.textPrimary)
                }
                VStack(spacing: 4) {
                    Text("Calm")
                        .font(.caption2)
                        .foregroundStyle(BrandTheme.textSecondary)
                    Text("\(Int(vitals.calmScore * 100))%")
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(BrandTheme.textPrimary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
            )
        }
    }
}
