import UIKit

/// Soft haptics + chimes for calm UI feedback.
@MainActor
enum CalmExperienceFeedback {
    private static var lastButtonChimeTime: CFAbsoluteTime = 0
    /// Persistent generator so the Taptic engine stays warm — recreating one per tap re-incurs
    /// first-use latency, which reads as a stutter on the first interaction.
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)

    /// Warm haptics + chimes behind the launch screen so the first real interaction is instant.
    static func prewarm() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        softGenerator.prepare()
    }

    /// Standard soft chime for any button press (deduped within ~80ms).
    static func buttonPress() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastButtonChimeTime > 0.08 else { return }
        lastButtonChimeTime = now
        DiscoveryEtherealTapChime.playButton()
    }

    static func lightTap() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        impact(.soft, intensity: 0.42)
        buttonPress()
    }

    static func signInSuccess() {
        impact(.soft, intensity: 0.58)
        DiscoveryEtherealTapChime.playSuccess()
    }

    static func playlistStart() {
        impact(.soft, intensity: 0.48)
    }

    static func discoveryPick() {
        impact(.soft, intensity: 0.44)
    }

    static func sessionSettle() {
        impact(.soft, intensity: 0.36)
        DiscoveryEtherealTapChime.playSuccess()
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        // All call sites use `.soft`; reuse the warm persistent generator to avoid first-use lag.
        let generator: UIImpactFeedbackGenerator = style == .soft
            ? softGenerator
            : UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }
}
