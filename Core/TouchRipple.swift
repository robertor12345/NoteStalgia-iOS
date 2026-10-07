import SwiftUI
import UIKit

// MARK: - Screen-tap glow ripple

/// A soft glowing ring blooms wherever the screen is tapped. Taps are observed at the window level
/// by a recogniser that never recognises, cancels or delays touches, so buttons, scrolling and
/// gestures behave exactly as before. Drags and scrolls don't ripple — only short taps.
@MainActor
final class TouchRippleStore: ObservableObject {
    static let shared = TouchRippleStore()

    struct Ripple: Identifiable, Equatable {
        let id = UUID()
        let point: CGPoint
    }

    @Published private(set) var ripples: [Ripple] = []

    static let lifetime: TimeInterval = 0.85
    private static let maxConcurrent = 6

    func add(at point: CGPoint) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let ripple = Ripple(point: point)
        ripples.append(ripple)
        if ripples.count > Self.maxConcurrent {
            ripples.removeFirst(ripples.count - Self.maxConcurrent)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.lifetime) { [weak self] in
            self?.ripples.removeAll { $0.id == ripple.id }
        }
    }
}

/// Full-screen, hit-test-transparent layer that draws the active ripples. Observes only the
/// ripple store, so a tap never re-renders the screens underneath.
struct TouchRippleOverlay: View {
    @ObservedObject private var store = TouchRippleStore.shared

    var body: some View {
        ZStack {
            ForEach(store.ripples) { ripple in
                TouchRippleView()
                    .position(ripple.point)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct TouchRippleView: View {
    @State private var expanded = false

    var body: some View {
        // The blurred disc and glowing ring never change shape — only scale and opacity animate —
        // so draw the pre-rendered sprite (see `TouchRippleSprite`) instead of re-blurring and
        // re-shadowing two circles on every frame of the ripple.
        TouchRippleSprite.image()
            .resizable()
            .interpolation(.medium)
            .frame(width: TouchRippleSprite.canvas, height: TouchRippleSprite.canvas)
            .scaleEffect(expanded ? 1 : 0.18)
            .opacity(expanded ? 0 : 0.95)
            .onAppear {
                withAnimation(.easeOut(duration: TouchRippleStore.lifetime * 0.9)) {
                    expanded = true
                }
            }
    }
}

/// The ripple artwork, rendered once at 3× and cached. Prewarmed from `LaunchWarmUp` so the first
/// tap pays nothing.
@MainActor
enum TouchRippleSprite {
    static let diameter: CGFloat = 92
    /// Artwork plus room for the blur (6pt) and shadow (8pt) tails.
    static let canvas: CGFloat = 92 + 2 * 24

    private static var cached: Image?

    static func prewarm() {
        _ = image()
    }

    static func image() -> Image {
        if let cached { return cached }
        let renderer = ImageRenderer(content: TouchRippleArtwork().frame(width: canvas, height: canvas))
        renderer.scale = 3
        renderer.isOpaque = false
        let image = renderer.cgImage.map { Image(decorative: $0, scale: 3) } ?? Image(systemName: "circle")
        cached = image
        return image
    }
}

private struct TouchRippleArtwork: View {
    private let diameter = TouchRippleSprite.diameter

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BrandTheme.logoCyan.opacity(0.55),
                            BrandTheme.logoPink.opacity(0.24),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter * 0.5
                    )
                )
                .blur(radius: 6)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [BrandTheme.logoCyan, BrandTheme.logoPink, BrandTheme.gold, BrandTheme.logoCyan],
                        center: .center
                    ),
                    lineWidth: 2.5
                )
                .blur(radius: 0.8)
                .shadow(color: BrandTheme.logoCyan.opacity(0.9), radius: 8)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Window touch observer

/// Install once (as a background of the root view); attaches the tap observer to the hosting window.
struct WindowTapObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        private weak var installedWindow: UIWindow?
        private let recognizer = PassiveTapRecognizer()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, window !== installedWindow else { return }
            installedWindow?.removeGestureRecognizer(recognizer)
            recognizer.onTap = { point in
                Task { @MainActor in TouchRippleStore.shared.add(at: point) }
            }
            window.addGestureRecognizer(recognizer)
            installedWindow = window
        }
    }
}

/// Watches touches without ever taking part in gesture resolution: it never leaves `.possible`
/// except to fail, cancels nothing and delays nothing.
private final class PassiveTapRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    var onTap: ((CGPoint) -> Void)?

    private var startPoint: CGPoint?
    private var startTime: TimeInterval = 0
    private static let maxMovement: CGFloat = 12
    private static let maxDuration: TimeInterval = 0.6

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard startPoint == nil, let touch = touches.first, let view else { return }
        startPoint = touch.location(in: view)
        startTime = touch.timestamp
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let start = startPoint, let touch = touches.first, let view else { return }
        let p = touch.location(in: view)
        if hypot(p.x - start.x, p.y - start.y) > Self.maxMovement {
            state = .failed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if let start = startPoint, let touch = touches.first, let view,
           touch.timestamp - startTime <= Self.maxDuration {
            let p = touch.location(in: view)
            if hypot(p.x - start.x, p.y - start.y) <= Self.maxMovement {
                onTap?(p)
            }
        }
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func reset() {
        super.reset()
        startPoint = nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
