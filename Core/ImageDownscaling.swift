import UIKit

/// POC photo capture stores images straight into `@Published` state (mood/colour analysis,
/// profile portraits). Camera/library assets can be 12+ MP; nothing in this app displays them
/// above a few hundred points, so keep the in-memory copy capped instead of carrying full
/// resolution through every re-render and analysis pass.
extension UIImage {
    /// Returns a copy no larger than `maxDimension` on its longest side, preserving aspect ratio.
    /// Images already at or under the cap are returned unchanged (no redundant redraw).
    func downscaledForDisplay(maxDimension: CGFloat = 1200) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return self }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
