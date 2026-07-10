import SwiftUI

/// Prominent home-screen entry for resident Face ID sign-in.
struct ResidentFaceIDHomeSignInButton: View {
    var linkedPatient: CarePatientProfile?
    var isBusy: Bool = false
    var statusMessage: String?
    var onSignIn: () -> Void

    var body: some View {
        VStack(spacing: SignInPageLayout.points(8)) {
            Button(action: onSignIn) {
                HStack(spacing: SignInPageLayout.points(12)) {
                    Image(systemName: "faceid")
                        .font(SignInPageLayout.iconFont)
                        .foregroundStyle(BrandTheme.textOnOrb.opacity(0.98))
                        .accessibilityHidden(true)

                    Group {
                        if isBusy {
                            Text("Verifying…")
                        } else {
                            Text("Sign in with \(PatientBiometricAuth.biometryLabel)")
                        }
                    }
                    .font(SignInPageLayout.subheadFont)
                    .foregroundStyle(BrandTheme.textOnOrb.opacity(0.98))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, SignInPageLayout.buttonVerticalPadding)
                .padding(.horizontal, SignInPageLayout.buttonHorizontalPadding)
                .background { SignInPeachCapsuleFill() }
                .clipShape(Capsule(style: .continuous))
            }
            .buttonStyle(SoftPressButtonStyle(pressedScale: 0.985))
            .disabled(isBusy)
            .opacity(isBusy ? 0.76 : 1)

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(SignInPageLayout.captionFont)
                    .orbOverlayText(muted: true)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
    }

    private var accessibilityHintText: String {
        "Opens your calm music surface."
    }

    private var accessibilityLabelText: String {
        if isBusy { return "Verifying identity" }
        return "Sign in with \(PatientBiometricAuth.biometryLabel)"
    }
}

/// Home / roster entry — Face ID straight into the resident calm surface.
struct PatientFaceIDSignInPanel: View {
    let patient: CarePatientProfile
    var isLinkedProfile: Bool = true
    var isBusy: Bool = false
    var statusMessage: String?
    var onSignIn: () -> Void
    var onUnlink: (() -> Void)?

    private var portraitSize: CGFloat { SignInPageLayout.points(88) }

    var body: some View {
        BrandCard {
            VStack(spacing: SignInPageLayout.sectionSpacing) {
                ResidentPortraitFill(
                    remoteURL: patient.remotePortraitURL,
                    assetName: patient.stockPortraitAssetName,
                    customImage: nil
                )
                    .frame(width: portraitSize, height: portraitSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(BrandTheme.gold.opacity(0.45), lineWidth: 2))
                    .shadow(color: BrandTheme.brown.opacity(0.10), radius: 8, y: 3)
                    .accessibilityHidden(true)

                VStack(spacing: SignInPageLayout.points(6)) {
                    Text(isLinkedProfile ? "Quick resident sign-in" : patient.displayName)
                        .font(SignInPageLayout.labelFont)
                        .foregroundStyle(BrandTheme.textSecondary)
                    Text(isLinkedProfile ? patient.displayName : patient.careContextLabel)
                        .font(SignInPageLayout.titleFont)
                        .foregroundStyle(BrandTheme.textPrimary)
                        .multilineTextAlignment(.center)
                }

                SignInPrimaryButton(title: signInTitle) {
                    onSignIn()
                }
                .disabled(isBusy)
                .opacity(isBusy ? 0.72 : 1)

                if let statusMessage, !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(SignInPageLayout.captionFont)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Opens \(patient.displayName)'s calm surface — floating music symbols, no staff menus.")
                        .font(SignInPageLayout.captionFont)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if isLinkedProfile, let onUnlink {
                    Button("Remove Face ID link") {
                        onUnlink()
                    }
                    .font(SignInPageLayout.captionFont)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .buttonStyle(ChimingPlainButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sign in as \(patient.displayName) with \(PatientBiometricAuth.biometryLabel)")
    }

    private var signInTitle: String {
        if isBusy { return "Verifying…" }
        return "Sign in with \(PatientBiometricAuth.biometryLabel)"
    }
}
