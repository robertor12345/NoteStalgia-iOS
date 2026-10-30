import SwiftUI

/// Body copy — soft fade + slight rise (on the orb).
struct FadeInLine: View {
    let text: String
    var font: Font = BrandTheme.orbLineFont()
    var magnification: CGFloat = 1
    var muted: Bool = false
    var delay: Double = 0
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedFont: Font {
        magnification > 1 ? SignInPageLayout.subheadFont : font
    }

    var body: some View {
        Text(text)
            .font(resolvedFont)
            .orbOverlayText(muted: muted)
            .multilineTextAlignment(.center)
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.65).delay(delay)) {
                    visible = true
                }
            }
            .onDisappear { visible = false }
    }
}

/// Title fade on the orb.
struct FadeInTitle: View {
    let text: String
    var size: Font.TextStyle = .largeTitle
    var magnification: CGFloat = 1
    var delay: Double = 0
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedFont: Font {
        magnification > 1
            ? SignInPageLayout.titleFont
            : BrandTheme.orbTitleFont(size)
    }

    var body: some View {
        Text(text)
            .font(resolvedFont)
            .tracking(magnification > 1 ? 3 : 2)
            .orbOverlayText()
            .multilineTextAlignment(.center)
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.7).delay(delay)) {
                    visible = true
                }
            }
            .onDisappear { visible = false }
    }
}

/// NoteStalgia title fade — wordmark with ™.
struct FadeInNoteStalgiaWordmark: View {
    var magnification: CGFloat = 1
    var delay: Double = 0
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedFont: Font {
        magnification > 1 ? SignInPageLayout.titleFont : BrandTheme.orbTitleFont(.title)
    }

    private var resolvedPointSize: CGFloat {
        magnification > 1 ? SignInPageLayout.points(28) : 32
    }

    var body: some View {
        NoteStalgiaWordmark(
            font: resolvedFont,
            tracking: magnification > 1 ? 3 : 2,
            pointSize: resolvedPointSize
        )
        .multilineTextAlignment(.center)
        .opacity(visible ? 1 : 0)
        .offset(y: visible || reduceMotion ? 0 : 12)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.7).delay(delay)) {
                visible = true
            }
        }
        .onDisappear { visible = false }
    }
}

/// Fades the entire screen content in after transition.
struct ScreenFadeIn<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var visible = false
    @State private var onScreen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content()
            .opacity(visible ? 1 : 0)
            // With Reduce Motion on, a screen only fades — it does not drift or scale into place.
            .scaleEffect(visible || reduceMotion ? 1 : 0.992)
            .offset(y: visible || reduceMotion ? 0 : 6)
            .onAppear {
                onScreen = true
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : CalmMotion.softFade) {
                    visible = true
                }
                // A state write inside onAppear can be dropped when the screen is inserted while the
                // phase fade is still animating — seen under recording load, where a new phase stayed
                // at opacity 0 (invisible to touch and to accessibility). Re-assert the reveal.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    if onScreen, !visible {
                        DemoAudioLog.record("fadeInFallback")
                        withAnimation(CalmMotion.softFade) {
                            visible = true
                        }
                    }
                }
            }
            .onDisappear {
                onScreen = false
                visible = false
            }
    }
}
