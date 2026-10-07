import SwiftUI

// MARK: - Scroll metrics

struct ScrollViewportMetrics: Equatable {
    var contentHeight: CGFloat = 0
    var contentMinY: CGFloat = 0
}

enum ScrollViewportMetricsKey: PreferenceKey {
    static var defaultValue = ScrollViewportMetrics()

    static func reduce(value: inout ScrollViewportMetrics, nextValue: () -> ScrollViewportMetrics) {
        value = nextValue()
    }
}

struct ScrollViewportMetricsReader: View {
    var coordinateSpace: String

    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ScrollViewportMetricsKey.self,
                value: ScrollViewportMetrics(
                    contentHeight: geo.size.height,
                    contentMinY: geo.frame(in: .named(coordinateSpace)).minY
                )
            )
        }
    }
}

// MARK: - Tight viewport edge mask (mask only — no scrim cap)

private struct ScrollViewportEdgeMask: View {
    var showTop: Bool
    var showBottom: Bool
    var fadeHeight: CGFloat
    var viewportHeight: CGFloat

    var body: some View {
        let height = max(viewportHeight, 1)
        // Keep the dissolve band hugging the viewport edge, but never thinner than ~28pt
        // so phone menus still read a soft cutoff under the staff chrome.
        let band = max(
            28 / height,
            min(BrandLayout.scrollEdgeFadeMaxFraction, fadeHeight / height)
        )

        LinearGradient(
            stops: edgeStops(band: band),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func edgeStops(band: CGFloat) -> [Gradient.Stop] {
        let ramp = band * 0.85
        var stops: [Gradient.Stop] = []

        if showTop {
            stops.append(.init(color: .clear, location: 0))
            stops.append(.init(color: .black, location: ramp))
        } else {
            stops.append(.init(color: .black, location: 0))
        }

        let opaqueThrough = showBottom ? (1 - ramp) : 1
        if opaqueThrough > (stops.last?.location ?? 0) {
            stops.append(.init(color: .black, location: opaqueThrough))
        }

        if showBottom {
            stops.append(.init(color: .clear, location: 1))
        } else if stops.last?.location != 1 {
            stops.append(.init(color: .black, location: 1))
        }

        return stops
    }
}

// MARK: - Scroll viewport with edge dissolve

struct ScrollViewportEdgeFade<Content: View>: View {
    var coordinateSpace: String
    var fadeHeight: CGFloat = BrandLayout.scrollEdgeFadeHeight
    var fadeBottom: Bool = true
    var fadeTop: Bool = true
    @ViewBuilder var content: () -> Content

    @State private var showTopFade = false
    @State private var lastContentMinY: CGFloat = 0
    @State private var hasSampledOffset = false
    @State private var scrollIdleResetTask: Task<Void, Never>?
    @State private var holdsAmbientScrollPause = false

    var body: some View {
        ScrollView {
            content()
                .background {
                    // iOS 18+ reads offsets from `onScrollGeometryChange` / `onScrollPhaseChange`;
                    // skip the per-frame geometry preference there so scrolling does no extra layout.
                    if #unavailable(iOS 18.0) {
                        ScrollViewportMetricsReader(coordinateSpace: coordinateSpace)
                    }
                }
        }
        .coordinateSpace(name: coordinateSpace)
        .scrollBounceBehavior(.basedOnSize)
        .mask {
            GeometryReader { geo in
                ScrollViewportEdgeMask(
                    showTop: fadeTop && showTopFade,
                    showBottom: fadeBottom,
                    fadeHeight: fadeHeight,
                    viewportHeight: geo.size.height
                )
            }
        }
        .modifier(ScrollAmbientPauseModifier(holdsAmbientScrollPause: $holdsAmbientScrollPause))
        .modifier(ScrollTopFadeOffsetModifier(showTopFade: $showTopFade, enabled: fadeTop))
        .onPreferenceChange(ScrollViewportMetricsKey.self) { metrics in
            if #unavailable(iOS 18.0) {
                applyTopFade(offsetY: -metrics.contentMinY)
                noteLegacyScrollActivity(contentMinY: metrics.contentMinY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            scrollIdleResetTask?.cancel()
            releaseAmbientScrollPauseIfNeeded()
        }
    }

    private func applyTopFade(offsetY: CGFloat) {
        let nextShowTop = offsetY > 2
        guard nextShowTop != showTopFade else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showTopFade = nextShowTop
        }
    }

    private func noteLegacyScrollActivity(contentMinY: CGFloat) {
        if hasSampledOffset, abs(contentMinY - lastContentMinY) > 0.5 {
            acquireAmbientScrollPauseIfNeeded()
            scrollIdleResetTask?.cancel()
            scrollIdleResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 140_000_000)
                guard !Task.isCancelled else { return }
                releaseAmbientScrollPauseIfNeeded()
            }
        }
        lastContentMinY = contentMinY
        hasSampledOffset = true
    }

    private func acquireAmbientScrollPauseIfNeeded() {
        guard !holdsAmbientScrollPause else { return }
        holdsAmbientScrollPause = true
        AmbientInteractionPause.beginScroll()
    }

    private func releaseAmbientScrollPauseIfNeeded() {
        guard holdsAmbientScrollPause else { return }
        holdsAmbientScrollPause = false
        AmbientInteractionPause.endScroll()
    }
}

/// iOS 18+: drive the top dissolve from `contentOffset` (reliable under `safeAreaInset`).
private struct ScrollTopFadeOffsetModifier: ViewModifier {
    @Binding var showTopFade: Bool
    var enabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), enabled {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offsetY in
                let next = offsetY > 2
                guard next != showTopFade else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showTopFade = next
                }
            }
        } else {
            content
        }
    }
}

private struct ScrollAmbientPauseModifier: ViewModifier {
    @Binding var holdsAmbientScrollPause: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, newPhase in
                let scrolling = newPhase.isScrolling
                if scrolling {
                    guard !holdsAmbientScrollPause else { return }
                    holdsAmbientScrollPause = true
                    AmbientInteractionPause.beginScroll()
                } else if holdsAmbientScrollPause {
                    holdsAmbientScrollPause = false
                    AmbientInteractionPause.endScroll()
                }
            }
        } else {
            content
        }
    }
}

// MARK: - Horizontal scroll edge dissolve

private struct HorizontalContentMetrics: Equatable {
    var size: CGSize = .zero
    var minX: CGFloat = 0
}

private struct HorizontalScrollViewportEdgeMask: View {
    var showLeading: Bool
    var showTrailing: Bool
    var fadeWidth: CGFloat
    var viewportWidth: CGFloat

    var body: some View {
        let width = max(viewportWidth, 1)
        let band = max(32 / width, min(0.14, fadeWidth / width))
        let ramp = band * 0.9

        LinearGradient(
            stops: edgeStops(ramp: ramp),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func edgeStops(ramp: CGFloat) -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = []

        if showLeading {
            stops.append(.init(color: .clear, location: 0))
            stops.append(.init(color: .black, location: ramp))
        } else {
            stops.append(.init(color: .black, location: 0))
        }

        let opaqueThrough = showTrailing ? (1 - ramp) : 1
        if opaqueThrough > (stops.last?.location ?? 0) {
            stops.append(.init(color: .black, location: opaqueThrough))
        }

        if showTrailing {
            stops.append(.init(color: .clear, location: 1))
        } else if stops.last?.location != 1 {
            stops.append(.init(color: .black, location: 1))
        }

        return stops
    }
}

private struct HorizontalScrollFadeSnapshot: Equatable {
    var offsetX: CGFloat
    var contentWidth: CGFloat
    var viewportWidth: CGFloat
}

/// Horizontal `ScrollView` with leading/trailing dissolve when content is clipped.
struct HorizontalScrollEdgeFade<Content: View>: View {
    var coordinateSpace: String
    var fadeWidth: CGFloat = BrandLayout.scrollEdgeFadeWidth
    /// When the row fits without scrolling, centre it under the rest of the column instead of
    /// hugging the leading edge (the wing filter pills looked off-centre on iPad).
    var centersWhenContentFits: Bool = true
    @ViewBuilder var content: () -> Content

    @State private var showLeadingFade = false
    @State private var showTrailingFade = false
    @State private var viewportWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var lastOffsetX: CGFloat = 0

    // The row sizes to its content's height (`fixedSize` on the vertical axis) instead of a
    // preference-measured `@State` height, which stayed at its seed value — tall rows (admin
    // trend cards) were clipped to ~40pt and spilled over the cards below.
    private var contentFits: Bool {
        viewportWidth > 1 && contentWidth > 1 && contentWidth <= viewportWidth + 2
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content()
                .padding(.horizontal, BrandLayout.scrollEdgeFadeComfortPaddingHorizontal)
                // Measured on the intrinsic content (inside the centring frame below).
                .onGeometryChange(for: HorizontalContentMetrics.self) { proxy in
                    HorizontalContentMetrics(
                        size: proxy.size,
                        minX: proxy.frame(in: .named(coordinateSpace)).minX
                    )
                } action: { metrics in
                    contentWidth = metrics.size.width
                    // Covers iOS 17; on iOS 18 the geometry modifier owns offsets while
                    // scrolling, but this still seeds the resting clipped/trailing state.
                    let offsetX = -metrics.minX
                    lastOffsetX = offsetX
                    applyFades(
                        offsetX: offsetX,
                        contentWidth: metrics.size.width,
                        viewportWidth: viewportWidth
                    )
                }
                .frame(minWidth: centersWhenContentFits && contentFits ? viewportWidth : nil, alignment: .center)
        }
        .coordinateSpace(name: coordinateSpace)
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            viewportWidth = width
            applyFades(offsetX: lastOffsetX, contentWidth: contentWidth, viewportWidth: width)
        }
        .mask {
            HorizontalScrollViewportEdgeMask(
                showLeading: showLeadingFade,
                showTrailing: showTrailingFade,
                fadeWidth: fadeWidth,
                viewportWidth: viewportWidth
            )
        }
        .modifier(
            HorizontalScrollGeometryFadeModifier(
                showLeadingFade: $showLeadingFade,
                showTrailingFade: $showTrailingFade,
                lastOffsetX: $lastOffsetX
            )
        )
    }

    private func applyFades(offsetX: CGFloat, contentWidth: CGFloat, viewportWidth: CGFloat) {
        guard viewportWidth > 1, contentWidth > 1 else { return }
        let clipped = contentWidth > viewportWidth + 2
        let nextLeading = offsetX > 2
        let nextTrailing = clipped && (contentWidth - offsetX > viewportWidth + 2)
        guard nextLeading != showLeadingFade || nextTrailing != showTrailingFade else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showLeadingFade = nextLeading
            showTrailingFade = nextTrailing
        }
    }
}

private struct HorizontalScrollGeometryFadeModifier: ViewModifier {
    @Binding var showLeadingFade: Bool
    @Binding var showTrailingFade: Bool
    @Binding var lastOffsetX: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: HorizontalScrollFadeSnapshot.self) { geometry in
                HorizontalScrollFadeSnapshot(
                    offsetX: geometry.contentOffset.x,
                    contentWidth: geometry.contentSize.width,
                    viewportWidth: geometry.containerSize.width
                )
            } action: { _, snapshot in
                lastOffsetX = snapshot.offsetX
                guard snapshot.viewportWidth > 1, snapshot.contentWidth > 1 else { return }
                let clipped = snapshot.contentWidth > snapshot.viewportWidth + 2
                let nextLeading = snapshot.offsetX > 2
                let nextTrailing = clipped
                    && (snapshot.contentWidth - snapshot.offsetX > snapshot.viewportWidth + 2)
                guard nextLeading != showLeadingFade || nextTrailing != showTrailingFade else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showLeadingFade = nextLeading
                    showTrailingFade = nextTrailing
                }
            }
        } else {
            content
        }
    }
}

// Back-compat alias used by group session screen.
struct ScrollViewportWithEdgeFade<Content: View>: View {
    var coordinateSpace: String
    var fadeHeight: CGFloat = BrandLayout.scrollEdgeFadeHeight
    var fadeTop: Bool = true
    var fadeBottom: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollViewportEdgeFade(
            coordinateSpace: coordinateSpace,
            fadeHeight: fadeHeight,
            fadeBottom: fadeBottom,
            fadeTop: fadeTop,
            content: content
        )
    }
}

extension View {
    func scrollViewportWithEdgeFade(
        coordinateSpace: String = "scrollFade",
        fadeHeight: CGFloat = BrandLayout.scrollEdgeFadeHeight,
        fadeTop: Bool = true,
        fadeBottom: Bool = true
    ) -> some View {
        ScrollViewportWithEdgeFade(
            coordinateSpace: coordinateSpace,
            fadeHeight: fadeHeight,
            fadeTop: fadeTop,
            fadeBottom: fadeBottom
        ) {
            self
        }
    }
}
