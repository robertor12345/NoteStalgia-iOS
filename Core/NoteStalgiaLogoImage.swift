import SwiftUI

/// NoteStalgia mark from asset catalog — full logo (orb + wordmark).
struct NoteStalgiaLogoImage: View {
    var maxHeight: CGFloat = 420

    var body: some View {
        Image("NoteStalgiaLogo")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: maxHeight)
            .accessibilityLabel("NoteStalgia")
    }
}
