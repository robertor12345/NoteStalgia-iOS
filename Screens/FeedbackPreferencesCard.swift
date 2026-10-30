import SwiftUI

/// "Sounds and haptics": the two switches behind `FeedbackPreferences`, on the roster and on a Care at home page. They are
/// per device and have nothing to do with Reduce Motion or with the music. Switching one on plays what it controls, so the
/// card is also how you hear and feel the difference.
struct FeedbackPreferencesCard: View {
    @AppStorage(FeedbackPreferences.soundsKey) private var sounds = true
    @AppStorage(FeedbackPreferences.hapticsKey) private var haptics = true

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "Sounds and haptics",
                    systemImage: "speaker.wave.2",
                    subtitle: "A quiet chime and a light tap when you press, choose or save, and a lower note when something needs a second look. Music is not affected."
                )
                BrandRowsTile {
                    Toggle(isOn: $sounds) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Chimes", systemImage: "bell")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text("On every button, choice and save.")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textSecondary)
                        }
                        .frame(minHeight: 44)
                    }
                    .toggleStyle(BrandRowToggleStyle())
                    .accessibilityIdentifier("settings.sounds")
                    BrandHairline()
                    Toggle(isOn: $haptics) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Haptics", systemImage: "hand.tap")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text("Felt on an iPhone; an iPad has no haptic motor.")
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textSecondary)
                        }
                        .frame(minHeight: 44)
                    }
                    .toggleStyle(BrandRowToggleStyle())
                    .accessibilityIdentifier("settings.haptics")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        // Turning one on shows what it does (the press that flipped it happened while it was still off).
        .onChange(of: sounds) { _, on in
            if on { DiscoveryEtherealTapChime.playButton() }
        }
        .onChange(of: haptics) { _, on in
            if on { CalmExperienceFeedback.lightTap() }
        }
    }
}
