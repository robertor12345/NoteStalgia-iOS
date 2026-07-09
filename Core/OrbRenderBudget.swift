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
    /// Ambient background sparkles (present on every page).
    static let sparkleFramesPerSecond: Double = 60
    /// Heavy full-screen procedural session backdrops (nature, leaves) — slower, soft motion
    /// where 60fps would burn budget without a perceptible gain.
    static let ambientFramesPerSecond: Double = 30

    /// Frame interval for the orb shell, respecting Reduce Motion.
    static func shellFrameInterval(reduceMotion: Bool) -> Double {
        1 / (reduceMotion ? reducedMotionFramesPerSecond : shellFramesPerSecond)
    }

    /// Frame interval for inner content motion, respecting Reduce Motion.
    static func contentFrameInterval(reduceMotion: Bool) -> Double {
        1 / (reduceMotion ? reducedMotionFramesPerSecond : contentFramesPerSecond)
    }

    static func nebulaGridColumns(for diameter: CGFloat) -> Int {
        // Cell count grows with the square of this, and each cell runs two domain-warped noise
        // samples per frame — the dominant cost of the always-on orb shell. The post-blur below
        // hides the coarser grid, so a lower density is visually near-identical but ~35% cheaper
        // (e.g. a ~300pt orb drops from ~46² ≈ 2,100 cells to ~37² ≈ 1,370).
        min(40, max(28, Int(diameter / 8.0)))
    }

    /// Post-blur on the volumetric nebula canvas — hides grid splats without extra samples.
    /// Nudged up slightly to keep the coarser grid looking smooth.
    static func nebulaVolumeBlurRadius(for diameter: CGFloat) -> CGFloat {
        max(0.85, diameter * 0.016)
    }

    static var usesLiteNebulaInterior: (CGFloat, CGFloat) -> Bool {
        { diameter, fillOpacity in
            diameter < 88 || fillOpacity < 0.22
        }
    }
}
