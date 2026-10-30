import SwiftUI

enum OrbEnvelopeKind: Equatable {
    case organicBubble
    case roundedPanel
}

/// Animated envelope dimensions + pulse for the single persistent flow orb.
struct OrbShellConfiguration: Equatable {
    var width: CGFloat
    var height: CGFloat
    var opacity: CGFloat
    var pulseMode: OrbPulseMode
    var pulseSoftness: CGFloat
    var floats: Bool
    var kind: OrbEnvelopeKind
    var panelPulseSpeed: Double = 1
    var panelPulseIntensity: CGFloat = 1
    var nebulaFillOpacity: CGFloat = 1
    var showArcFrame: Bool = true
    var shellGlowScale: CGFloat = 1
    /// Tone of the orb's interior. Pages that lay cards over it ask for less, so text keeps its contrast.
    var brightness: CGFloat = 1

    static func forPhase(
        _ phase: FlowPhase,
        launchActive: Bool,
        containerSize: CGSize,
        isResidentSession: Bool = false
    ) -> OrbShellConfiguration {
        guard containerSize.width > 1, containerSize.height > 1 else {
            return panelShell(in: .zero, width: 280, height: 280)
        }

        if launchActive {
            // The title card lays the wordmark and tagline straight over the orb: luminous, but with a ceiling so white
            // text keeps its contrast (the full pastel orb gave the tagline about 2:1).
            let size = BrandLayout.flowOrbPanelSize(in: containerSize)
            return panelShell(in: containerSize, width: size.width, height: size.height, floats: false, brightness: 0.66)
        }

        let tone = interiorBrightness(for: phase)
        switch phase {
        case .immersive:
            let nebula: CGFloat = isResidentSession ? 0.22 : 0.35
            return panelShell(in: containerSize, nebulaFillOpacity: nebula, shellGlowScale: 1.45, brightness: tone)
        case .careDiscoveryCalibration:
            return panelShell(in: containerSize, shellGlowScale: 1.45, brightness: tone)
        default:
            _ = isResidentSession
            return panelShell(in: containerSize, shellGlowScale: 1.45, brightness: tone)
        }
    }

    /// The ceiling on the orb's interior luminance behind each page (1 = none). A pastel orb is the point of the hero pages (sign-in, the
    /// calm surface, discovery), but behind a stack of half-transparent cards it is the thing that decides whether 12 pt
    /// text is readable — so the pages made of cards and forms ask for a calmer interior. The change eases with the
    /// page transition.
    private static func interiorBrightness(for phase: FlowPhase) -> CGFloat {
        switch phase {
        case .residentProfile, .careDiscoveryCalibration, .careFaceLinkedPick, .immersive, .processingFast, .sessionSettling:
            return 1.0
        case .home, .supervisorWelcome, .careHomeAdminWelcome, .careHomePicker, .entryMode, .captureMoment, .moodSelect:
            return 0.62
        default:
            return 0.52
        }
    }

    /// One panel-sized orb on every screen — size morphs, cadence follows the reference orb loop.
    private static func panelShell(
        in containerSize: CGSize,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        nebulaFillOpacity: CGFloat = 1,
        shellGlowScale: CGFloat = 1.45,
        opacity: CGFloat = 1,
        floats: Bool = false,
        brightness: CGFloat = 1
    ) -> OrbShellConfiguration {
        let size = BrandLayout.flowOrbPanelSize(in: containerSize)
        return OrbShellConfiguration(
            width: width ?? size.width,
            height: height ?? size.height,
            opacity: opacity,
            pulseMode: .calm,
            pulseSoftness: 1,
            floats: floats,
            kind: .organicBubble,
            panelPulseSpeed: 1,
            panelPulseIntensity: 1,
            nebulaFillOpacity: nebulaFillOpacity,
            showArcFrame: true,
            shellGlowScale: shellGlowScale,
            brightness: brightness
        )
    }
}

/// One orb shell that morphs size and opacity as the flow moves between pages.
struct PersistentFlowOrbShell: View {
    var configuration: OrbShellConfiguration
    var anchor: Date
    /// Pause the pulse/nebula draw loop from outside (e.g. while the keyboard is up) so the
    /// per-cell nebula noise doesn't compete with text input for the main thread.
    var externallyPaused: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var metal = OrbMetalPipeline.shared

    /// On the GPU the orb breathes and swirls on its own display link, so this view has no timeline: SwiftUI is not
    /// asked to re-evaluate anything per frame. The CPU orb below is the fallback.
    var body: some View {
        if metal.usesMetal {
            MorphingMetalOrbBackdrop(
                width: configuration.width,
                height: configuration.height,
                anchor: anchor,
                fill: configuration.nebulaFillOpacity,
                brightness: configuration.brightness,
                glowBoost: min(1.2, 0.85 + 0.2 * configuration.shellGlowScale),
                paused: (externallyPaused && OrbMetalPipeline.pausesForInteraction) || configuration.pulseMode == .dormant
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(configuration.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            classicBody
        }
    }

    // Reading `MusicReactiveBus.shared.snapshot` directly (rather than subscribing via
    // `@ObservedObject`) avoids a second, faster invalidation source stacking on top of this
    // shell's own `TimelineView` tick — the shell already redraws every frame, so it picks up
    // the latest snapshot value each tick without needing its own publish-driven re-render.
    private var classicBody: some View {
        // Present on every screen for the app's whole lifetime — pause while backgrounded so the
        // pulse/glow animation isn't computed and drawn when nothing is on screen.
        TimelineView(.animation(minimumInterval: OrbRenderBudget.shellFrameInterval(reduceMotion: reduceMotion), paused: configuration.pulseMode == .dormant || scenePhase != .active || externallyPaused || DemoLaunchOptions.freezeOrb)) { timeline in
            let elapsed = DemoLaunchOptions.freezeOrb ? 2.0 : timeline.date.timeIntervalSince(anchor) * configuration.panelPulseSpeed
            let baseSample = OrbPulseSample.sample(
                at: elapsed,
                mode: configuration.pulseMode,
                reduceMotion: reduceMotion,
                speedMultiplier: configuration.panelPulseSpeed
            )
            let reactive = MusicReactiveBus.shared.snapshot
            let sample = reactive.isActive && !reduceMotion
                ? baseSample.blendedWithMusic(pulse: reactive.pulse, glow: reactive.glow)
                : baseSample
            let shellScale = sample.shellScale
            let floatScale: CGFloat = configuration.floats ? 0.25 : 0
            let _ = OrbFrameMonitor.noteShellDrawIfEnabled()

            ZStack {
                MorphingOrbShellBackdrop(
                    width: configuration.width,
                    height: configuration.height,
                    pulse: sample.pulse,
                    glowPulse: sample.glowPulse,
                    shellScale: shellScale,
                    kind: configuration.kind,
                    nebulaFillOpacity: configuration.nebulaFillOpacity,
                    showArcFrame: configuration.showArcFrame,
                    shellGlowScale: configuration.shellGlowScale,
                    animationElapsed: elapsed
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(configuration.opacity)
            .offset(
                x: configuration.floats ? sample.contentFloatX * floatScale : 0,
                y: configuration.floats ? sample.contentFloatY * floatScale : 0
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MorphingOrbShellBackdrop: View, Animatable {
    var width: CGFloat
    var height: CGFloat
    var pulse: Double
    var glowPulse: Double
    var shellScale: CGFloat
    var kind: OrbEnvelopeKind
    var nebulaFillOpacity: CGFloat = 1
    var showArcFrame: Bool = true
    var shellGlowScale: CGFloat = 1
    var animationElapsed: TimeInterval? = nil

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(width, height) }
        set {
            width = newValue.first
            height = newValue.second
        }
    }

    var body: some View {
        switch kind {
        case .organicBubble, .roundedPanel:
            NoteStalgiaOrbEnvelopeBackdrop(
                width: max(0, width),
                height: max(0, height),
                pulse: pulse,
                glowPulse: glowPulse,
                shellScale: shellScale,
                nebulaFillOpacity: nebulaFillOpacity,
                showArcFrame: showArcFrame,
                shellGlowScale: shellGlowScale,
                animationElapsed: animationElapsed
            )
        }
    }
}

/// The GPU orb with an animatable size, so it morphs with the flow like the CPU orb does.
private struct MorphingMetalOrbBackdrop: View, Animatable {
    var width: CGFloat
    var height: CGFloat
    var anchor: Date
    var fill: CGFloat
    var brightness: CGFloat
    var glowBoost: CGFloat
    var paused: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(width, height), AnimatablePair(brightness, fill)) }
        set {
            width = newValue.first.first
            height = newValue.first.second
            brightness = newValue.second.first
            fill = newValue.second.second
        }
    }

    var body: some View {
        NoteStalgiaMetalOrb(
            baseDiameter: max(0, min(width, height)),
            drive: .heartbeat,
            anchor: anchor,
            brightness: brightness,
            fill: fill,
            glowBoost: glowBoost,
            externallyPaused: paused
        )
    }
}

