import SwiftUI

/// Animated logo splash on cold launch — transitions into `FlowRootView`.
struct SplashScreenView: View {
    var onComplete: () -> Void

    @State private var logoIn = false
    @State private var exitFade = false

    var body: some View {
        ZStack {
            BrandBackground()

            VStack(spacing: 20) {
                NoteStalgiaLogoImage(maxHeight: 380)
                    .scaleEffect(logoIn ? 1 : 0.78)
                    .opacity(logoIn ? 1 : 0)
            }
            .padding(.horizontal, BrandTheme.contentGutter)
        }
        .opacity(exitFade ? 0 : 1)
        .task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.spring(response: 0.78, dampingFraction: 0.78, blendDuration: 0)) {
                logoIn = true
            }
            try? await Task.sleep(nanoseconds: 320_000_000)
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.easeInOut(duration: 0.5)) {
                exitFade = true
            }
            try? await Task.sleep(nanoseconds: 520_000_000)
            onComplete()
        }
    }
}
