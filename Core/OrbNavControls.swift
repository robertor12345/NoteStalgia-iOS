import SwiftUI

// MARK: - Shared orb fills for navigation controls

struct OrbSkyCapsuleFill: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BrandTheme.nebulaPurple.opacity(0.42),
                        BrandTheme.cream.opacity(0.92),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(BrandTheme.nebulaCyan.opacity(0.35), lineWidth: 1)
            }
    }
}

struct OrbPeachCapsuleFill: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BrandTheme.nebulaPink.opacity(0.88),
                        BrandTheme.nebulaMagenta.opacity(0.72),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
            }
    }
}

/// Lighter nebula fill for the home sign-in hero.
struct SignInPeachCapsuleFill: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BrandTheme.nebulaPink.opacity(0.92),
                        BrandTheme.nebulaMagenta.opacity(0.78),
                        BrandTheme.nebulaPurple.opacity(0.65),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 0.75)
            }
    }
}

/// Staff sign-in actions on the home screen.
struct SignInSkyCapsuleFill: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BrandTheme.nebulaCyan.opacity(0.35),
                        BrandTheme.cream.opacity(0.95),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(BrandTheme.nebulaLavender.opacity(0.38), lineWidth: 0.75)
            }
    }
}

// MARK: - Primary / secondary navigation (orb-styled)

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BrandTheme.buttonLabel(.headline))
                .foregroundStyle(BrandTheme.textOnOrb)
                .shadow(color: Color(red: 0.42, green: 0.58, blue: 0.72).opacity(0.38), radius: 1.5, y: 1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .background { OrbPeachCapsuleFill() }
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BrandTheme.buttonLabel(.subheadline))
                .foregroundStyle(BrandTheme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background { OrbSkyCapsuleFill() }
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(SoftPressButtonStyle())
    }
}

// MARK: - Compact top-leading back control

enum FlowStaffNavChrome {
    static let buttonMinWidth: CGFloat = 76
}

struct FlowSmallBackButton: View {
    var title: String = "Back"
    var accessibilityLabel: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(BrandTheme.textPrimary.opacity(0.9))
            .frame(minWidth: FlowStaffNavChrome.buttonMinWidth)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.94))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(BrandTheme.gold.opacity(0.24), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(SoftPressButtonStyle(pressedScale: 0.97))
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

struct FlowSmallLogoutButton: View {
    var title: String = "Log out"
    var action: () -> Void

    private var logoutRed: Color {
        Color(red: 0.94, green: 0.36, blue: 0.34)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.caption2.weight(.bold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(logoutRed)
            .frame(minWidth: FlowStaffNavChrome.buttonMinWidth)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.94))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(logoutRed.opacity(0.42), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(SoftPressButtonStyle(pressedScale: 0.97))
        .accessibilityLabel(title)
    }
}

struct FlowTopStaffNavBar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    var backTitle: String = "Back"
    var backAccessibilityLabel: String?
    var onBack: (() -> Void)?
    var onLogout: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let onBack {
                FlowSmallBackButton(
                    title: backTitle,
                    accessibilityLabel: backAccessibilityLabel,
                    action: onBack
                )
            }
            if let onLogout {
                FlowSmallLogoutButton(action: onLogout)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

struct FlowTopBackBar: View {
    var title: String = "Back"
    var accessibilityLabel: String?
    var onLogout: (() -> Void)?
    var action: () -> Void

    var body: some View {
        FlowTopStaffNavBar(
            backTitle: title,
            backAccessibilityLabel: accessibilityLabel,
            onBack: action,
            onLogout: onLogout
        )
    }
}

// MARK: - Sign-in page controls (3× type + tap targets)

struct SignInPrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SignInPageLayout.subheadFont)
                .foregroundStyle(BrandTheme.textOnOrb.opacity(0.98))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SignInPageLayout.buttonVerticalPadding)
                .padding(.horizontal, SignInPageLayout.buttonHorizontalPadding)
                .background { SignInPeachCapsuleFill() }
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(SoftPressButtonStyle(pressedScale: 0.985))
    }
}

struct SignInSecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SignInPageLayout.subheadFont)
                .foregroundStyle(BrandTheme.textPrimary.opacity(0.92))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, SignInPageLayout.buttonVerticalPadding)
                .padding(.horizontal, SignInPageLayout.buttonHorizontalPadding)
                .background { SignInSkyCapsuleFill() }
                .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(SoftPressButtonStyle(pressedScale: 0.985))
    }
}

struct HomeStaffToggleButton: View {
    var isExpanded: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SignInPageLayout.points(6)) {
                Image(systemName: "person.badge.key")
                    .font(SignInPageLayout.staffToggleIconFont)
                Text(isExpanded ? "Hide staff" : "Staff")
                    .font(SignInPageLayout.staffToggleFont)
            }
            .foregroundStyle(BrandTheme.textSecondary.opacity(0.92))
            .padding(.vertical, SignInPageLayout.staffToggleVerticalPadding)
            .padding(.horizontal, SignInPageLayout.staffToggleHorizontalPadding)
            .background {
                Capsule(style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.90))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(BrandTheme.gold.opacity(0.22), lineWidth: 0.75)
                    }
            }
        }
        .buttonStyle(SoftPressButtonStyle(pressedScale: 0.985))
        .accessibilityLabel(isExpanded ? "Hide staff options" : "Show staff options")
    }
}

// MARK: - Tile + icon orb navigation

struct OrbNavTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var iconOrbDiameter: CGFloat {
        56 * BrandLayout.orbScale(for: horizontalSizeClass)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    NoteStalgiaOrbBackdrop(diameter: iconOrbDiameter, pulse: 0.52, glowPulse: 0.68)
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BrandTheme.textOnOrb)
                        .shadow(color: Color(red: 0.38, green: 0.58, blue: 0.78).opacity(0.35), radius: 4, y: 1)
                }
                .frame(width: iconOrbDiameter, height: iconOrbDiameter)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(BrandTheme.title(.headline))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.gold.opacity(0.75))
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.88))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color(red: 0.62, green: 0.84, blue: 0.98).opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(ChimingPlainButtonStyle())
    }
}

struct OrbIconNavButton: View {
    let systemImage: String
    var accessibilityLabel: String
    var diameter: CGFloat = 58
    var action: () -> Void

    private var resolvedDiameter: CGFloat {
        diameter * BrandLayout.currentCompactPhoneScale
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                NoteStalgiaOrbBackdrop(diameter: resolvedDiameter, pulse: 0.5, glowPulse: 0.66)
                Image(systemName: systemImage)
                    .font(.system(size: resolvedDiameter * 0.38, weight: .medium))
                    .foregroundStyle(BrandTheme.textOnOrb)
                    .shadow(color: Color(red: 0.38, green: 0.58, blue: 0.78).opacity(0.35), radius: 4, y: 1)
            }
            .frame(width: resolvedDiameter, height: resolvedDiameter)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct OrbPortraitNavButton: View {
    let portraitAssetName: String
    var customPortraitImage: UIImage?
    var remotePortraitURL: URL? = nil
    let title: String
    let subtitle: String
    var portraitSize: CGFloat?
    var action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var resolvedPortraitSize: CGFloat {
        portraitSize ?? BrandLayout.scaled(52, regular: 64, horizontalSizeClass: horizontalSizeClass)
    }

    private var frameSize: CGFloat { resolvedPortraitSize + 12 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    NoteStalgiaOrbBackdrop(diameter: frameSize, pulse: 0.5, glowPulse: 0.62)
                    ResidentPortraitFill(
                        remoteURL: remotePortraitURL,
                        assetName: portraitAssetName,
                        customImage: customPortraitImage
                    )
                    .frame(width: resolvedPortraitSize, height: resolvedPortraitSize)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                }
                .frame(width: frameSize, height: frameSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BrandTheme.title(.headline))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(BrandTheme.gold.opacity(0.8))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.62, green: 0.84, blue: 0.98).opacity(0.32), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(ChimingPlainButtonStyle())
    }
}

struct OrbFaceLinkedTile: View {
    let portraitAssetName: String
    let title: String
    let subtitle: String
    var action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var backdropDiameter: CGFloat {
        BrandLayout.scaled(132, regular: 148, horizontalSizeClass: horizontalSizeClass)
    }

    private var portraitDiameter: CGFloat {
        BrandLayout.scaled(112, regular: 128, horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    NoteStalgiaOrbBackdrop(diameter: backdropDiameter, pulse: 0.5, glowPulse: 0.64)
                    Image(portraitAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: portraitDiameter, height: portraitDiameter)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2))
                }
                .frame(width: backdropDiameter, height: backdropDiameter)

                VStack(spacing: 2) {
                    Text(title)
                        .font(BrandTheme.title(.headline))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(BrandTheme.cream.opacity(0.90))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(red: 0.62, green: 0.84, blue: 0.98).opacity(0.30), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(ChimingPlainButtonStyle())
    }
}

struct OrbMoodNavOrb: View {
    let title: String
    let index: Int
    let phase: TimeInterval
    let isSelected: Bool
    let onSelect: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var floatY: CGFloat {
        CGFloat(sin(phase * 0.82 + Double(index) * 0.61) * (isSelected ? 2.5 : 4.5))
    }

    private var diameter: CGFloat {
        let base = isSelected ? 88.0 : 76.0
        return base * BrandLayout.orbScale(for: horizontalSizeClass)
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                NoteStalgiaOrbBackdrop(
                    diameter: diameter,
                    pulse: isSelected ? 0.72 : 0.5,
                    glowPulse: isSelected ? 0.78 : 0.6
                )
                Text(title)
                    .font(.system(size: isSelected ? 17 : 15, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? BrandTheme.textOnOrb : BrandTheme.textOnOrb.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(width: diameter * 0.72)
                    .shadow(color: Color(red: 0.38, green: 0.58, blue: 0.78).opacity(0.35), radius: 4, y: 1)
            }
            .frame(width: diameter + 8, height: diameter + 8)
            .offset(y: floatY)
            .scaleEffect(isSelected ? 1.04 : 1)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isSelected)
    }
}

struct OrbPickerLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                NoteStalgiaOrbBackdrop(diameter: 36, pulse: 0.5, glowPulse: 0.62)
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textOnOrb)
            }
            .frame(width: 36, height: 36)
            Text(title)
                .font(BrandTheme.buttonLabel(.subheadline))
                .foregroundStyle(BrandTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background { OrbSkyCapsuleFill() }
        .clipShape(Capsule(style: .continuous))
    }
}

struct OrbSessionSettingsChip: View {
    let title: String
    let systemImage: String
    var isExpanded: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                NoteStalgiaOrbBackdrop(diameter: 28, pulse: 0.5, glowPulse: 0.6)
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BrandTheme.textOnOrb)
            }
            .frame(width: 28, height: 28)
            Text(title)
                .font(.caption.weight(.semibold))
            Image(systemName: isExpanded ? "chevron.compact.down" : "chevron.compact.up")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(BrandTheme.textPrimary.opacity(0.95))
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background { OrbSkyCapsuleFill().opacity(0.92) }
        .clipShape(Capsule(style: .continuous))
    }
}
