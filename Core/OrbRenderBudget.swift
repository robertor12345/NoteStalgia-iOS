import CoreGraphics

/// Tunable orb render cost — drives the ~10s pulse and ambient motion at a silky 60fps,
/// while keeping heavy procedural backdrops on a calmer cadence to protect the frame budget.
enum OrbRenderBudget {
    /// Orb shell breathe + glow. 60fps for fluid, ethereal motion.
    static let shellFramesPerSecond: Double = 60
    /// Honoured when Reduce Motion is on — calmer and cheaper.
    static let reducedMotionFramesPerSecond: Double = 30
    /// Inner orb content drift and interactive glyph layouts.
    static let contentFramesPerSecond: Double = 60
    /// Ambient background sparkles (present on every page). 45fps reads as smooth drift while
    /// leaving headroom for a denser particle field + the nebula shell.
    static let sparkleFramesPerSecond: Double = 45
    /// Heavy full-screen procedural session backdrops (nature, leaves) — slower, soft motion
    /// where 60fps would burn budget without a perceptible gain.
    static let ambientFramesPerSecond: Double = 30
    /// Genre-glyph constellation while a playlist is expanded — drift is already muted.
    static let glyphPlayingFramesPerSecond: Double = 30

    /// Frame interval for the orb shell, respecting Reduce Motion.
    static func shellFrameInterval(reduceMotion: Bool) -> Double {
        1 / (reduceMotion ? reducedMotionFramesPerSecond : shellFramesPerSecond)
    }

    /// Frame interval for inner content motion, respecting Reduce Motion.
    static func contentFrameInterval(reduceMotion: Bool) -> Double {
        1 / (reduceMotion ? reducedMotionFramesPerSecond : contentFramesPerSecond)
    }

    /// Frame interval for ambient sparkles.
    static func sparkleFrameInterval(reduceMotion: Bool) -> Double {
        1 / (reduceMotion ? reducedMotionFramesPerSecond : sparkleFramesPerSecond)
    }

    static func nebulaGridColumns(for diameter: CGFloat) -> Int {
        // Cell count grows with the square of this, and each cell runs two domain-warped noise
        // samples per frame — the dominant cost of the always-on orb shell. The post-blur below
        // hides the coarser grid, so a slightly lower density is visually near-identical and
        // frees budget for the denser sparkle field.
        min(36, max(26, Int(diameter / 8.6)))
    }

    /// Post-blur on the volumetric nebula canvas — hides grid splats without extra samples.
    /// Nudged up slightly to keep the coarser grid looking smooth.
    static func nebulaVolumeBlurRadius(for diameter: CGFloat) -> CGFloat {
        max(0.95, diameter * 0.017)
    }

    static var usesLiteNebulaInterior: (CGFloat, CGFloat) -> Bool {
        { diameter, fillOpacity in
            diameter < 96 || fillOpacity < 0.22
        }
    }
}
