import SwiftUI

// MARK: - Shared calm motion language (ethereal, unhurried)

/// Centralised animation curves so transitions across the app feel consistent and calm.
enum CalmMotion {
    /// Cross-screen phase changes — slow, weightless cross-dissolve.
    static let ethereal: Animation = .easeInOut(duration: 0.8)
    /// In-place content changes (cards, step swaps) — soft settle, no bounce.
    static let gentle: Animation = .spring(response: 0.66, dampingFraction: 0.92, blendDuration: 0.2)
    /// Resident playlist orb bloom — smooth, decelerating grow so the orb→full-page fill feels like
    /// one continuous, unhurried breath (no abrupt snap at the edges).
    static let playlistOrbMorph: Animation = .timingCurve(0.2, 0.85, 0.25, 1, duration: 1.05)
    /// Resident playlist orb collapse — settles the media back down to the compact orb before a
    /// genre swap re-blooms.
    static let playlistOrbCollapse: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.5)
    /// Screen content fading in after a transition.
    static let softFade: Animation = .easeOut(duration: 0.6)
    /// Small state tweaks (button enable, progress fill) — quick but smooth.
    static let subtle: Animation = .easeInOut(duration: 0.34)
}

extension AnyTransition {
    /// Opacity + the faintest scale and upward drift — content "arrives" rather than snaps.
    static var etherealAppear: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.99)).combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .scale(scale: 1.006))
        )
    }
}

// MARK: - Soft press (buttons feel organic, not sharp)

/// Every button press chimes and sends a soft glowing pulse out from the control: a quick bloom
/// that rings outward and fades. The halo sits behind the label (no layout change) and only
/// exists while the pulse is running, so idle buttons cost nothing extra.
struct SoftPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.978
    var glow: Color = BrandTheme.logoCyan

    func makeBody(configuration: Configuration) -> some View {
        GlowPressBody(configuration: configuration, pressedScale: pressedScale, pressedOpacity: 0.94, tone: glow)
    }
}

/// Plain buttons (custom-drawn labels) with the same chime and glow pulse.
struct ChimingPlainButtonStyle: ButtonStyle {
    var glow: Color = BrandTheme.logoCyan

    func makeBody(configuration: Configuration) -> some View {
        GlowPressBody(configuration: configuration, pressedScale: 1, pressedOpacity: 1, tone: glow)
    }
}

private struct GlowPulseFrame {
    var glow: CGFloat = 0
    var ring: CGFloat = 0
}

private struct GlowPressBody: View {
    let configuration: ButtonStyleConfiguration
    var pressedScale: CGFloat
    var pressedOpacity: Double
    var tone: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseCount = 0

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            // Keyframes so even a very quick tap gets the full bloom → ring → fade.
            .keyframeAnimator(initialValue: GlowPulseFrame(), trigger: pulseCount) { content, frame in
                content.background {
                    if frame.glow > 0.01 {
                        PressGlowHalo(glow: frame.glow, ring: frame.ring, tone: tone)
                    }
                }
            } keyframes: { _ in
                KeyframeTrack(\.glow) {
                    CubicKeyframe(1, duration: 0.12)
                    CubicKeyframe(0.8, duration: 0.2)
                    CubicKeyframe(0, duration: 0.5)
                }
                KeyframeTrack(\.ring) {
                    LinearKeyframe(0, duration: 0.08)
                    CubicKeyframe(1, duration: 0.74)
                }
            }
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                CalmExperienceFeedback.buttonPress()
                if !reduceMotion { pulseCount &+= 1 }
            }
    }
}

/// Soft bloom hugging the control plus a thin ring that drifts outward as it fades. Square-ish
/// controls (glyphs, round buttons) get a circle; wider ones a capsule / rounded card outline.
private struct PressGlowHalo: View {
    let glow: CGFloat
    let ring: CGFloat
    let tone: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Compact controls (round orb buttons with a caption) get a pill; wide rows and cards
            // keep a card-like corner.
            let radius = max(w, h) < min(w, h) * 1.5 ? min(w, h) / 2 : min(h / 2, 22)
            let spread = 3 + 18 * ring
            ZStack {
                RoundedRectangle(cornerRadius: radius + 6, style: .continuous)
                    .fill(tone.opacity(0.38 * glow))
                    .padding(-6)
                    .blur(radius: 12)
                RoundedRectangle(cornerRadius: radius + spread, style: .continuous)
                    .stroke(tone.opacity(0.9 * glow), lineWidth: 2)
                    .padding(-spread)
                    .blur(radius: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Chime when a non-button control (toggle, segmented picker, stepper, menu) changes value.
    func chimeOnChange<V: Equatable>(of value: V) -> some View {
        onChange(of: value) { _, _ in
            CalmExperienceFeedback.buttonPress()
        }
    }
}

extension View {
    func calmSoftPress() -> some View {
        buttonStyle(SoftPressButtonStyle())
    }

    func calmDissolveTransition() -> some View {
        transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.985)),
                removal: .opacity.combined(with: .scale(scale: 1.012))
            )
        )
    }
}

// MARK: - Breath ring (replaces spinners on calm waits)

struct CalmCircularLoader: View {
    var diameter: CGFloat = 72
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Capped at 60fps — the ring is a quarter-second sweep, so 120Hz ProMotion ticks bought
        // nothing visible. Shadows are centred (y: 0) and so rotation-invariant; applying them
        // before the rotation means they are not re-blurred on every tick.
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            let rotation = reduceMotion
                ? 0
                : context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 0.95) / 0.95 * 360

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.42), lineWidth: 2.5)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .trim(from: 0.08, to: 0.72)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                BrandTheme.logoCyan.opacity(0.95),
                                BrandTheme.gold.opacity(0.98),
                                BrandTheme.goldDeep.opacity(0.92),
                                Color.white.opacity(0.5),
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .frame(width: diameter, height: diameter)
                    .shadow(color: BrandTheme.logoCyan.opacity(0.55), radius: 10)
                    .shadow(color: BrandTheme.gold.opacity(0.45), radius: 6)
                    .rotationEffect(.degrees(rotation))
            }
        }
        .accessibilityLabel("Loading")
    }
}

enum CalmLoaderPace {
    case standard
    case brisk

    var breathDuration: TimeInterval {
        switch self {
        case .standard: return 2.6
        case .brisk: return 1.45
        }
    }
}

struct BreathingCalmProgressView: View {
    var diameter: CGFloat = 56
    var pace: CalmLoaderPace = .standard
    @State private var inhale = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 2.5)
                .frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0, to: 0.68)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.52),
                            BrandTheme.logoCyan.opacity(0.92),
                            BrandTheme.gold.opacity(0.96),
                            BrandTheme.goldDeep.opacity(0.88),
                            Color.white.opacity(0.48),
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(inhale ? 24 : -12))
                .scaleEffect(inhale ? 1.06 : 0.90)
                .opacity(inhale ? 1 : 0.78)
                .shadow(color: BrandTheme.logoCyan.opacity(0.5), radius: 9)
                .shadow(color: BrandTheme.gold.opacity(0.42), radius: 5)
        }
        .accessibilityLabel("Preparing your calm space")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: pace.breathDuration).repeatForever(autoreverses: true)) {
                inhale = true
            }
        }
    }
}

// MARK: - Staff → resident handoff veil

struct ResidentStaffHandoffOverlay: View {
    var patientName: String?
    var onComplete: () -> Void

    @State private var veilOpacity: Double = 0
    @State private var copyOpacity: Double = 0
    @State private var orbGlow: Double = 0.4

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.28, blue: 0.38)
                .opacity(veilOpacity * 0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                BreathingCalmProgressView(diameter: 72, pace: .brisk)
                    .scaleEffect(1 + orbGlow * 0.08)
                if let patientName {
                    Text(patientName)
                        .font(BrandTheme.orbTitleFont(.title2))
                        .orbOverlayText()
                }
                Text("Opening calm surface")
                    .font(BrandTheme.orbLineFont())
                    .orbOverlayText(muted: true)
            }
            .opacity(copyOpacity)
        }
        .allowsHitTesting(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Opening the resident calm surface")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55)) {
                veilOpacity = 1
                copyOpacity = 1
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                orbGlow = 1
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                withAnimation(.easeInOut(duration: 0.5)) {
                    copyOpacity = 0
                    veilOpacity = 0
                }
                try? await Task.sleep(nanoseconds: 520_000_000)
                onComplete()
            }
        }
    }
}

// MARK: - Post-session settling pause

struct SessionSettlingView: View {
    @ObservedObject var state: SessionPOCState
    @State private var visible = false

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                BreathingCalmProgressView(diameter: 80)
                Text(state.isResidentSession ? "Settling" : "A quiet moment")
                    .font(BrandTheme.orbTitleFont(.title2))
                    .orbOverlayText()
            }
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.98)
        }
        .accessibilityLabel("Settling after session")
        .onAppear {
            CalmExperienceFeedback.sessionSettle()
            withAnimation(.easeInOut(duration: 0.65)) { visible = true }
        }
        .task {
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) { visible = false }
            }
            try? await Task.sleep(nanoseconds: 560_000_000)
            await MainActor.run {
                if state.shouldOfferSessionSentimentFeedback() {
                    state.beginSessionSentimentFeedback()
                } else if state.isResidentSession {
                    state.returnToResidentProfile()
                } else {
                    state.phase = .insight
                }
            }
        }
    }
}
