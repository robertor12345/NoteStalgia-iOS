import SwiftUI

/// Full-screen canvas from `FlowRootView` — use for envelope sizing so discovery matches resident.
private struct FlowContainerSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

/// Root safe-area insets — lets full-bleed layers inside the safe area reach the physical edges.
private struct FlowSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

private struct FlowOrbShellSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

private struct FlowOrbPulseAnchorKey: EnvironmentKey {
    static let defaultValue: Date = .distantPast
}

private struct FlowPanelPulseIntensityKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private struct FlowPanelPulseSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1
}

private struct FlowAmbientPausedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var flowContainerSize: CGSize {
        get { self[FlowContainerSizeKey.self] }
        set { self[FlowContainerSizeKey.self] = newValue }
    }

    var flowSafeAreaInsets: EdgeInsets {
        get { self[FlowSafeAreaInsetsKey.self] }
        set { self[FlowSafeAreaInsetsKey.self] = newValue }
    }

    /// Live persistent orb dimensions — discovery media must clip to this exactly.
    var flowOrbShellSize: CGSize {
        get { self[FlowOrbShellSizeKey.self] }
        set { self[FlowOrbShellSizeKey.self] = newValue }
    }

    /// Shared pulse clock for shell + in-orb discovery content.
    var flowOrbPulseAnchor: Date {
        get { self[FlowOrbPulseAnchorKey.self] }
        set { self[FlowOrbPulseAnchorKey.self] = newValue }
    }

    var flowPanelPulseIntensity: CGFloat {
        get { self[FlowPanelPulseIntensityKey.self] }
        set { self[FlowPanelPulseIntensityKey.self] = newValue }
    }

    var flowPanelPulseSpeed: Double {
        get { self[FlowPanelPulseSpeedKey.self] }
        set { self[FlowPanelPulseSpeedKey.self] = newValue }
    }

    /// True while the keyboard is up or a staff scroll view is moving — the same signal that
    /// freezes the sparkles and persistent orb. Small self-driven orbs (roster cards, mood orbs,
    /// picker labels) pause their own timers on it so typing and scrolling get the whole frame.
    var flowAmbientPaused: Bool {
        get { self[FlowAmbientPausedKey.self] }
        set { self[FlowAmbientPausedKey.self] = newValue }
    }
}
