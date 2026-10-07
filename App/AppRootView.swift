import SwiftUI

/// App shell — persistent orb navigation lives in `FlowRootView`.
struct AppRootView: View {
    var body: some View {
        ZStack {
            FlowRootView()
            // Glowing ripple wherever the screen is tapped (drawn above everything, never hit-tested).
            TouchRippleOverlay()
        }
        .background(WindowTapObserver())
        // Every surface is now dark cards on the cosmic canvas (the old cream theme is gone),
        // so system-drawn pieces — status bar, steppers, segmented pickers, menus, keyboard,
        // text-field placeholders — need the dark appearance to stay legible.
        .preferredColorScheme(.dark)
        .environment(\.font, Font.system(.body, design: .rounded))
        .task {
            // Warm the shared audio session so the first chime/music plays without delay.
            AppAudioSession.activate()
        }
    }
}
