import SwiftUI

/// NoteStalgia cosmos brand — deep navy field, nebula orb (teal · lavender · pink).
enum BrandTheme {
    // MARK: - Surfaces (dark UI cards on cosmic background)
    static let cream = Color(red: 0.16, green: 0.15, blue: 0.24)
    static let creamMid = Color(red: 0.12, green: 0.11, blue: 0.20)
    static let creamDeep = Color(red: 0.10, green: 0.09, blue: 0.17)

    // MARK: - Canvas (soft lavender–teal field drawn from the nebula palette)
    static let skyBackgroundTop = Color(red: 0.46, green: 0.42, blue: 0.62)
    static let skyBackgroundMid = Color(red: 0.40, green: 0.46, blue: 0.64)
    static let skyBackgroundDeep = Color(red: 0.36, green: 0.44, blue: 0.60)

    // MARK: - Nebula orb palette
    static let nebulaMagenta = Color(red: 0.82, green: 0.38, blue: 0.78)
    static let nebulaPurple = Color(red: 0.58, green: 0.32, blue: 0.88)
    static let nebulaLavender = Color(red: 0.72, green: 0.58, blue: 0.96)
    static let nebulaCyan = Color(red: 0.38, green: 0.88, blue: 0.94)
    static let nebulaTeal = Color(red: 0.28, green: 0.78, blue: 0.88)
    static let nebulaPink = Color(red: 0.96, green: 0.62, blue: 0.82)
    /// Warm peach smoke on the reference orb’s right side.
    static let nebulaPeach = Color(red: 0.98, green: 0.66, blue: 0.52)
    static let nebulaSalmon = Color(red: 0.94, green: 0.58, blue: 0.62)
    /// Deep atmospheric shadow — gas-giant belts and limb darkening.
    static let nebulaDeep = Color(red: 0.14, green: 0.18, blue: 0.38)
    static let nebulaBeltShadow = Color(red: 0.22, green: 0.26, blue: 0.52)
    static let nebulaBeltHighlight = Color(red: 0.72, green: 0.90, blue: 0.98)
    static let orbShellHighlight = nebulaPink.opacity(0.95)
    static let orbShellMid = nebulaLavender.opacity(0.85)
    static let orbShellEdge = nebulaPurple.opacity(0.72)
    static let orbGlowOuter = nebulaCyan
    static let orbShellShadow = Color(red: 0.02, green: 0.02, blue: 0.08)

    // MARK: - Ambient background sparkles
    /// Floating sparks behind the orb on every screen (+50% vs the prior 300).
    static let ambientSparkleParticleCount: Int = 450
    static let ambientSparkleIntensity: CGFloat = 0.6
    /// Softer layer when stacked (e.g. resident playlist playing).
    static let ambientSparkleIntensitySubtle: CGFloat = 0.32

    // MARK: - Intro / splash copy on dark field
    static let introTitle = Color(red: 0.96, green: 0.88, blue: 1.0)
    static let introTitleHighlight = Color(red: 0.72, green: 0.94, blue: 1.0)
    static let introSubtitle = Color(red: 0.82, green: 0.78, blue: 0.94)
    static let introBody = Color(red: 0.68, green: 0.64, blue: 0.82)
    static let introTextHalo = Color(red: 0.45, green: 0.35, blue: 0.72).opacity(0.55)
    static let introTextShadow = Color.black.opacity(0.45)

    // MARK: - Semantic text (readability-first on cosmic canvas)
    /// Primary copy on the gradient and dark cards.
    static let textPrimary = introTitle
    /// Secondary labels, hints, and metadata.
    static let textSecondary = introSubtitle
    /// Captions and de-emphasized copy.
    static let textTertiary = introBody
    /// Short labels on the nebula orb — near-white for maximum contrast on colour.
    static let textOnOrb = Color(red: 0.99, green: 0.98, blue: 1.0)
    /// De-emphasised orb copy — still light, not grey.
    static let textOnOrbMuted = Color(red: 0.93, green: 0.95, blue: 1.0)

    // MARK: - Orb overlay typography (sized up for legibility on the nebula)
    static func orbTitleFont(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .rounded, weight: .semibold)
    }

    static func orbLineFont(_ style: Font.TextStyle = .title3) -> Font {
        .system(style, design: .rounded, weight: .medium)
    }

    static func orbHintFont(_ style: Font.TextStyle = .body) -> Font {
        .system(style, design: .rounded, weight: .medium)
    }

    // MARK: - Logo wordmark tones (readable on cosmic canvas)
    static let logoPink = Color(red: 0.91, green: 0.72, blue: 0.84)
    static let logoCyan = Color(red: 0.56, green: 0.84, blue: 0.93)
    static let logoLavenderBlue = Color(red: 0.78, green: 0.82, blue: 0.98)

    // MARK: - Typography & accents (legacy aliases — prefer textPrimary / textSecondary)
    static let brown = textPrimary
    static let brownMuted = textSecondary
    static let gold = logoCyan
    static let goldSoft = logoPink.opacity(0.88)
    static let goldDeep = Color(red: 0.62, green: 0.88, blue: 0.96)

    static let introPeach = introTitleHighlight
    static let introPeachSoft = introBody
    static let introPeachMuted = introBody.opacity(0.92)
    static let introPeachGlow = introTitleHighlight

    static let primaryButtonPeach = nebulaPink

    static let backgroundGradient = LinearGradient(
        colors: [skyBackgroundTop, skyBackgroundMid, skyBackgroundDeep],
        startPoint: .top,
        endPoint: .bottom
    )

    static let brandWordmarkGradient = LinearGradient(
        colors: [logoPink, logoLavenderBlue, logoCyan],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let etherealGradient = LinearGradient(
        colors: [
            nebulaPurple.opacity(0.42),
            nebulaCyan.opacity(0.28),
            cream.opacity(0.88),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sessionNatureSkyGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.14, blue: 0.28),
            Color(red: 0.14, green: 0.22, blue: 0.32),
            Color(red: 0.08, green: 0.18, blue: 0.24),
            Color(red: 0.12, green: 0.10, blue: 0.20),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static func title(_ style: Font.TextStyle = .title) -> Font {
        .system(style, design: .default, weight: .medium)
    }

    static func buttonLabel(_ style: Font.TextStyle = .headline) -> Font {
        .system(style, design: .default, weight: .semibold)
    }

    static let contentGutter: CGFloat = 22
}

// MARK: - Sign-in surfaces (home Face ID — large type for resident / staff iPads)

enum SignInPageLayout {
    /// The original 3× treatment is retained exactly on iPad. On iPhone it is reduced according to
    /// screen height so a Pro Max keeps the same hierarchy without inheriting iPad-sized controls.
    static var scale: CGFloat {
        guard UIDevice.current.userInterfaceIdiom != .pad else { return 3.0 }
        let height = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        if height >= 850 { return 1.65 }
        if height >= 740 { return 1.35 }
        return 1.15
    }

    static func points(_ base: CGFloat) -> CGFloat { base * scale }

    static var titleFont: Font {
        .system(size: points(28), weight: .medium, design: .default)
    }

    static var headlineFont: Font {
        .system(size: points(17), weight: .semibold, design: .default)
    }

    static var subheadFont: Font {
        .system(size: points(15), weight: .medium, design: .default)
    }

    static var bodyFont: Font {
        .system(size: points(17), weight: .regular, design: .default)
    }

    static var captionFont: Font {
        .system(size: points(12), weight: .regular, design: .default)
    }

    static var labelFont: Font {
        .system(size: points(12), weight: .semibold, design: .default)
    }

    static var iconFont: Font {
        .system(size: points(22), weight: .medium, design: .default)
    }

    static var buttonVerticalPadding: CGFloat { points(10) }
    static var buttonHorizontalPadding: CGFloat { points(18) }
    static var staffToggleVerticalPadding: CGFloat { points(5) }
    static var staffToggleHorizontalPadding: CGFloat { points(10) }
    static var staffToggleFont: Font {
        .system(size: points(11), weight: .medium, design: .default)
    }
    static var staffToggleIconFont: Font {
        .system(size: points(10), weight: .semibold, design: .default)
    }
    static var fieldVerticalPadding: CGFloat { points(12) }
    static var fieldHorizontalPadding: CGFloat { points(14) }
    static var stackSpacing: CGFloat { points(12) }
    static var sectionSpacing: CGFloat { points(20) }
    static var fieldCornerRadius: CGFloat { points(12) }
}

// MARK: - Responsive layout (iPad-friendly, same visual language)

enum BrandLayout {
    static let menuColumnMaxWidth: CGFloat = 560
    /// Height of the tight dissolve band at scroll clip edges.
    static let scrollEdgeFadeHeight: CGFloat = 56
    /// Width of the tight dissolve band at horizontal scroll clip edges.
    static let scrollEdgeFadeWidth: CGFloat = 44
    /// Max fraction of viewport used by the dissolve (keeps fade hugging the edge).
    static let scrollEdgeFadeMaxFraction: CGFloat = 0.10
    /// Extra scroll padding so the last card clears the dissolve when fully scrolled.
    static let scrollEdgeFadeComfortPadding: CGFloat = 12
    /// Extra horizontal padding so the last chip clears the leading/trailing dissolve.
    static let scrollEdgeFadeComfortPaddingHorizontal: CGFloat = 10

    static func contentGutter(for horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        horizontalSizeClass == .regular
            ? 32
            : BrandTheme.contentGutter * currentCompactPhoneScale
    }

    static func isRegularWidth(_ horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        horizontalSizeClass == .regular
    }

    static func orbScale(for horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isRegularWidth(horizontalSizeClass) ? 1.18 : currentCompactPhoneScale
    }

    static func hullScale(for size: CGSize) -> CGFloat {
        let minimumDimension = min(size.width, size.height)
        if minimumDimension >= 560 {
            // Preserve the existing iPad curve exactly (13-inch iPad remains capped at 1.38).
            return min(1.38, max(1.0, minimumDimension / 560))
        }
        return compactPhoneScale(for: size)
    }

    /// A restrained uplift for Plus / Pro Max portrait widths. Standard phones remain at 1× and
    /// iPads deliberately return 1× here because their existing regular-width scaling is separate.
    static func compactPhoneScale(for size: CGSize) -> CGFloat {
        let minimumDimension = min(size.width, size.height)
        guard minimumDimension >= 414, minimumDimension < 560 else { return 1 }
        return min(1.12, 1 + (minimumDimension - 390) / 360)
    }

    /// For reusable controls which do not receive the flow container size. iPad always returns 1 so
    /// its existing regular-width constants remain pixel-for-pixel unchanged.
    static var currentCompactPhoneScale: CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return 1 }
        return compactPhoneScale(for: UIScreen.main.bounds.size)
    }

    static func scaled(_ compact: CGFloat, regular: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isRegularWidth(horizontalSizeClass) ? regular : compact * currentCompactPhoneScale
    }

    static func discoveryEqualizerHeight(for width: CGFloat) -> CGFloat {
        min(280, max(228, width * 0.42))
    }

    static func discoveryFaceDiameterCap(for horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        scaled(136, regular: 152, horizontalSizeClass: horizontalSizeClass)
    }

    static let discoveryPanelScale: CGFloat = 0.98
    static let residentPanelScale: CGFloat = discoveryPanelScale
    static let fullScreenEnvelopeScale: CGFloat = discoveryPanelScale

    static func envelopePadding(in size: CGSize) -> (horizontal: CGFloat, vertical: CGFloat) {
        (max(12, size.width * 0.04), max(16, size.height * 0.03))
    }

    static func panelEnvelopePadding(in size: CGSize) -> (horizontal: CGFloat, vertical: CGFloat) {
        (max(6, size.width * 0.012), max(8, size.height * 0.010))
    }

    static func envelopeContentSize(in size: CGSize, scale: CGFloat = 1.0) -> CGSize {
        let pad = envelopePadding(in: size)
        let w = max(120, (size.width - pad.horizontal * 2) * scale)
        let h = max(160, (size.height - pad.vertical * 2) * scale)
        let d = min(w, h)
        return CGSize(width: d, height: d)
    }

    static func panelContentSize(in containerSize: CGSize, scale: CGFloat = discoveryPanelScale) -> CGSize {
        let d = discoveryOrbDiameter(in: containerSize, scale: scale)
        return CGSize(width: d, height: d)
    }

    /// Circular playback / discovery orb — inscribed in the screen.
    static func discoveryOrbDiameter(in containerSize: CGSize, scale: CGFloat = discoveryPanelScale) -> CGFloat {
        guard containerSize.width > 1, containerSize.height > 1 else { return 320 }
        let pad = panelEnvelopePadding(in: containerSize)
        let availW = max(120, containerSize.width - pad.horizontal * 2)
        let availH = max(120, containerSize.height - pad.vertical * 2)
        return min(availW, availH) * scale
    }

    static func discoveryPanelSize(in containerSize: CGSize) -> CGSize {
        flowOrbPanelSize(in: containerSize)
    }

    /// Panel orb diameter — reserves headroom so heartbeat expansion never exceeds the screen.
    static func flowOrbPanelSize(in containerSize: CGSize) -> CGSize {
        guard containerSize.width > 1, containerSize.height > 1 else {
            return CGSize(width: 300, height: 300)
        }
        let pad = panelEnvelopePadding(in: containerSize)
        let availW = max(120, containerSize.width - pad.horizontal * 2)
        let availH = max(120, containerSize.height - pad.vertical * 2)
        let inset = min(availW, availH) * discoveryPanelScale
        let d = inset / OrbHeartbeat.maxVisualExtentScale
        return CGSize(width: d, height: d)
    }

    static func residentPanelSize(in containerSize: CGSize) -> CGSize {
        discoveryPanelSize(in: containerSize)
    }

    static func fullScreenPanelSize(in containerSize: CGSize) -> CGSize {
        discoveryPanelSize(in: containerSize)
    }

    static func fullScreenEnvelopeSize(in containerSize: CGSize) -> CGSize {
        discoveryPanelSize(in: containerSize)
    }

    static func rectPanelClipShape(
        width: CGFloat,
        height: CGFloat,
        pulse: Double,
        deformStrength: CGFloat = 1
    ) -> GlowingRectEnvelopeShape {
        OrbEnvelopeMorph.rectPanelShape(
            width: width,
            height: height,
            pulse: pulse,
            deformStrength: deformStrength
        )
    }

    static func homeTopSpacer(min viewportHeight: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> CGFloat {
        if isRegularWidth(horizontalSizeClass) {
            return min(72, viewportHeight * 0.08)
        }
        return min(120, viewportHeight * 0.14)
    }

    static func photoPreviewMaxHeight(for viewportHeight: CGFloat) -> CGFloat {
        min(440, max(320, viewportHeight * 0.42))
    }

    static func faceLinkedGridColumns(for horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        if isRegularWidth(horizontalSizeClass) {
            return [
                GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 18),
            ]
        }
        return [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
        ]
    }
}
