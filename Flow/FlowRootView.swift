import SwiftUI
import UIKit

struct FlowRootView: View {
    @StateObject private var state = SessionPOCState()
    @State private var launchComplete = false
    @State private var launchAnchor = Date()
    @State private var launchDidFinish = false
    /// Set once `LaunchWarmUp.perform()` has run. The title screen will not dismiss (via the timer
    /// or a tap-to-skip) until this is true, so the user can never land on a cold, unwarmed login.
    @State private var warmUpComplete = false
    /// Set when the launch timer fires or the user taps to skip. The actual dismissal is deferred
    /// until `warmUpComplete` is also true.
    @State private var launchFinishRequested = false
    /// While the keyboard is up the user is typing — pause the ambient sparkle + orb nebula draw
    /// loops so their continuous main-thread rendering doesn't make form fields feel unresponsive.
    @State private var keyboardVisible = false
    /// While a staff scroll view is interacting / decelerating — freeze ambient loops so the
    /// scroll compositor gets a clean 60fps budget. Fidelity is unchanged (same particles / nebula;
    /// motion simply resumes when the scroll settles).
    @State private var scrollAmbientPaused = false

    private let launchTotalDuration: Double = 5.8

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let style = OrbNavigationStyle.forPhase(
                state.phase,
                launchActive: !launchComplete,
                isResidentSession: state.isResidentSession
            )
            let contentInset = style.resolvedContentTopInset(safeTop: safeTop)
            let shellConfig = OrbShellConfiguration.forPhase(
                state.phase,
                launchActive: !launchComplete,
                containerSize: geo.size,
                isResidentSession: state.isResidentSession
            )

            ZStack {
                BrandBackground(showSparkles: false)

                // Isolated behind an `Equatable` boundary: the sparkles + orb nebula are expensive
                // 60fps `Canvas` layers, and `FlowRootView` re-renders on every unrelated state
                // change (including each keystroke in a form field, via the coordinator's forwarded
                // `objectWillChange`). Gating on `.equatable()` means those keystroke re-renders no
                // longer re-evaluate — and thus never force a synchronous nebula redraw — as long as
                // the orb config, anchor, and keyboard state are unchanged.
                FlowAmbientBackdrop(
                    shellConfig: shellConfig,
                    anchor: launchAnchor,
                    ambientPaused: keyboardVisible || scrollAmbientPaused
                )
                .equatable()
                .zIndex(1)

                phaseLayer(contentInset: contentInset, style: style)
                    .zIndex(2)
                    .environment(\.flowContainerSize, geo.size)
                    .environment(\.flowOrbShellSize, CGSize(width: shellConfig.width, height: shellConfig.height))
                    .environment(\.flowOrbPulseAnchor, launchAnchor)
                    .environment(\.flowPanelPulseIntensity, shellConfig.panelPulseIntensity)
                    .environment(\.flowPanelPulseSpeed, shellConfig.panelPulseSpeed)

                if !launchComplete {
                    LaunchIntroOverlay(anchor: launchAnchor, totalDuration: launchTotalDuration)
                        .zIndex(8)
                }

                if state.residentHandoffActive {
                    ResidentStaffHandoffOverlay(
                        patientName: state.carePatient(id: state.selectedCarePatientId)?.displayName,
                        onComplete: { state.completeResidentHandoffTransition() }
                    )
                    .zIndex(12)
                    .transition(.opacity)
                }
            }
        }
        // Phase fades use explicit `withAnimation` in `SessionPOCState` — no root implicit
        // animation here; it breaks TimelineView + `.position()` glyph layout on the resident surface.
        // Full-screen skip tap only while the launch overlay is up — otherwise it competes with
        // resident genre glyphs and other controls.
        .modifier(LaunchSkipTapModifier(enabled: !launchComplete, onSkip: skipLaunchIfNeeded))
        .accessibilityLabel(launchComplete ? "NoteStalgia" : "NoteStalgia is starting.")
        .accessibilityHint(launchComplete ? "" : "Tap anywhere to skip.")
        .onAppear {
            launchAnchor = Date()
            state.resetAllForFreshAppLaunch()
            StreamAudioCache.prefetchLaunchEssentials()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onReceive(NotificationCenter.default.publisher(for: AmbientInteractionPause.didChangeNotification)) { note in
            scrollAmbientPaused = (note.userInfo?[AmbientInteractionPause.isPausedKey] as? Bool) ?? false
        }
        .task {
            // Let the first frame + launch animation start, then warm up the subsystems that
            // otherwise hitch the main thread on first use (keyboard, audio/chime engine, haptics)
            // while the title screen still covers the UI — so the sign-in form is responsive the
            // instant it appears.
            try? await Task.sleep(nanoseconds: 400_000_000)
            LaunchWarmUp.perform()
            warmUpComplete = true
            finishLaunchIfReady()
        }
        .task {
            try? await Task.sleep(nanoseconds: UInt64(launchTotalDuration * 1_000_000_000))
            await MainActor.run { requestFinishLaunch() }
        }
    }

    @ViewBuilder
    private func phaseLayer(contentInset: CGFloat, style: OrbNavigationStyle) -> some View {
        Group {
            switch state.phase {
            case .home:
                HomeView(state: state)
            case .entryMode:
                EntryModeView(state: state)
            case .captureMoment:
                CapturePhotoView(state: state)
            case .moodSelect:
                MoodSelectView(state: state)
            case .processingFast:
                ProcessingFastView(state: state)
            case .immersive:
                ImmersiveSessionView(state: state)
            case .insight:
                InsightView(state: state)
            case .carePatientList:
                CarePatientListView(state: state)
            case .carePatientDetail:
                CarePatientDetailView(state: state)
            case .careSessionFeedback:
                CareSessionFeedbackView(state: state)
            case .careSessionPrep:
                CareSessionPrepView(state: state)
            case .residentProfile:
                ResidentProfileView(state: state)
            case .careFaceLinkedPick:
                CarePatientListView(state: state)
            case .careDiscoveryCalibration:
                DiscoveryCalibrationView(state: state)
            case .sessionSettling:
                SessionSettlingView(state: state)
            case .careDiscoveryAgeInput:
                CareDiscoveryAgeInputView(state: state)
            case .careNewResidentProfile:
                CareNewResidentProfileView(state: state)
            case .careSessionSentimentFeedback:
                CareSessionSentimentFeedbackView(state: state)
            case .careSessionInsight:
                CareSessionInsightView(state: state)
            case .careGroupSession:
                GroupSessionView(state: state)
            case .careGroupSessionFeedback:
                GroupSessionFeedbackView(state: state)
            case .supervisorWelcome:
                SupervisorWelcomeView(state: state)
            case .careHomePicker:
                CareHomePickerView(state: state)
            case .careHomeAdminWelcome:
                CareHomeAdminWelcomeView(state: state)
            case .careHomeAdminDashboard:
                CareHomeAdminDashboardView(state: state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, contentInset)
        .orbContentMotion(
            anchor: launchAnchor,
            pulseMode: style.pulseMode,
            enabled: style.floats && style.showsMenuEnvelope
        )
        .id(state.phase)
        // Removal is instant so the previous screen never lingers behind the next one.
        // No global implicit animation here — it would interfere with screens that run their
        // own TimelineView / continuous motion (e.g. the resident calm surface glyphs).
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
        .opacity(launchComplete && state.phaseContentVisible ? 1 : 0)
        .allowsHitTesting(launchComplete && !state.residentHandoffActive && state.phaseContentVisible)
    }

    private func skipLaunchIfNeeded() {
        guard !launchComplete else { return }
        requestFinishLaunch()
    }

    /// Requests dismissal of the title screen (from the launch timer or a tap-to-skip). The screen
    /// only actually dismisses once warm-up has finished, so we never reveal a cold login form.
    private func requestFinishLaunch() {
        launchFinishRequested = true
        finishLaunchIfReady()
    }

    private func finishLaunchIfReady() {
        guard launchFinishRequested, warmUpComplete, !launchDidFinish else { return }
        launchDidFinish = true
        withAnimation(.easeInOut(duration: 0.62)) {
            launchComplete = true
        }
    }

}

/// One-time warm-up of subsystems that otherwise stutter the main thread on first use. Run behind
/// the launch title screen so the sign-in form is fully responsive the moment it appears.
@MainActor
enum LaunchWarmUp {
    private static var didRun = false

    static func perform() {
        guard !didRun else { return }
        didRun = true

        // First tap chime would otherwise start an AVAudioEngine + synthesise buffers on main.
        AppAudioSession.activate()
        DiscoveryEtherealTapChime.prewarm()
        // First button press would otherwise pay Taptic engine first-use latency.
        CalmExperienceFeedback.prewarm()
        // The very first `becomeFirstResponder` loads the keyboard subsystem (the biggest first-tap
        // cost). Prime it offscreen while the title screen is up.
        prewarmKeyboard()
    }

    private static func prewarmKeyboard() {
        guard let window = activeWindow else { return }
        let field = UITextField(frame: .zero)
        field.isHidden = true
        window.addSubview(field)
        field.becomeFirstResponder()
        field.resignFirstResponder()
        field.removeFromSuperview()
    }

    private static var activeWindow: UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first { $0.isKeyWindow } ?? windows.first
    }
}

/// The always-on ambient layers (drifting sparkles + persistent orb nebula shell), extracted so
/// they can sit behind an `.equatable()` boundary. Their only inputs are value types, so SwiftUI
/// skips re-evaluating them while a form field's keystrokes churn the rest of the view tree.
private struct FlowAmbientBackdrop: View, Equatable {
    let shellConfig: OrbShellConfiguration
    let anchor: Date
    let ambientPaused: Bool

    static func == (lhs: FlowAmbientBackdrop, rhs: FlowAmbientBackdrop) -> Bool {
        lhs.shellConfig == rhs.shellConfig
            && lhs.anchor == rhs.anchor
            && lhs.ambientPaused == rhs.ambientPaused
    }

    var body: some View {
        ZStack {
            GoldAmbientSparklesView(
                particleCount: BrandTheme.ambientSparkleParticleCount,
                intensity: BrandTheme.ambientSparkleIntensity,
                externallyPaused: ambientPaused
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            PersistentFlowOrbShell(configuration: shellConfig, anchor: anchor, externallyPaused: ambientPaused)
                .animation(.easeInOut(duration: 0.62), value: shellConfig)
        }
    }
}

struct BrandBackground: View {
    var showSparkles: Bool = true

    var body: some View {
        ZStack {
            BrandTheme.backgroundGradient
                .ignoresSafeArea()
            RadialGradient(
                colors: [
                    BrandTheme.nebulaPurple.opacity(0.16),
                    Color.clear,
                    BrandTheme.nebulaCyan.opacity(0.08),
                ],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 20,
                endRadius: 680
            )
            .ignoresSafeArea()
            if showSparkles {
                GoldAmbientSparklesView(
                    particleCount: BrandTheme.ambientSparkleParticleCount,
                    intensity: BrandTheme.ambientSparkleIntensity
                )
                .ignoresSafeArea()
            }
        }
    }
}

/// Full-screen tap-to-skip for the launch title only — disabled once the app is interactive.
private struct LaunchSkipTapModifier: ViewModifier {
    var enabled: Bool
    var onSkip: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: onSkip)
        } else {
            content
        }
    }
}

struct BrandCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.94))
                    .shadow(color: BrandTheme.brown.opacity(0.08), radius: 12, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
            )
    }
}
