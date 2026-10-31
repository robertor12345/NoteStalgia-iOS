import SwiftUI

// MARK: - Log an activity held outside the app

/// Staff write up something that happened away from the app — bingo, a chair-exercise class, a visiting singer: what it
/// was, when, who came and how each of them was. Saves as a group record (`ActivityLogDraft`), so it reaches the
/// profile, the planner and the Home Admin programme card without a second system. iPad first: the form sits in one
/// centred column, three cards and a pinned Save.
struct ActivityLogView: View {
    @ObservedObject var state: SessionPOCState
    @State private var showRecent = false
    @State private var pendingRemoval: GroupSessionRecord?
    /// The icon slot in a category chip grows with the text, so a larger icon never runs into its label.
    @ScaledMetric(relativeTo: .subheadline) private var chipIconSlot: CGFloat = 18

    private var draft: ActivityLogDraft { state.groupSession.activityDraft }
    private var errors: [String: String] { state.groupSession.activityErrors }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: state.isHouseholdAccount ? "Back to home" : state.groupSession.activityReturnPhase != nil ? "Back to profile" : "Back to roster",
                onBack: { state.cancelActivityLog() },
                onLogout: { state.signOutSupervisor() },
                topAligned: true
            ) {
                VStack(spacing: 22) {
                    header
                    recentCard
                    whatCard
                    if draft.solo { howCard } else { whoCard }
                    notesCard
                }
                .padding(.vertical, 20)
                .environment(\.fieldFeedback, FieldFeedback(errors: errors) { state.clearActivityError($0) })
            }
            .scrollDismissesKeyboard(.interactively)
            // Save stays within reach: the list of residents runs long.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
            }
        }
        .onAppear {
            if !state.isSignedIn { state.phase = .home }
        }
        .confirmationDialog(
            "Remove this activity?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { record in
            Button("Remove “\(record.displayTitle)”", role: .destructive) { state.withdrawActivity(record) }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("It disappears from the dashboards and the planner. The record of it stays in the history.")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<ActivityLogDraft, Value>, clearing field: String? = nil) -> Binding<Value> {
        Binding(
            get: { state.groupSession.activityDraft[keyPath: keyPath] },
            set: {
                state.groupSession.activityDraft[keyPath: keyPath] = $0
                if let field { state.clearActivityError(field) }
            }
        )
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            FadeInTitle(text: "Log an activity", delay: 0)
            FadeInLine(
                text: draft.solo
                    ? (state.isHouseholdAccount
                        ? "For anything that happened away from the app — a walk in the garden, a visit, a game. Say how they were, and it counts towards their insights."
                        : "For something you did with them on their own — a walk, a visit, a game. Say how they were, and it counts as a one-to-one visit.")
                    : "For anything that happened away from the app — bingo, a class, a visit. Say who came and how each of them was, and it counts towards the dashboards and the group planner.",
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)

            let unnoted = draft.unnotedIds.count
            HStack(spacing: 10) {
                if draft.solo {
                    if unnoted > 0 {
                        BrandStatusChip(text: "Say how they were", systemImage: "pencil.circle", tint: BrandTheme.statusCaution, filled: true)
                    } else {
                        BrandStatusChip(text: "Ready to save", systemImage: "checkmark.circle", tint: BrandTheme.logoCyan, filled: true)
                    }
                } else {
                    BrandStatusChip(text: "\(draft.attendeeIds.count) came", systemImage: "person.2", tint: BrandTheme.logoCyan, filled: true)
                    if unnoted > 0 {
                        BrandStatusChip(text: "\(unnoted) to note", systemImage: "pencil.circle", tint: BrandTheme.statusCaution, filled: true)
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: Logged recently

    /// The last few activities logged for this home, to correct a mistake or take one off the dashboards. Records are
    /// immutable once synced, so a correction is a new record that replaces the old one and a removal a withdrawal.
    @ViewBuilder private var recentCard: some View {
        let recent = state.recentLoggedActivities()
        if !recent.isEmpty {
            BrandCard {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation(CalmMotion.subtle) { showRecent.toggle() }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            BrandSectionHeader(
                                title: "Logged recently",
                                systemImage: "clock.arrow.circlepath",
                                subtitle: showRecent ? "Do one again, correct a mistake, or take one off." : "\(recent.count) recent — tap to repeat, correct or remove one."
                            )
                            Image(systemName: showRecent ? "chevron.up" : "chevron.down")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(BrandTheme.gold)
                                .frame(width: 24, height: 44)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityIdentifier("activity.recent")
                    .accessibilityValue(showRecent ? "Expanded" : "Collapsed")
                    if showRecent {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, record in
                            if index > 0 { BrandHairline() }
                            recentRow(record)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
        }
    }

    private func recentRow(_ record: GroupSessionRecord) -> some View {
        let when = record.date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        var detail = "\(when) · \(record.participantIds.count) attended"
        if let engagement = record.engagementRating { detail += " · engagement \(engagement)/10" }
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            HStack(spacing: 10) {
                SecondaryButton(title: "Correct") {
                    state.beginEditingActivity(record)
                    withAnimation(CalmMotion.subtle) { showRecent = false }
                }
                .accessibilityLabel("Correct \(record.displayTitle), \(when)")
                .accessibilityIdentifier("activity.recent.correct.\(record.id.uuidString.prefix(8))")
                SecondaryButton(title: "Repeat") {
                    state.beginRepeatingActivity(record)
                    withAnimation(CalmMotion.subtle) { showRecent = false }
                }
                .accessibilityLabel("Repeat \(record.displayTitle) with the same \(record.participantIds.count == 1 ? "person" : "people")")
                .accessibilityIdentifier("activity.recent.repeat.\(record.id.uuidString.prefix(8))")
                SecondaryButton(title: "Remove") {
                    pendingRemoval = record
                }
                .accessibilityLabel("Remove \(record.displayTitle), \(when)")
                .accessibilityIdentifier("activity.recent.remove.\(record.id.uuidString.prefix(8))")
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: What happened

    private var whatCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: "What happened",
                    systemImage: "list.bullet.rectangle",
                    subtitle: "Pick the nearest match, then when it started and for how long."
                )
                if draft.isRepeat {
                    BrandMessageTile(
                        text: draft.solo ? "Same again. Say how they were this time." : "Same activity and people, as of now. Say how each of them was this time.",
                        kind: .notice
                    )
                    .accessibilityIdentifier("activity.repeating")
                }
                if draft.replacing != nil {
                    BrandMessageTile(text: "You are correcting an earlier entry. Saving replaces it; the original stays in the history.", kind: .notice)
                        .accessibilityIdentifier("activity.correcting")
                    Button {
                        state.stopEditingActivity()
                    } label: {
                        Text("Stop correcting")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.gold)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityIdentifier("activity.stopCorrecting")
                }
                InsightChipFlow(spacing: 8) {
                    ForEach(OtherActivityKind.allCases) { kind in
                        kindChip(kind)
                    }
                }
                if let message = errors["activity.kind"] {
                    FieldErrorLabel(message: message, identifier: "activity.kind")
                }
                if draft.kind == .other {
                    OnboardingField(
                        title: "Activity name",
                        text: binding(\.customTitle),
                        prompt: "e.g. Poetry afternoon",
                        identifier: "activity.title",
                        maxLength: ActivityLogDraft.titleMaxLength
                    )
                }

                BrandHairline()

                HStack(spacing: 12) {
                    Text("Started")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                    Spacer(minLength: 8)
                    DatePicker("Started", selection: binding(\.date, clearing: "activity.when"), in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .tint(BrandTheme.gold)
                        .accessibilityIdentifier("activity.when")
                }
                .frame(minHeight: 44)
                if let message = errors["activity.when"] {
                    FieldErrorLabel(message: message, identifier: "activity.when")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How long")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                    InsightChipFlow(spacing: 8) {
                        ForEach(ActivityLogDraft.durationChoices, id: \.self) { minutes in
                            BrandSelectableChip(label: Self.durationLabel(minutes), selected: draft.durationMinutes == minutes) {
                                state.groupSession.activityDraft.durationMinutes = minutes
                            }
                            .accessibilityIdentifier("activity.duration.\(minutes)")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private static func durationLabel(_ minutes: Int) -> String {
        switch minutes {
        case 60: return "1 hour"
        case 90: return "1½ hours"
        case 120: return "2 hours"
        default: return "\(minutes) min"
        }
    }

    private func kindChip(_ kind: OtherActivityKind) -> some View {
        let selected = draft.kind == kind
        return Button {
            state.groupSession.activityDraft.kind = kind
            state.clearActivityError("activity.kind")
        } label: {
            HStack(spacing: 6) {
                // The tick and the icon share one slot, so choosing a category never changes a chip's width and re-wraps
                // the rows under the finger.
                ZStack {
                    Image(systemName: kind.systemImage).opacity(selected ? 0 : 1)
                    Image(systemName: "checkmark").opacity(selected ? 1 : 0)
                }
                .font(.caption.weight(.bold))
                .frame(width: chipIconSlot)
                .accessibilityHidden(true)
                Text(kind.label)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(BrandTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(Capsule().fill(selected ? BrandTheme.logoCyan.opacity(0.26) : BrandTheme.surfaceInset))
            .overlay(Capsule().stroke(selected ? BrandTheme.logoCyan.opacity(0.7) : BrandTheme.insetBorder, lineWidth: 1))
            .expandedHitArea(vertical: 4)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("activity.kind.\(kind.rawValue)")
    }

    // MARK: Who came

    private var whoCard: some View {
        let residents = state.activityLogResidents()
        return BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "Who came",
                    systemImage: "person.2",
                    subtitle: "Tap a name, then say how they were. Everyone who came needs a line."
                )
                if draft.unnotedIds.count >= 2 {
                    Menu {
                        ForEach(GroupParticipantState.activityOptions) { option in
                            Button {
                                state.setActivityResponseForUnnoted(option)
                            } label: {
                                Label(option.label, systemImage: option.systemImage)
                            }
                        }
                    } label: {
                        Label("Note the rest as…", systemImage: "wand.and.stars")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandTheme.gold)
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("activity.noteRest")
                    .accessibilityHint("Gives everyone you have not yet noted the same line")
                }
                if let message = errors["activity.attendees"] {
                    FieldErrorLabel(message: message, identifier: "activity.attendees")
                }
                if let message = errors["activity.responses"] {
                    FieldErrorLabel(message: message, identifier: "activity.responses")
                }
                ForEach(residents) { resident in
                    residentRow(resident)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    /// A Care at home account logs for one person, so there is no list: their name, and how they were.
    private var howCard: some View {
        let resident = state.activityLogResidents().first
        let response = resident.flatMap { draft.responses[$0.id] }
        return BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "How were they?",
                    systemImage: "face.smiling",
                    subtitle: "Pick the one that is closest."
                )
                if let resident {
                    HStack(spacing: 12) {
                        CarePatientPortraitView(
                            assetName: resident.stockPortraitAssetName,
                            customImage: state.portraitImage(for: resident.id),
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resident.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text(response?.label ?? "Say how they were")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(response == nil ? BrandTheme.statusCaution : BrandTheme.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    if let message = errors["activity.responses"] {
                        FieldErrorLabel(message: message, identifier: "activity.responses")
                    }
                    InsightChipFlow(spacing: 8) {
                        ForEach(GroupParticipantState.activityOptions) { option in
                            responseChip(option, selected: response == option, for: resident)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func residentRow(_ resident: CarePatientProfile) -> some View {
        let isAttending = draft.isAttending(resident.id)
        let response = draft.responses[resident.id]
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                state.toggleActivityAttendee(resident.id)
            } label: {
                HStack(spacing: 12) {
                    CarePatientPortraitView(
                        assetName: resident.stockPortraitAssetName,
                        customImage: state.portraitImage(for: resident.id),
                        size: 44
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resident.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                        if isAttending {
                            Text(response.map { $0.label } ?? "Say how they were")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(response == nil ? BrandTheme.statusCaution : BrandTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isAttending ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2)
                        .foregroundStyle(isAttending ? BrandTheme.logoCyan : BrandTheme.gold.opacity(0.7))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(ChimingPlainButtonStyle())
            .accessibilityIdentifier("activity.resident.\(resident.displayName)")
            .accessibilityAddTraits(isAttending ? .isSelected : [])
            .accessibilityValue(isAttending ? (response?.label ?? "Came, not noted yet") : "Did not come")

            if isAttending {
                InsightChipFlow(spacing: 8) {
                    ForEach(GroupParticipantState.activityOptions) { option in
                        responseChip(option, selected: response == option, for: resident)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCardSurface(
            cornerRadius: 14,
            edge: isAttending ? BrandTheme.logoCyan.opacity(0.7) : BrandTheme.cardBorder,
            opacity: BrandTheme.rowOpacity
        )
        .background(isAttending ? BrandTheme.logoCyan.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(CalmMotion.subtle, value: isAttending)
    }

    private func responseChip(_ option: GroupParticipantState, selected: Bool, for resident: CarePatientProfile) -> some View {
        let tint = option.brandTint
        return Button {
            state.setActivityResponse(option, for: resident.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.systemImage)
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
                Text(option.label)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(BrandTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 36)
            .background(Capsule().fill(selected ? tint.opacity(0.30) : BrandTheme.surfaceInset))
            .overlay(Capsule().stroke(selected ? tint : BrandTheme.insetBorder, lineWidth: selected ? 1.5 : 1))
            .expandedHitArea(vertical: 4)
        }
        .buttonStyle(ChimingPlainButtonStyle())
        // The row above already reads "Name, Enjoyed it" once chosen; the chip says what pressing it does.
        .accessibilityLabel("\(option.label) for \(resident.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("activity.response.\(resident.displayName).\(option.rawValue)")
    }

    // MARK: Notes

    private var notesCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "Anything to add?",
                    systemImage: "text.bubble",
                    subtitle: "Optional. What went well, or what to try next time."
                )
                OnboardingField(
                    title: "Note",
                    text: binding(\.note),
                    prompt: "A line for the next carer",
                    identifier: "activity.note",
                    axis: .vertical,
                    maxLength: ActivityLogDraft.noteMaxLength
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Save

    private var saveBar: some View {
        let came = draft.attendeeIds.count
        let unnoted = draft.unnotedIds.count
        let summary: String = {
            if draft.solo { return unnoted > 0 ? "Say how they were to save" : "Ready to save" }
            if came == 0 { return "Nobody added yet" }
            let names = "\(came) came"
            return unnoted == 0 ? names : "\(names) · \(unnoted) still to note"
        }()
        return VStack(spacing: 8) {
            Text(summary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(BrandTheme.textSecondary)
                .accessibilityIdentifier("activity.summary")
            PrimaryButton(title: draft.replacing == nil ? "Save activity" : "Save correction") {
                state.saveActivityLog()
            }
            .accessibilityIdentifier("activity.save")
        }
        .frame(maxWidth: BrandLayout.menuColumnMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .brandBottomBarSurface()
    }
}
