import SwiftUI

/// Roster / detail portrait — custom photo when captured, otherwise a name-matched elderly portrait
/// pulled from the internet, with the bundled stock asset as the offline fallback.
struct CarePatientPortraitView: View {
    var assetName: String?
    var customImage: UIImage?
    var size: CGFloat
    var showOrbFrame: Bool = false

    var body: some View {
        Group {
            if showOrbFrame {
                ZStack {
                    NoteStalgiaOrbBackdrop(diameter: size + 12, pulse: 0.5, glowPulse: 0.62)
                    portraitContent
                        .frame(width: size, height: size)
                }
                .frame(width: size + 12, height: size + 12)
            } else {
                portraitContent
                    .frame(width: size, height: size)
            }
        }
    }

    @ViewBuilder
    private var portraitContent: some View {
        ResidentPortraitFill(assetName: assetName, customImage: customImage)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(BrandTheme.gold.opacity(0.42), lineWidth: 2))
    }
}
