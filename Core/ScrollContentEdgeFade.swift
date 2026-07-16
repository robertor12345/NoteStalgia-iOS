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
        // Keep the dissolve band narrow and hugging the viewport edge.
        let band = min(BrandLayout.scrollEdgeFadeMaxFraction, fadeHeight / height)

        LinearGradient(
            stops: edgeStops(band: band),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func edgeStops(band: CGFloat) -> [Gradient.Stop] {
        // Steep ramp: opaque almost to the edge, then a short dissolve.
        let ramp = band * 0.72
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
    @ViewBuilder var content: () -> Content

    /// Only the boolean that changes the mask — never store per-frame content offset in `@State`.
    @State private var showTopFade = false
    /// iOS 17 fallback: preference-driven scroll activity with idle settle.
    @State private var lastContentMinY: CGFloat = 0
    @State private var hasSampledOffset = false
    @State private var scrollIdleResetTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            content()
                .background {
                    ScrollViewportMetricsReader(coordinateSpace: coordinateSpace)
                }
        }
        .coordinateSpace(name: coordinateSpace)
        .scrollBounceBehavior(.basedOnSize)
        .mask {
            GeometryReader { geo in
                ScrollViewportEdgeMask(
                    showTop: showTopFade,
                    showBottom: fadeBottom,
                    fadeHeight: fadeHeight,
                    viewportHeight: geo.size.height
                )
            }
        }
        // Prefer the system scroll-phase API (iOS 18+) — fires only on phase edges, not every frame.
        .modifier(ScrollAmbientPauseModifier())
        .onPreferenceChange(ScrollViewportMetricsKey.self) { metrics in
            let nextShowTop = metrics.contentMinY < -6
            if nextShowTop != showTopFade {
                // Disable implicit animation so the mask swap doesn't hitch the scroll compositor.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showTopFade = nextShowTop
                }
            }
            // iOS 17: infer scroll activity from offset deltas (iOS 18 path uses phase changes).
            if #unavailable(iOS 18.0) {
                noteLegacyScrollActivity(contentMinY: metrics.contentMinY)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            scrollIdleResetTask?.cancel()
            AmbientInteractionPause.setScrollActive(false)
        }
    }

    private func noteLegacyScrollActivity(contentMinY: CGFloat) {
        if hasSampledOffset, abs(contentMinY - lastContentMinY) > 0.5 {
            AmbientInteractionPause.setScrollActive(true)
            scrollIdleResetTask?.cancel()
            scrollIdleResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 140_000_000)
                guard !Task.isCancelled else { return }
                AmbientInteractionPause.setScrollActive(false)
            }
        }
        lastContentMinY = contentMinY
        hasSampledOffset = true
    }
}

/// Pauses ambient TimelineViews while a ScrollView is interacting / decelerating (iOS 18+).
private struct ScrollAmbientPauseModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, newPhase in
                AmbientInteractionPause.setScrollActive(newPhase.isScrolling)
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
