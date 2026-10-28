import SwiftUI

// MARK: - Group activities — choose who joins, with recommendations

/// Sits between the roster's "Group activities" button and the group session. Staff pick the
/// residents; the app suggests an activity built around shared tastes, flags who has been
/// overlooked, and shows how the home's group programme is landing. Every suggestion is a tap
/// away from being applied and a tap away from being undone.
struct GroupActivityPlannerView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var presentation: GroupActivityPlannerPresentation {
        state.groupActivityPlannerPresentation()
    }

    private var selectedIds: Set<UUID> {
        state.groupSession.plannerSelectedIds
    }

    var body: some View {
        let p = presentation
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to roster",
                onBack: { state.cancelGroupActivityPlanning() },
                onLogout: { state.signOutSupervisor() },
                topAligned: true
            ) {
                VStack(spacing: 22) {
                    header(p)
                    if !p.activities.isEmpty {
                        activitiesSection(p)
                    }
                    if !p.suggestions.isEmpty {
                        suggestionsCard(p)
                    }
                    residentPicker(p)
                    engagementCard(p)
                    startButtons
                }
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            if !state.isSignedIn {
                state.phase = .home
            }
        }
    }

    // MARK: Header

    private func header(_ p: GroupActivityPlannerPresentation) -> some View {
        VStack(spacing: 8) {
            FadeInTitle(text: "Group activities", delay: 0)
            FadeInLine(
                text: "Choose who joins. Suggestions come from each resident's music, their recent one-to-ones and the groups they've already had — you decide.",
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)

            let overdue = p.residents.filter { $0.flags.contains(.overdue) && $0.isRecommendable }.count
            let dueGroup = p.residents.filter { $0.flags.contains(.dueGroup) && $0.isRecommendable }.count
            HStack(spacing: 10) {
                summaryChip("\(selectedIds.count) selected", tint: BrandTheme.logoCyan)
                summaryChip("\(overdue) overdue a visit", tint: BrandTheme.nebulaSalmon)
                summaryChip("\(dueGroup) due a group", tint: BrandTheme.gold)
            }
            .padding(.top, 4)
        }
    }

    private func summaryChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.22)))
            .overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1))
    }

    // MARK: Suggested activities

    private func activitiesSection(_ p: GroupActivityPlannerPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suggested activities")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("Built around what residents respond to. Tap one to invite its residents; adjust the list below.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(p.activities) { activity in
                    activityRow(activity, isChosen: state.groupSession.plannerActivityId == activity.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func activityRow(_ activity: GroupActivitySuggestion, isChosen: Bool) -> some View {
        Button {
            state.chooseGroupActivity(activity)
        } label: {
            HStack(spacing: 14) {
                if let genre = activity.genre {
                    Image(genre.artworkAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundStyle(BrandTheme.gold)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(BrandTheme.title(.headline))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text(activity.reason)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChosen ? BrandTheme.logoCyan : BrandTheme.gold.opacity(0.6))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isChosen ? BrandTheme.logoCyan.opacity(0.14) : BrandTheme.creamMid.opacity(0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isChosen ? BrandTheme.logoCyan.opacity(0.55) : BrandTheme.gold.opacity(0.22), lineWidth: 1)
                    }
            }
        }
        .accessibilityIdentifier("planner.activity.\(activity.id)")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .buttonStyle(ChimingPlainButtonStyle())
    }

    // MARK: Staff suggestions

    private func suggestionsCard(_ p: GroupActivityPlannerPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suggestions for today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                ForEach(p.suggestions) { suggestion in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: suggestion.kind.systemImage)
                            .font(.body)
                            .foregroundStyle(suggestion.kind == .oneToOne ? BrandTheme.nebulaSalmon : BrandTheme.gold)
                            .frame(width: 22)
                            .padding(.top, 2)
                        Text(suggestion.text)
                            .font(.callout)
                            .foregroundStyle(BrandTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if suggestion.canAdd {
                            let allIn = suggestion.residentIds.allSatisfy { selectedIds.contains($0) }
                            Button(allIn ? "Added" : "Add") {
                                state.addGroupPlannerResidents(suggestion.residentIds)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(allIn ? BrandTheme.textSecondary : BrandTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(allIn ? BrandTheme.creamMid.opacity(0.7) : BrandTheme.logoCyan.opacity(0.22)))
                            .overlay(Capsule().stroke(BrandTheme.logoCyan.opacity(allIn ? 0.2 : 0.55), lineWidth: 1))
                            .disabled(allIn)
                            .accessibilityIdentifier("planner.suggestion.\(suggestion.id)")
                            .buttonStyle(ChimingPlainButtonStyle())
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Resident picker

    private func residentPicker(_ p: GroupActivityPlannerPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Residents")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textSecondary)
                    Spacer()
                    Button("Clear") {
                        state.groupSession.plannerSelectedIds = []
                        state.groupSession.plannerActivityId = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.gold)
                    .accessibilityIdentifier("planner.clear")
                    .buttonStyle(ChimingPlainButtonStyle())
                    .disabled(selectedIds.isEmpty)
                }
                Text("Sorted by who would benefit most. Tap to add or remove.")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                LazyVStack(spacing: 10) {
                    ForEach(p.residents) { resident in
                        residentRow(resident, isSelected: selectedIds.contains(resident.id))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func residentRow(_ resident: GroupResidentInsight, isSelected: Bool) -> some View {
        Button {
            state.toggleGroupPlannerResident(resident.id)
        } label: {
            HStack(spacing: 12) {
                CarePatientPortraitView(
                    assetName: resident.stockPortraitAssetName,
                    customImage: state.portraitImage(for: resident.id),
                    size: 44
                )
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(resident.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Image(resident.favouriteGenre.artworkAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .accessibilityLabel(resident.favouriteGenre.accessibilityLabel)
                    }
                    Text(resident.statusLine)
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !resident.flags.isEmpty {
                        flagRow(resident.flags)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? BrandTheme.logoCyan : BrandTheme.gold.opacity(0.7))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? BrandTheme.logoCyan.opacity(0.12) : BrandTheme.creamMid.opacity(0.85))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? BrandTheme.logoCyan.opacity(0.5) : BrandTheme.gold.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .accessibilityIdentifier("planner.resident.\(resident.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(resident.flags.map(\.label).joined(separator: ", "))
        .buttonStyle(ChimingPlainButtonStyle())
    }

    private func flagRow(_ flags: [GroupResidentInsight.Flag]) -> some View {
        HStack(spacing: 6) {
            ForEach(flags) { flag in
                Text(flag.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(flagTint(flag).opacity(0.22)))
                    .overlay(Capsule().stroke(flagTint(flag).opacity(0.45), lineWidth: 1))
            }
        }
    }

    private func flagTint(_ flag: GroupResidentInsight.Flag) -> Color {
        switch flag {
        case .overdue: return BrandTheme.nebulaSalmon
        case .dueGroup: return BrandTheme.gold
        case .regular: return BrandTheme.nebulaTeal
        case .smallGroups, .prefersOneToOne: return BrandTheme.nebulaLavender
        case .gentle: return BrandTheme.nebulaPeach
        }
    }

    // MARK: Engagement overview

    private func engagementCard(_ p: GroupActivityPlannerPresentation) -> some View {
        let byId = Dictionary(uniqueKeysWithValues: p.residents.map { ($0.id, $0) })
        let regulars = p.overview.regularIds.compactMap { byId[$0]?.displayName }
        let encourage = p.overview.needEncouragementIds.prefix(6).compactMap { byId[$0]?.displayName }
        return BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Engagement over the last \(GroupActivityPlanner.windowDays) days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text("\(p.overview.groupSessions14d) group session\(p.overview.groupSessions14d == 1 ? "" : "s") · \(regulars.count) regular\(regulars.count == 1 ? "" : "s") · \(p.overview.needEncouragementIds.count) with no group yet")
                    .font(.callout)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !encourage.isEmpty {
                    overviewLine("May need encouragement", encourage.joined(separator: ", ") + (p.overview.needEncouragementIds.count > 6 ? "…" : ""))
                }
                if !regulars.isEmpty {
                    overviewLine("Taking part regularly", regulars.prefix(8).joined(separator: ", ") + (regulars.count > 8 ? "…" : ""))
                }
                if !p.overview.bestActivities.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activities that land best")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                        ForEach(p.overview.bestActivities) { outcome in
                            HStack {
                                Text(outcome.title)
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f/10 engagement · %d session%@", outcome.averageEngagement, outcome.sessions, outcome.sessions == 1 ? "" : "s"))
                                    .font(.caption2)
                                    .foregroundStyle(BrandTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func overviewLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(BrandTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Start

    private var startButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: selectedIds.isEmpty ? "Select residents to start" : "Start group session (\(selectedIds.count))") {
                state.startPlannedGroupSession()
            }
            .accessibilityIdentifier("planner.start")
            .disabled(selectedIds.isEmpty)
            .opacity(selectedIds.isEmpty ? 0.6 : 1)
            .padding(.horizontal, 24)

            SecondaryButton(title: "Whole-home playlist instead") {
                state.beginGroupSession()
            }
            .accessibilityIdentifier("planner.startAll")
            .padding(.horizontal, 24)
        }
    }
}
