import UIKit

/// Whether the interface makes sound and haptics. Per device, and deliberately separate from Reduce Motion: that setting
/// is about movement, and a person who turns it on may still want the chime that confirms a tap. On by default; the
/// "Sounds and haptics" card on the roster and on a Care at home page changes them. Music is never affected.
enum FeedbackPreferences {
    static let soundsKey = "NoteStalgiaInterfaceSounds"
    static let hapticsKey = "NoteStalgiaInterfaceHaptics"

    static var soundsOn: Bool { UserDefaults.standard.object(forKey: soundsKey) as? Bool ?? true }
    static var hapticsOn: Bool { UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true }
}

/// Soft haptics + chimes for calm UI feedback. Four kinds of moment, each with its own cue:
///
/// * **a press or a choice** — `buttonPress()`: the quiet chime and a light selection tick (every button, chip, toggle and row);
/// * **a good outcome** — `saved()` / `signInSuccess()`: a soft impact and the rising success chime;
/// * **something needs a second look** — `attention(announcing:)`: a warning haptic, the lower attention chime and, for
///   VoiceOver, the message itself read out (a message that appears on screen is otherwise silent to it);
/// * **a milestone in a session** — `discoveryPick()`, `playlistStart()`, `sessionSettle()`: a soft impact.
///
/// iPads have no haptic motor, so on them the sounds carry everything; the haptics are for the phone.
@MainActor
enum CalmExperienceFeedback {
    private static var lastButtonChimeTime: CFAbsoluteTime = 0
    /// Persistent generators so the Taptic engine stays warm — recreating one per tap re-incurs
    /// first-use latency, which reads as a stutter on the first interaction.
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Warm haptics + chimes behind the launch screen so the first real interaction is instant.
    static func prewarm() {
        guard FeedbackPreferences.hapticsOn else { return }
        softGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Standard cue for any button press (deduped within ~80ms): the quiet chime and a light tick.
    static func buttonPress() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastButtonChimeTime > 0.08 else { return }
        lastButtonChimeTime = now
        if FeedbackPreferences.soundsOn { DiscoveryEtherealTapChime.playButton() }
        if FeedbackPreferences.hapticsOn {
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
            DemoAudioLog.record("haptic", ["kind": "selection"])
        }
    }

    static func lightTap() {
        impact(.soft, intensity: 0.42)
        buttonPress()
    }

    /// Something went right and is done: a save, a sign-in, a registration. `announcing` is read out by VoiceOver.
    static func saved(announcing message: String? = nil) {
        impact(.soft, intensity: 0.58)
        if FeedbackPreferences.soundsOn { DiscoveryEtherealTapChime.playSuccess() }
        announce(message)
    }

    static func signInSuccess() {
        saved()
    }

    /// Something needs a second look — a form that cannot be saved, a sign-in that did not match. Gentle, not an alarm.
    static func attention(announcing message: String? = nil) {
        if FeedbackPreferences.hapticsOn {
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
            DemoAudioLog.record("haptic", ["kind": "attention"])
        }
        if FeedbackPreferences.soundsOn { DiscoveryEtherealTapChime.playAttention() }
        announce(message)
    }

    static func playlistStart() {
        impact(.soft, intensity: 0.48)
    }

    static func discoveryPick() {
        impact(.soft, intensity: 0.44)
    }

    static func sessionSettle() {
        impact(.soft, intensity: 0.36)
        if FeedbackPreferences.soundsOn { DiscoveryEtherealTapChime.playSuccess() }
    }

    private static func announce(_ message: String?) {
        guard let message, !message.isEmpty else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        guard FeedbackPreferences.hapticsOn else { return }
        // All call sites use `.soft`; reuse the warm persistent generator to avoid first-use lag.
        let generator: UIImpactFeedbackGenerator = style == .soft
            ? softGenerator
            : UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
        DemoAudioLog.record("haptic", ["kind": "impact", "intensity": Double(intensity)])
    }
}
