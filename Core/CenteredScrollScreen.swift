import SwiftUI

/// Scrollable column that is **vertically and horizontally centered** when content is shorter than the safe area; scrolls when content is taller.
struct CenteredScrollScreen<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var backTitle: String = "Back"
    var backAccessibilityLabel: String?
    var onBack: (() -> Void)?
    var onLogout: (() -> Void)?
    /// Pin content to the top instead of centring it when it is shorter than the viewport — for
    /// screens whose height changes as the user types (e.g. roster search), so the field never jumps.
    var topAligned: Bool = false
    @ViewBuilder var content: () -> Content

    private let scrollSpace = "centeredScroll"

    private var showsStaffChrome: Bool {
        onBack != nil || onLogout != nil
    }

    var body: some View {
        GeometryReader { geo in
            let gutter = BrandLayout.contentGutter(for: horizontalSizeClass)
            // `safeAreaInset` shrinks the scroll viewport; size the centered column to that
            // reduced height so we don't invent phantom scroll space under the chrome.
            let chromeAllowance: CGFloat = showsStaffChrome ? 52 : 0
            let viewportHeight = max(geo.size.height - chromeAllowance, 200)

            ScrollViewportEdgeFade(coordinateSpace: scrollSpace) {
                VStack(spacing: 0) {
                    if !topAligned {
                        Spacer(minLength: 0)
                    }
                    content()
                        .frame(maxWidth: BrandLayout.menuColumnMaxWidth)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, gutter)
                        .padding(.top, showsStaffChrome ? BrandLayout.scrollEdgeFadeComfortPadding : 0)
                        .padding(.bottom, BrandLayout.scrollEdgeFadeComfortPadding)
                        .environment(\.centeredScrollContentGutter, gutter)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: viewportHeight)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsStaffChrome {
                    FlowTopStaffNavBar(
                        backTitle: backTitle,
                        backAccessibilityLabel: backAccessibilityLabel,
                        onBack: onBack,
                        onLogout: onLogout
                    )
                }
            }
        }
    }
}

// MARK: - Full-bleed horizontal rows inside CenteredScrollScreen

private enum CenteredScrollContentGutterKey: EnvironmentKey {
    static let defaultValue: CGFloat = BrandTheme.contentGutter
}

extension EnvironmentValues {
    var centeredScrollContentGutter: CGFloat {
        get { self[CenteredScrollContentGutterKey.self] }
        set { self[CenteredScrollContentGutterKey.self] = newValue }
    }
}

extension View {
    /// Breaks out of `CenteredScrollScreen`'s horizontal gutter so a chip row can fade at the
    /// true screen edges on phone.
    func centeredScrollFullBleed() -> some View {
        modifier(CenteredScrollFullBleedModifier())
    }
}

private struct CenteredScrollFullBleedModifier: ViewModifier {
    @Environment(\.centeredScrollContentGutter) private var gutter

    func body(content: Content) -> some View {
        content.padding(.horizontal, -gutter)
    }
}
