import UIKit

extension UIImage {
    /// JPEG no larger than `maxDimension` on its long side — what the portrait endpoint accepts (≤ 300 KB).
    func syncJPEGData(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        var q = quality
        var data = rendered.jpegData(compressionQuality: q)
        while let d = data, d.count > 290_000, q > 0.3 {
            q -= 0.1
            data = rendered.jpegData(compressionQuality: q)
        }
        return data
    }
}
