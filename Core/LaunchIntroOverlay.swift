import SwiftUI
import UIKit

/// Launch copy inside the orb — motion locked to the same pulse anchor as the envelope.
struct LaunchIntroOverlay: View {
    var anchor: Date
    var totalDuration: TimeInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let titleFadeIn: TimeInterval = 0.85
    private let subtitleStart: TimeInterval = 1.05
    private let wordStagger: TimeInterval = 0.38
    private let wordFadeDuration: TimeInterval = 0.62

    /// Keep the approved 60 pt iPad wordmark; use a phone-specific size so it clears the orb edges.
    private var titlePointSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 60 : 44
    }

    private var titleTracking: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 6 : 4.5
    }

    private var subtitlePointSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 40 : 10
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: OrbRenderBudget.contentFrameInterval(reduceMotion: reduceMotion), paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(anchor)
            let sample = OrbPulseSample.sample(at: elapsed, mode: .calm, reduceMotion: reduceMotion)
            let fadeOutStart = max(0, totalDuration - 0.85)
            let overlayOpacity = elapsed >= fadeOutStart
                ? max(0, 1 - (elapsed - fadeOutStart) / 0.85)
                : 1.0

            let titleOpacity = reduceMotion
                ? min(1, max(0, elapsed / 0.4))
                : min(1, max(0, elapsed / titleFadeIn))

            VStack(spacing: 22) {
                NoteStalgiaWordmark(
                    font: .system(size: titlePointSize, weight: .semibold, design: .rounded),
                    tracking: titleTracking,
                    pointSize: titlePointSize
                )
                .opacity(titleOpacity)
                .offset(y: reduceMotion ? 0 : (1 - titleOpacity) * 14)

                IntroStaggeredWords(
                    text: "Sound that takes you back....",
                    elapsed: elapsed,
                    startAt: reduceMotion ? 0.3 : subtitleStart,
                    wordStagger: reduceMotion ? 0 : wordStagger,
                    fadeDuration: reduceMotion ? 0.35 : wordFadeDuration,
                    pointSize: subtitlePointSize,
                    weight: .semibold,
                    legibilityIntensity: 1.08
                )
            }
            .padding(.horizontal, BrandTheme.contentGutter)
            .scaleEffect(sample.innerContentScale)
            .offset(x: sample.contentFloatX, y: sample.contentFloatY)
            .opacity(overlayOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("NoteStalgia is starting. Sound that takes you back.")
        }
    }
}

/// Fades each word in sequentially.
private struct IntroStaggeredWords: View {
    let text: String
    let elapsed: TimeInterval
    let startAt: TimeInterval
    var wordStagger: TimeInterval
    var fadeDuration: TimeInterval
    let pointSize: CGFloat
    let weight: Font.Weight
    var muted: Bool = false
    var legibilityIntensity: CGFloat = 1

    /// Once every word has fully faded in, the string stops changing — cache it instead of
    /// rebuilding an `AttributedString` (with per-word `UIFont`/`UIColor` conversions) on every
    /// 60fps tick for the rest of the launch animation.
    @State private var settledString: AttributedString?

    var body: some View {
        Text(currentAttributedString)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .orbOverlayTextStyle(intensity: legibilityIntensity)
    }

    private var wordCount: Int {
        text.split(separator: " ", omittingEmptySubsequences: true).count
    }

    private var isFullySettled: Bool {
        let lastWordStart = startAt + Double(max(0, wordCount - 1)) * wordStagger
        return elapsed >= lastWordStart + fadeDuration
    }

    private var currentAttributedString: AttributedString {
        if isFullySettled, let settledString {
            return settledString
        }
        let built = staggeredAttributedString
        if isFullySettled {
            settledString = built
        }
        return built
    }

    private var staggeredAttributedString: AttributedString {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var line = AttributedString()
        let uiWeight = weight.uiFontWeight
        let textColor = muted ? BrandTheme.textOnOrbMuted : BrandTheme.textOnOrb
        let baseAlpha: CGFloat = muted ? 0.92 : 1

        for (index, word) in words.enumerated() {
            let progress = wordProgress(for: index)
            var chunk = AttributedString((index == 0 ? "" : " ") + word)
            var attributes = AttributeContainer()
            attributes.font = .systemFont(ofSize: pointSize, weight: uiWeight)
            attributes.foregroundColor = UIColor(textColor).withAlphaComponent(baseAlpha * progress)
            chunk.mergeAttributes(attributes)
            line.append(chunk)
        }
        return line
    }

    private func wordProgress(for index: Int) -> CGFloat {
        let start = startAt + Double(index) * wordStagger
        return CGFloat(min(1, max(0, (elapsed - start) / max(0.001, fadeDuration))))
    }
}

private extension Font.Weight {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }
}
