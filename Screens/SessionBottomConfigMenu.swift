import SwiftUI
import UIKit

/// Unobtrusive collapsed bar at the bottom of the immersive session; expands for home lighting + share.
///
/// Observes only `ImmersiveSessionVitalsStore` (the home-lighting toggle lives there) rather than
/// the full `SessionPOCState`, so unrelated flow changes don't re-render this menu. `state` is
/// kept as a plain, unobserved reference purely to read the mood snapshot when the share sheet
/// is presented — a one-off read, not something that needs live reactivity here.
struct SessionBottomConfigMenu: View {
    let state: SessionPOCState
    @ObservedObject var vitals: ImmersiveSessionVitalsStore
    @State private var expanded = false
    @State private var showShareSheet = false

    init(state: SessionPOCState) {
        self.state = state
        self.vitals = state.vitals
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                    expanded.toggle()
                }
            } label: {
                OrbSessionSettingsChip(
                    title: expanded ? "Hide" : "Session settings",
                    systemImage: "slider.horizontal.3",
                    isExpanded: expanded
                )
            }
            .accessibilityIdentifier("immersive.settings")
            .buttonStyle(ChimingPlainButtonStyle())
            .accessibilityLabel(expanded ? "Hide session settings" : "Show session settings")

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $vitals.sessionHomeLightsSyncEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Home lighting", systemImage: "lightbulb.led.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text("Let your lights follow the calm — Hue, HomeKit, or anything on the same bridge.")
                                .font(.caption2)
                                .foregroundStyle(BrandTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityIdentifier("immersive.lights")
                    .tint(BrandTheme.goldDeep)
                    .chimeOnChange(of: vitals.sessionHomeLightsSyncEnabled)

                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(BrandTheme.goldDeep)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share a snapshot")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Text("Send a line about this session through the usual share sheet.")
                                    .font(.caption2)
                                    .foregroundStyle(BrandTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(BrandTheme.cream.opacity(0.92))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(BrandTheme.gold.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .accessibilityIdentifier("immersive.share")
                    .buttonStyle(ChimingPlainButtonStyle())
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(BrandTheme.gold.opacity(0.22), lineWidth: 1)
                )
                .padding(.top, 10)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(activityItems: shareItems)
        }
    }

    private var shareItems: [Any] {
        let mood = state.selectedMoodsOrdered.isEmpty
            ? "Calm"
            : state.selectedMoodsOrdered.joined(separator: ", ")
        let text = "Quiet moment with NoteStalgia — feeling: \(mood)."
        return [text]
    }
}

// MARK: - UIKit share sheet

private struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
