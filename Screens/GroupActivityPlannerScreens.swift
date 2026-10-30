import SwiftUI

// MARK: - Group activities — choose who joins, with recommendations

/// Sits between the roster's "Group activities" button and the group session. Staff pick the
/// residents; the app suggests an activity built around shared tastes, flags who has been
/// overlooked, and shows how the home's group programme is landing. Every suggestion is a tap
/// away from being applied and a tap away from being undone.
struct GroupActivityPlannerView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// "Better one-to-one today" starts collapsed — the planner would see them alone first.
    @State private var showsOneToOneSection = false

    /// The resident list in three sections instead of one score-ordered run that read as random
    /// once scores tied: who would benefit most, who was seen recently, and who the planner would
    /// rather see one-to-one. A–Z inside each.
    private struct ResidentSection: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let residents: [GroupResidentInsight]
    }

    private func residentSections(_ p: GroupActivityPlannerPresentation) -> [ResidentSection] {
        let byName: (GroupResidentInsight, GroupResidentInsight) -> Bool = { $0.displayName < $1.displayName }
        let oneToOne = p.residents.filter { GroupActivityPlanner.betterServedOneToOne($0) != nil }.sorted(by: byName)
        let rest = p.residents.filter { GroupActivityPlanner.betterServedOneToOne($0) == nil }
        let benefit = rest.filter { $0.needScore > 0 }.sorted(by: byName)
        let recent = rest.filter { $0.needScore <= 0 }.sorted(by: byName)
        var out: [ResidentSection] = []
        if !benefit.isEmpty {
            out.append(ResidentSection(id: "benefit", title: "Would benefit most", subtitle: "Overdue a visit, no group lately, or groups visibly do them good.", residents: benefit))
        }
        if !recent.isEmpty {
            out.append(ResidentSection(id: "recent", title: "Seen recently", subtitle: "A one-to-one or a group in the last few days.", residents: recent))
        }
        if !oneToOne.isEmpty {
            out.append(ResidentSection(id: "oneToOne", title: "Better one-to-one today", subtitle: "The planner would see them alone first — still yours to add.", residents: oneToOne))
        }
        return out
    }

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
                }
                .padding(.vertical, 20)
            }
            // Start stays within reach: on iPad the list runs to three screens, and the primary
            // action used to sit under all of it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                startBar
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
                text: "Choose who joins. Suggestions come from each resident’s music, their recent one-to-ones and the groups they’ve already had — you decide.",
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)

            let overdue = p.residents.filter { $0.flags.contains(.overdue) && $0.isRecommendable }.count
            let dueGroup = p.residents.filter { $0.flags.contains(.dueGroup) && $0.isRecommendable }.count
            // Zero counts are noise ("0 overdue a visit"); only the chips with something to say show.
            HStack(spacing: 10) {
                BrandStatusChip(text: "\(selectedIds.count) selected", systemImage: "checkmark.circle", tint: BrandTheme.logoCyan, filled: true)
                if overdue > 0 {
                    BrandStatusChip(text: "\(overdue) overdue a visit", systemImage: "exclamationmark.circle", tint: BrandTheme.statusAttention, filled: true)
                }
                if dueGroup > 0 {
                    BrandStatusChip(text: "\(dueGroup) due a group", systemImage: "person.3", tint: BrandTheme.statusCaution, filled: true)
                }
                if overdue == 0, dueGroup == 0 {
                    BrandStatusChip(text: "Nobody overdue", systemImage: "checkmark.seal", tint: BrandTheme.statusPositive, filled: true)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: Suggested activities

    private func activitiesSection(_ p: GroupActivityPlannerPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: "Suggested activities",
                    systemImage: "sparkles",
                    subtitle: "Built around what residents respond to. Tap one to invite its residents; adjust the list below."
                )
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
            .brandCardSurface(cornerRadius: 16, edge: isChosen ? BrandTheme.logoCyan.opacity(0.7) : BrandTheme.cardBorder, opacity: BrandTheme.rowOpacity)
            .background(isChosen ? BrandTheme.logoCyan.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityIdentifier("planner.activity.\(activity.id)")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .buttonStyle(ChimingPlainButtonStyle())
    }

    // MARK: Staff suggestions

    private func suggestionsCard(_ p: GroupActivityPlannerPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(title: "Suggestions for today", systemImage: "lightbulb")
                ForEach(Array(p.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    if index > 0 { BrandHairline() }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: suggestion.kind.systemImage)
                            .font(.body)
                            .foregroundStyle(suggestion.kind == .oneToOne ? BrandTheme.statusAttention : BrandTheme.gold)
                            .frame(width: 22)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
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
                            .background(Capsule().fill(allIn ? BrandTheme.surfaceInset : BrandTheme.logoCyan.opacity(0.22)))
                            .overlay(Capsule().stroke(allIn ? BrandTheme.insetBorder : BrandTheme.logoCyan.opacity(0.6), lineWidth: 1))
                            .expandedHitArea(vertical: 8, horizontal: 4)
                            .disabled(allIn)
                            .accessibilityIdentifier("planner.suggestion.\(suggestion.id)")
                            .accessibilityLabel("\(allIn ? "Added" : "Add") \(suggestion.residentIds.count) resident\(suggestion.residentIds.count == 1 ? "" : "s")")
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
                HStack(alignment: .top) {
                    BrandSectionHeader(
                        title: "Residents",
                        systemImage: "person.2",
                        subtitle: "Grouped by who would benefit most, A–Z within each. Tap to add or remove."
                    )
                    Button("Clear") {
                        state.groupSession.plannerSelectedIds = []
                        state.groupSession.plannerActivityId = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedIds.isEmpty ? BrandTheme.textTertiary : BrandTheme.gold)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .expandedHitArea(horizontal: 12)
                    .accessibilityIdentifier("planner.clear")
                    .accessibilityLabel("Clear selection")
                    .buttonStyle(ChimingPlainButtonStyle())
                    .disabled(selectedIds.isEmpty)
                }
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(residentSections(p).enumerated()), id: \.element.id) { index, section in
                        if index > 0 { BrandHairline().padding(.top, 6) }
                        sectionHeader(section)
                        if section.id == "oneToOne", !showsOneToOneSection {
                            let selectedHere = section.residents.filter { selectedIds.contains($0.id) }.count
                            Button {
                                withAnimation(CalmMotion.gentle) { showsOneToOneSection = true }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.down")
                                        .font(.caption.weight(.bold))
                                        .accessibilityHidden(true)
                                    Text("Show \(section.residents.count)\(selectedHere > 0 ? " (\(selectedHere) selected)" : "")")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundStyle(BrandTheme.gold)
                                .padding(.vertical, 6)
                                .expandedHitArea(vertical: 8, horizontal: 12)
                            }
                            .buttonStyle(ChimingPlainButtonStyle())
                            .accessibilityIdentifier("planner.showOneToOne")
                            .accessibilityHint("Shows the residents the planner would see one-to-one")
                        } else {
                            ForEach(section.residents) { resident in
                                residentRow(resident, isSelected: selectedIds.contains(resident.id))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func sectionHeader(_ section: ResidentSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("\(section.residents.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(BrandTheme.surfaceInset))
                    .overlay(Capsule().stroke(BrandTheme.insetBorder, lineWidth: 1))
            }
            Text(section.subtitle)
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
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
                            .accessibilityLabel("favourite genre \(resident.favouriteGenre.accessibilityLabel)")
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
            .brandCardSurface(cornerRadius: 14, edge: isSelected ? BrandTheme.logoCyan.opacity(0.7) : BrandTheme.cardBorder, opacity: BrandTheme.rowOpacity)
            .background(isSelected ? BrandTheme.logoCyan.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityIdentifier("planner.resident.\(resident.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(resident.flags.map(\.label).joined(separator: ", "))
        .buttonStyle(ChimingPlainButtonStyle())
    }

    /// The flags under a resident: the same icon-and-word chips as everywhere else, wrapping rather than overflowing.
    private func flagRow(_ flags: [GroupResidentInsight.Flag]) -> some View {
        InsightChipFlow(spacing: 6) {
            ForEach(flags) { flag in
                BrandStatusChip(text: flag.label, systemImage: flagIcon(flag), tint: flagTint(flag))
            }
        }
    }

    private func flagTint(_ flag: GroupResidentInsight.Flag) -> Color {
        switch flag {
        case .overdue: return BrandTheme.statusAttention
        case .dueGroup, .gentle: return BrandTheme.statusCaution
        case .regular: return BrandTheme.statusPositive
        case .smallGroups, .prefersOneToOne: return BrandTheme.statusNeutral
        }
    }

    private func flagIcon(_ flag: GroupResidentInsight.Flag) -> String {
        switch flag {
        case .overdue: return "exclamationmark.circle"
        case .dueGroup: return "clock"
        case .regular: return "checkmark.circle"
        case .smallGroups: return "person.2"
        case .prefersOneToOne: return "person"
        case .gentle: return "heart"
        }
    }

    // MARK: Engagement overview

    private func engagementCard(_ p: GroupActivityPlannerPresentation) -> some View {
        let byId = Dictionary(uniqueKeysWithValues: p.residents.map { ($0.id, $0) })
        let regulars = p.overview.regularIds.compactMap { byId[$0]?.displayName }
        let encourage = p.overview.needEncouragementIds.prefix(6).compactMap { byId[$0]?.displayName }
        let encourageMore = p.overview.needEncouragementIds.count - encourage.count
        let regularsMore = regulars.count - min(regulars.count, 8)
        return BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(title: "Engagement over the last \(GroupActivityPlanner.windowDays) days", systemImage: "chart.bar")
                BrandStatTileRow {
                    BrandStatTile(value: "\(p.overview.groupSessions14d)", label: "Group sessions")
                    BrandStatTile(value: "\(regulars.count)", label: "Regulars", tint: BrandTheme.statusPositive)
                    BrandStatTile(
                        value: "\(p.overview.needEncouragementIds.count)",
                        label: "No group yet",
                        tint: p.overview.needEncouragementIds.isEmpty ? nil : BrandTheme.statusAttention
                    )
                }
                if !encourage.isEmpty {
                    overviewLine("May need encouragement", encourage.joined(separator: ", ") + (encourageMore > 0 ? " and \(encourageMore) more" : ""))
                }
                if !regulars.isEmpty {
                    overviewLine("Taking part regularly", regulars.prefix(8).joined(separator: ", ") + (regularsMore > 0 ? " and \(regularsMore) more" : ""))
                }
                if !p.overview.bestActivities.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Activities that land best")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                            .padding(.bottom, 4)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(Array(p.overview.bestActivities.enumerated()), id: \.element.id) { index, outcome in
                            BrandKeyValueRow(
                                label: outcome.title,
                                value: String(format: "%.1f/10 · %d session%@", outcome.averageEngagement, outcome.sessions, outcome.sessions == 1 ? "" : "s"),
                                valueTint: BrandRatingTone.tint(outOfTen: outcome.averageEngagement),
                                isLast: index == p.overview.bestActivities.count - 1
                            )
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
        .accessibilityElement(children: .combine)
    }

    // MARK: Start

    /// Pinned under the list: the primary action plus the whole-home alternative as a text link.
    private var startBar: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: selectedIds.isEmpty ? "Select residents to start" : "Start group session (\(selectedIds.count))") {
                state.startPlannedGroupSession()
            }
            .accessibilityIdentifier("planner.start")
            .disabled(selectedIds.isEmpty)
            .opacity(selectedIds.isEmpty ? 0.6 : 1)

            Button {
                state.beginGroupSession()
            } label: {
                Text("Whole-home playlist instead")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BrandTheme.gold)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .expandedHitArea(horizontal: 16)
            }
            .accessibilityIdentifier("planner.startAll")
            .buttonStyle(ChimingPlainButtonStyle())
        }
        .frame(maxWidth: BrandLayout.menuColumnMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(BrandTheme.creamDeep.opacity(0.55))
                .overlay(alignment: .top) {
                    Rectangle().fill(BrandTheme.hairline).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
