import SwiftUI
import UIKit
import PhotosUI

// MARK: - Patient roster

struct CarePatientListView: View {
    @ObservedObject var state: SessionPOCState
    @FocusState private var searchFocused: Bool

    private var presentation: CareRosterPresentation {
        state.rosterPresentation()
    }

    private var currentHome: CareHome? {
        state.currentHome()
    }

    private var canSwitchHome: Bool {
        (state.currentSupervisorAccount()?.homeIds.count ?? 0) > 1
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: state.isCareHomeAdmin ? "Back to home insights" : "Back to start screen",
                onBack: {
                    // A home lead came from their dashboard; staff came from the start screen.
                    if state.isCareHomeAdmin {
                        state.returnToAdminDashboardFromRoster()
                    } else {
                        state.selectedCarePatientId = nil
                        state.navigateStaffToHome()
                    }
                },
                onLogout: { state.signOutSupervisor() },
                topAligned: true
            ) {
                VStack(spacing: 22) {
                    rosterHeader

                    findResidentCard

                    // While searching, results sit directly under the field — the home summary
                    // and session shortcuts would otherwise push them below the fold.
                    if !presentation.isSearching {
                        careHomeSentimentCard

                        PrimaryButton(title: "Start discovery for new resident") {
                            state.beginNewResidentDiscovery()
                        }
                        .accessibilityIdentifier("roster.startDiscovery")
                        .padding(.horizontal, 24)

                        groupSessionsCard
                    }

                    rosterSections

                    if !presentation.isSearching, !presentation.isBrowsingAll {
                        SecondaryButton(title: browseAllTitle) {
                            state.rosterBrowsingAllResidents = true
                        }
                        .accessibilityIdentifier("roster.browseAll")
                        .padding(.horizontal, 24)
                    }

                    if presentation.isBrowsingAll {
                        SecondaryButton(title: "Back to today’s roster") {
                            state.rosterBrowsingAllResidents = false
                        }
                        .accessibilityIdentifier("roster.backToToday")
                        .padding(.horizontal, 24)
                    }

                    if canSwitchHome {
                        SecondaryButton(title: "Switch care home") {
                            state.switchHome()
                        }
                        .accessibilityIdentifier("roster.switchHome")
                        .padding(.horizontal, 24)
                    }

                    if !presentation.isSearching {
                        FeedbackPreferencesCard()
                    }
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            StreamAudioCache.prefetchWarmCatalog()
            if !state.isSignedIn {
                state.phase = .home
            } else if state.currentHomeId == nil {
                state.phase = .careHomePicker
            }
        }
    }

    private var browseAllTitle: String {
        if let wing = presentation.wingFilterName, let count = presentation.wingResidentCount {
            return "Browse all \(count) on \(wing)"
        }
        return "Browse all \(presentation.totalActiveResidents) residents"
    }

    private var rosterHeaderLine: String {
        if let wing = presentation.wingFilterName, let count = presentation.wingResidentCount {
            return "\(count) resident\(count == 1 ? "" : "s") on \(wing) · curated for today"
        }
        return "\(presentation.totalActiveResidents) residents · curated for today"
    }

    private var rosterHeader: some View {
        VStack(spacing: 8) {
            FadeInTitle(text: presentation.homeName, delay: 0)
            FadeInLine(
                text: rosterHeaderLine,
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
        }
    }

    /// Search, wing filter and display mode in one card, so nothing floats on the orb.
    private var findResidentCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(title: "Find a resident", systemImage: "magnifyingglass")
                searchField
                if !presentation.isSearching, let home = currentHome {
                    wingFilterRow(home: home)
                        // The scroller pads its content; pull it back so the chips line up with the field.
                        .padding(.horizontal, -BrandLayout.scrollEdgeFadeComfortPaddingHorizontal)
                    displayModePicker
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BrandTheme.textSecondary)
                .accessibilityHidden(true)
            TextField("Search residents", text: $state.rosterSearchQuery, prompt: BrandTheme.fieldPrompt("Search name, room, or wing"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .accessibilityIdentifier("roster.search")
            if !state.rosterSearchQuery.isEmpty {
                Button {
                    state.rosterSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(BrandTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ChimingPlainButtonStyle())
                .accessibilityLabel("Clear search")
            }
        }
        .font(.body)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .frame(minHeight: 48)
        .background(BrandTheme.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BrandTheme.insetBorder, lineWidth: 1)
        )
    }

    private func wingFilterRow(home: CareHome) -> some View {
        HorizontalScrollEdgeFade(coordinateSpace: "rosterWingFilter", centersWhenContentFits: false) {
            HStack(spacing: 10) {
                wingChip(title: "All wings", wingId: nil)
                ForEach(home.wings) { wing in
                    wingChip(title: wing.name, wingId: wing.id)
                }
            }
        }
    }

    private func wingChip(title: String, wingId: String?) -> some View {
        let selected = state.rosterSelectedWingId == wingId || (wingId == nil && state.rosterSelectedWingId == nil)
        return BrandSelectableChip(label: title, selected: selected) {
            if wingId == nil {
                state.rosterSelectedWingId = nil
            } else if state.rosterSelectedWingId == wingId {
                state.rosterSelectedWingId = nil
            } else {
                state.rosterSelectedWingId = wingId
            }
        }
        .accessibilityIdentifier("roster.wing.\(title)")
    }

    private var displayModePicker: some View {
        BrandSegmentedChoice(
            title: "Display",
            selection: $state.rosterDisplayMode,
            options: CareRosterDisplayMode.allCases.map { BrandChoiceOption(value: $0, label: $0.label) }
        )
        .chimeOnChange(of: state.rosterDisplayMode)
        .accessibilityIdentifier("roster.displayMode")
    }

    // `LazyVStack` defers building each row until it's about to scroll into view (this still
    // lives inside `CenteredScrollScreen`'s `ScrollView`, so laziness applies even though the
    // outer content stack is eager). Matters most in "browse all residents" mode, which can
    // list every active resident in the home instead of the day's curated ~20.
    @ViewBuilder
    private var rosterSections: some View {
        if state.carePatients.isEmpty {
            // Only reachable if the welcome gate hit its cap before the roster finished seeding.
            VStack(spacing: 14) {
                BreathingCalmProgressView(diameter: 48)
                Text("Loading residents…")
                    .font(BrandTheme.orbHintFont())
                    .orbOverlayText(muted: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .accessibilityElement(children: .combine)
        } else {
            rosterSectionList
        }
    }

    private var rosterSectionList: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(presentation.sections) { section in
                BrandCard {
                    VStack(alignment: .leading, spacing: 4) {
                        BrandSectionHeader(
                            title: section.title,
                            systemImage: sectionIcon(section.kind),
                            subtitle: section.subtitle
                        )
                        if section.patientIds.isEmpty {
                            // A search that matches nobody says so and says what to try, instead of an empty card.
                            BrandHairline()
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "questionmark.circle")
                                    .foregroundStyle(BrandTheme.statusNeutral)
                                    .accessibilityHidden(true)
                                Text("No resident matches “\(state.rosterSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines))”. Try a first name, a room number or a wing.")
                                    .font(.subheadline)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 12)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("roster.noMatches")
                        }
                        if !section.patientIds.isEmpty {
                            BrandRowsTile(spacing: 0, verticalPadding: 0) {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(section.patientIds.enumerated()), id: \.element) { index, patientId in
                                        if let patient = state.carePatient(id: patientId) {
                                            if index > 0 { BrandHairline() }
                                            rosterRow(for: patient)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func sectionIcon(_ kind: CareRosterSection.Kind) -> String {
        switch kind {
        case .pinned: return "star.fill"
        case .recent: return "clock.arrow.circlepath"
        case .due: return "calendar.badge.exclamationmark"
        case .wing: return "building.2"
        case .searchResults: return "magnifyingglass"
        case .allResidents: return "person.2.fill"
        }
    }

    /// One resident inside a section card: portrait, name, where they are, how the last visit went
    /// (icon + word, never colour alone) and a pin. Rows are separated by hairlines, not boxes.
    @ViewBuilder
    private func rosterRow(for patient: CarePatientProfile) -> some View {
        let subtitle = rosterSubtitle(for: patient)
        let chip = rosterChip(for: patient)
        let isPinned = state.rosterPinnedResidentIds.contains(patient.id)

        if state.rosterDisplayMode == .compact {
            HStack(spacing: 8) {
                Button {
                    openPatient(patient)
                } label: {
                    HStack(spacing: 12) {
                        CarePatientPortraitView(
                            assetName: patient.stockPortraitAssetName,
                            customImage: state.portraitImage(for: patient.id),
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(patient.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textSecondary)
                                .lineLimit(2)
                            BrandStatusChip(text: chip.text, systemImage: chip.systemImage, tint: chip.tint)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.gold.opacity(0.8))
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ChimingPlainButtonStyle())
                .accessibilityIdentifier("roster.resident.\(patient.displayName)")

                pinButton(for: patient, isPinned: isPinned)
            }
        } else {
            ZStack(alignment: .topTrailing) {
                OrbPortraitNavButton(
                    portraitAssetName: patient.stockPortraitAssetName,
                    customPortraitImage: state.portraitImage(for: patient.id),
                    title: patient.displayName,
                    subtitle: subtitle,
                    chip: chip,
                    embedded: true
                ) {
                    openPatient(patient)
                }
                .accessibilityIdentifier("roster.resident.\(patient.displayName)")

                pinButton(for: patient, isPinned: isPinned)
            }
        }
    }

    private func pinButton(for patient: CarePatientProfile, isPinned: Bool) -> some View {
        Button {
            state.toggleRosterPin(patient.id)
        } label: {
            Image(systemName: isPinned ? "star.fill" : "star")
                .font(.body)
                .foregroundStyle(isPinned ? BrandTheme.statusCaution : BrandTheme.textSecondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.interaction, Rectangle())
        }
        .accessibilityIdentifier("roster.pin.\(patient.displayName)")
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityLabel(isPinned ? "Unpin \(patient.displayName)" : "Pin \(patient.displayName)")
    }

    private func openPatient(_ patient: CarePatientProfile) {
        state.recordResidentRosterView(patient.id)
        state.selectedCarePatientId = patient.id
        state.transitionToPhase(.carePatientDetail)
    }

    /// Kept short so the roster scans at a glance — where they are and when they were last seen.
    /// How the visit went is the status chip; full sentiment averages live on the profile.
    private func rosterSubtitle(for patient: CarePatientProfile) -> String {
        var parts = [patient.careContextLabel]
        if let last = state.recordsForPatient(patient.id).first {
            parts.append("Last visit \(relativeDay(last.date))")
        }
        return parts.joined(separator: " · ")
    }

    private func rosterChip(for patient: CarePatientProfile) -> OrbPortraitNavChip {
        if let last = state.recordsForPatient(patient.id).first {
            return OrbPortraitNavChip(
                text: "\(last.calmPercent)% at ease",
                systemImage: "leaf.fill",
                tint: CareAtEaseTone.tint(percent: last.calmPercent)
            )
        }
        return OrbPortraitNavChip(text: "No visits yet", systemImage: "clock", tint: BrandTheme.statusNeutral)
    }

    private func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        default: return "\(days) days ago"
        }
    }

    private var careHomeSentimentCard: some View {
        let overview = state.careHomeSentimentOverview()
        return Group {
            if overview.hasData {
                BrandCard {
                    VStack(alignment: .leading, spacing: 12) {
                        BrandSectionHeader(
                            title: "Carer observations across the home",
                            systemImage: "heart.text.square",
                            subtitle: "Rolling averages of the 1–10 observations recorded after recent sessions."
                        )
                        SentimentAverageTiles(summary: overview)
                        Text("\(overview.sessionCount) rated session\(overview.sessionCount == 1 ? "" : "s") on file · \(BrandRatingTone.legend)")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// Group activities on the same card grammar as the dashboard's Group programme: what it does,
    /// how the last group went (four tiles, tone-tinted) and the one way in.
    private var groupSessionsCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "Group sessions",
                    systemImage: "person.3.fill",
                    subtitle: "Pick who joins. The app suggests an activity from shared tastes, flags residents who have been overlooked and builds the playlist from the people you choose."
                )
                if let last = state.latestGroupSessionRatings() {
                    Text("Last group session")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.textSecondary)
                    GroupRatingTiles(ratings: last)
                }
                SecondaryButton(title: "Group activities") {
                    state.beginGroupActivityPlanning()
                }
                .accessibilityIdentifier("roster.groupMode")
                BrandHairline()
                // Not everything is music: bingo, a class, a visit. Logging it keeps the dashboards and the planner honest.
                VStack(alignment: .leading, spacing: 10) {
                    Text("Held something away from the app?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.textSecondary)
                    if let last = state.latestLoggedActivity() {
                        Label(last.line, systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("roster.lastLoggedActivity")
                    }
                    SecondaryButton(title: "Log an activity") {
                        state.beginActivityLog()
                    }
                    .accessibilityIdentifier("roster.logActivity")
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

/// The four 1–10 ratings from a group check-in, tinted by the same tone as the carer observations.
struct GroupRatingTiles: View {
    let ratings: GroupSessionRatings
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var items: [(label: String, value: Int)] {
        [
            ("Morale / affect", ratings.morale),
            ("Alertness", ratings.alertness),
            ("Orientation", ratings.orientation),
            ("Engagement", ratings.engagement),
        ]
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: BrandLayout.statTileColumns(regularWidth: BrandLayout.isRegularWidth(horizontalSizeClass), dynamicTypeSize: dynamicTypeSize)
        )
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.label) { item in
                BrandStatTile(
                    value: "\(item.value)",
                    label: item.label,
                    detail: "out of 10",
                    tint: BrandRatingTone.tint(outOfTen: Double(item.value))
                )
            }
        }
    }
}

// MARK: - New resident discovery — age input (feeds snippet algorithm)

struct CareDiscoveryAgeInputView: View {
    @ObservedObject var state: SessionPOCState
    @FocusState private var ageFocused: Bool
    @State private var errorMessage: String?

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to roster",
                onBack: { state.abandonNewResidentAgeInput() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 24) {
                    FadeInTitle(text: "About this resident", delay: 0)
                    FadeInLine(
                        text: "Age and nationality help us order the listening pass — era first, with a soft cultural music bias.",
                        delay: 0.08
                    )

                    BrandCard {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Age")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                TextField("Age", text: $state.newResidentAgeDraft, prompt: BrandTheme.fieldPrompt("e.g. 82"))
                                    .accessibilityIdentifier("discovery.age")
                                    .keyboardType(.numberPad)
                                    .focused($ageFocused)
                                    .font(.title2.weight(.medium))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(BrandTheme.creamMid.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                                    )
                                Text("Peak listening years (roughly teens through twenties) order calm clips by era.")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            ResidentNationalityMenuField(
                                title: "Nationality",
                                selection: $state.newResidentNationalityDraft,
                                caption: "Gently weights familiar genres and moods — never overrides their live reactions."
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    if let errorMessage, !errorMessage.isEmpty {
                        BrandMessageTile(text: errorMessage)
                            .padding(.horizontal, 4)
                            .accessibilityIdentifier("discovery.error")
                    }

                    PrimaryButton(title: "Begin listening discovery") {
                        errorMessage = state.continueNewResidentDiscoveryFromAgeInput()
                    }
                    .accessibilityIdentifier("discovery.begin")
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            if !state.isSignedIn { state.phase = .home }
        }
    }
}

// MARK: - New resident profile capture (after first session)

struct CareNewResidentProfileView: View {
    @ObservedObject var state: SessionPOCState
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var errorMessage: String?
    @State private var isLoadingPhoto = false
    @State private var photoLoadError: String?
    @State private var showDiscardConfirm = false

    var body: some View {
        ScreenFadeIn {
            // Leaving here deletes the provisional resident and their whole discovery session, so
            // the control says "Discard" and asks first instead of posing as a plain Back.
            CenteredScrollScreen(
                backTitle: "Discard",
                backAccessibilityLabel: "Discard new resident",
                onBack: { showDiscardConfirm = true },
                onLogout: { state.signOutSupervisor() },
                logoutWarning: "This resident hasn’t been saved yet."
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Save this resident", delay: 0)
                    FadeInLine(
                        text: "So the next supervisor can recognise them on the roster.",
                        delay: 0.08
                    )

                    BrandCard {
                        VStack(spacing: 18) {
                            photoSection

                            profileField(title: "Name", text: $state.newResidentProfileNameDraft, prompt: "Full name or preferred name")

                            profileField(title: "Age", text: $state.newResidentProfileAgeDraft, prompt: "Age", keyboard: .numberPad)

                            ResidentNationalityMenuField(
                                title: "Nationality",
                                selection: $state.newResidentProfileNationalityDraft
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 4)

                    if let errorMessage, !errorMessage.isEmpty {
                        BrandMessageTile(text: errorMessage)
                            .padding(.horizontal, 4)
                            .accessibilityIdentifier("newResident.error")
                    }

                    PrimaryButton(title: "Save to roster") {
                        errorMessage = state.saveNewResidentProfile()
                        if errorMessage == nil {
                            CalmExperienceFeedback.signInSuccess()
                        }
                    }
                    .accessibilityIdentifier("newResident.save")
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $state.newResidentProfilePhoto)
                .ignoresSafeArea()
        }
        .onAppear {
            // Demo recordings only: stand-in portrait so the scripted flow can reach "Save to roster".
            if DemoLaunchOptions.autoPhoto, state.newResidentProfilePhoto == nil {
                state.newResidentProfilePhoto = UIImage(named: "PortraitWoman06")
            }
        }
        .confirmationDialog("Discard this resident?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard resident and discovery", role: .destructive) {
                state.cancelNewResidentProfileSave()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Their listening discovery and photo won’t be saved.")
        }
        .onChange(of: photoItem) { _, new in
            guard let new else { return }
            isLoadingPhoto = true
            photoLoadError = nil
            // Decode off-main (ImageIO thumbnail) and show progress — see `PhotoLoadStatusLine`.
            Task.detached(priority: .userInitiated) {
                let data = try? await new.loadTransferable(type: Data.self)
                let image = data.flatMap { UIImage.decodedThumbnail(from: $0, maxDimension: 600) }
                await MainActor.run {
                    isLoadingPhoto = false
                    if let image {
                        state.newResidentProfilePhoto = image
                    } else {
                        photoLoadError = "That photo couldn’t be opened. Try another one."
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 14) {
            if let photo = state.newResidentProfilePhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(BrandTheme.gold.opacity(0.45), lineWidth: 2))
                    .shadow(color: BrandTheme.brown.opacity(0.12), radius: 10, y: 4)
            } else {
                ZStack {
                    NoteStalgiaOrbBackdrop(diameter: 132, pulse: 0.5, glowPulse: 0.62)
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(BrandTheme.goldDeep)
                }
                .frame(width: 132, height: 132)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                OrbPickerLabel(title: "Choose photo", systemImage: "photo.stack")
            }
            .accessibilityIdentifier("newResident.choosePhoto")
            .buttonStyle(ChimingPlainButtonStyle())

            PhotoLoadStatusLine(isLoading: isLoadingPhoto, error: photoLoadError)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    OrbPickerLabel(title: "Take photo", systemImage: "camera.fill")
                }
                .accessibilityIdentifier("newResident.takePhoto")
                .buttonStyle(ChimingPlainButtonStyle())
            }
        }
    }

    private func profileField(
        title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            TextField(title, text: text, prompt: BrandTheme.fieldPrompt(prompt))
                .accessibilityIdentifier("newResident.\(title.lowercased())")
                .keyboardType(keyboard)
                .font(.body)
                .foregroundStyle(BrandTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(BrandTheme.creamMid.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Native `Menu` dropdown styled like the cream staff form fields — flag + country name.
struct ResidentNationalityMenuField: View {
    let title: String
    @Binding var selection: ResidentNationality
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)

            Menu {
                Picker(title, selection: $selection) {
                    ForEach(ResidentNationality.menuOrder) { nationality in
                        Text(nationality.menuLabel).tag(nationality)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(selection.flagEmoji)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(selection.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandTheme.goldDeep.opacity(0.85))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandTheme.creamMid.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                )
            }
            .accessibilityIdentifier("nationality.menu")
            .accessibilityLabel("\(title), \(selection.displayName)")
            .accessibilityHint("Opens a list of nationalities")
            .chimeOnChange(of: selection)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Environment & IoT prep (lighting, immersive / VR)

struct CareSessionPrepView: View {
    @ObservedObject var state: SessionPOCState

    private let durationChoices = [10, 12, 15, 20, 25]

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.selectedCarePatientId)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to profile",
                onBack: { state.phase = .carePatientDetail },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(alignment: .leading, spacing: 20) {
                    FadeInLine(
                        text: "If you use smart lights, a headset, or a TV in the room, set that up here so the session matches the space. None of this is required — it’s just so NoteStalgia knows what you have.",
                        font: BrandTheme.orbHintFont(),
                        muted: true,
                        delay: 0.06
                    )
                    .frame(maxWidth: .infinity)

                    if let patient {
                        BrandCard {
                            VStack(alignment: .leading, spacing: 12) {
                                BrandSectionHeader(title: "With \(patient.displayName)", systemImage: "hand.raised")
                                BrandInsetTile {
                                    VStack(spacing: 0) {
                                        CareSenseNoteRow(label: "Light", value: patient.preferredLight)
                                        CareSenseNoteRow(label: "Scent", value: patient.scentGuidance)
                                        CareSenseNoteRow(label: "Touch", value: patient.touchComfortNotes, isLast: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)
                    }

                    BrandCard {
                        VStack(alignment: .leading, spacing: 14) {
                            BrandSectionHeader(
                                title: "Smart lighting",
                                systemImage: "lightbulb.fill",
                                subtitle: "Pair a bridge if you have one — then a calm scene can drift with the session: warmer dim, slow fades, no sudden bright flashes."
                            )
                            iotToggle("Philips Hue scenes", isOn: $state.iotPhilipsHueEnabled)
                            iotToggle("Apple HomeKit rooms", isOn: $state.iotHomeKitEnabled)
                            iotToggle("Matter accessories", isOn: $state.iotMatterEnabled)
                            Divider().opacity(0.35)
                            iotToggle("Soft light pulses with the breathing pace", isOn: $state.iotFollowSessionBreath)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Max scene brightness cap")
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Spacer()
                                    Text("\(Int((state.iotMaxSceneBrightness * 100).rounded()))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(BrandTheme.textSecondary)
                                }
                                Slider(value: $state.iotMaxSceneBrightness, in: 0.15 ... 1)
                                .accessibilityIdentifier("prep.brightness")
                                    .tint(BrandTheme.goldDeep)
                            }
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    BrandCard {
                        VStack(alignment: .leading, spacing: 14) {
                            BrandSectionHeader(
                                title: "Immersive & VR",
                                systemImage: "eyeglasses",
                                subtitle: "Some teams use a headset or a wall screen for nature-led calm, with you right beside the person. In a real setting, consent, policy, and infection control come first — this is just the rehearsal."
                            )
                            iotToggle(
                                "VR / headset path (when your kit supports it)",
                                isOn: $state.carePrepVRImmersiveRoute
                            )
                            iotToggle(
                                "Also show on wall, TV, or bedside screen",
                                isOn: $state.carePrepRoomDisplayMirroring
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    BrandCard {
                        VStack(alignment: .leading, spacing: 12) {
                            BrandSectionHeader(
                                title: "Rough length",
                                systemImage: "timer",
                                subtitle: "Only a guide — stop whenever it feels right. Lights can ease down with the closing breath."
                            )
                            BrandSegmentedChoice(
                                title: "Minutes",
                                selection: $state.carePlannedDurationMinutes,
                                options: durationChoices.map { BrandChoiceOption(value: $0, label: "\($0) min") }
                            )
                            .accessibilityIdentifier("prep.minutes")
                            .chimeOnChange(of: state.carePlannedDurationMinutes)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)

                    Text("Wellness support only — not clinical advice or a medical device. Device names here are examples.")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary.opacity(0.9))
                        .padding(.horizontal, 4)

                    PrimaryButton(title: "Continue — photo or quick session") {
                        state.continueCareSessionFromPrep()
                    }
                    .accessibilityIdentifier("prep.continue")
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 28)
            }
        }
    }

    private func iotToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(BrandTheme.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 44, alignment: .leading)   // inside the label, so the toggle's own row is 44 pt
        }
        .toggleStyle(BrandRowToggleStyle())
        .accessibilityIdentifier("prep.toggle.\(title)")
        .chimeOnChange(of: isOn.wrappedValue)
    }
}

// MARK: - Patient detail

struct CarePatientDetailView: View {
    @ObservedObject var state: SessionPOCState
    /// Resident whose song-search sheet is open (backend mode).
    @State private var songSearchPatientId: UUID?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum DetailTypography {
        static let name = Font.title.weight(.semibold)
        static let context = Font.title3
        static let section = Font.headline.weight(.semibold)
        static let body = Font.body
        static let secondary = Font.callout
        static let label = Font.subheadline.weight(.semibold)
        static let pill = Font.subheadline.weight(.medium)
    }

    private var portraitSize: CGFloat {
        BrandLayout.scaled(112, regular: 144, horizontalSizeClass: horizontalSizeClass)
    }

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.selectedCarePatientId)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: state.isHouseholdAccount ? "Back to home" : "Back to roster",
                onBack: { state.returnFromResidentDetail() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 26) {
                    if let patient {
                        CarePatientPortraitView(
                            assetName: patient.stockPortraitAssetName,
                            customImage: state.portraitImage(for: patient.id),
                            size: portraitSize
                        )
                        .shadow(color: BrandTheme.brown.opacity(0.12), radius: 10, y: 4)

                        VStack(spacing: 6) {
                            Text(patient.displayName)
                                .font(BrandTheme.orbTitleFont(.title))
                                .orbOverlayText()
                                .multilineTextAlignment(.center)
                            Text(patient.careContextLabel)
                                .font(BrandTheme.orbLineFont())
                                .orbOverlayText(muted: true)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        // The main reason a carer opens a profile — keep it above the fold.
                        PrimaryButton(title: "Open resident calm surface") {
                            state.openResidentProfile()
                        }
                        .accessibilityIdentifier("profile.openSurface")
                        .padding(.horizontal, 24)

                        patientSentimentSummaryCard(patient)

                        if !state.isHouseholdAccount {   // households have no roster or group mode
                            groupActivitiesCard(patient)
                        }

                        genrePlaylistsCard(patient)

                        suggestedLikedSongsCard(patient)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                BrandSectionHeader(title: "Listening profile", systemImage: "person.text.rectangle")
                                // Two 44 pt buttons: the system stepper is 47 × 32 pt.
                                HStack(spacing: 10) {
                                    Text("Approx. age: \(patient.residentAgeYears)")
                                        .font(DetailTypography.body)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Spacer(minLength: 8)
                                    ageStepButton(systemImage: "minus", label: "Decrease age", identifier: "profile.age-Decrement",
                                                  enabled: patient.residentAgeYears > 55) {
                                        state.setResidentAge(for: patient.id, age: patient.residentAgeYears - 1)
                                    }
                                    ageStepButton(systemImage: "plus", label: "Increase age", identifier: "profile.age-Increment",
                                                  enabled: patient.residentAgeYears < 105) {
                                        state.setResidentAge(for: patient.id, age: patient.residentAgeYears + 1)
                                    }
                                }
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("profile.age")
                                .chimeOnChange(of: patient.residentAgeYears)
                                ResidentNationalityMenuField(
                                    title: "Nationality",
                                    selection: Binding(
                                        get: { patient.nationality },
                                        set: { state.setResidentNationality(for: patient.id, nationality: $0) }
                                    ),
                                    caption: "Used with age when discovery reorders clips and genres."
                                )
                                Text("Suggested liked songs above seed playlist order; the resident can still sun-like or cloud-skip live.")
                                    .font(DetailTypography.secondary)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                BrandSectionHeader(
                                    title: "Listening discovery",
                                    systemImage: "waveform",
                                    subtitle: "Seven short clips, one per genre (about 30 seconds each). The resident taps a face — red, amber or green — for each one; we then suggest genre playlists from what they enjoyed and open their calm surface."
                                )
                                SecondaryButton(title: "Start discovery pass") {
                                    state.startDiscoveryCalibration(for: patient.id)
                                }
                                .accessibilityIdentifier("profile.startDiscovery")
                                if let line = discoveryRunSummary(for: patient.id, state: state) {
                                    Text(line)
                                        .font(DetailTypography.body.weight(.medium))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 6)
                                        .accessibilityLabel(line)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 14) {
                                BrandSectionHeader(title: "Comfort & senses", systemImage: "hand.raised")
                                BrandInsetTile {
                                    VStack(spacing: 0) {
                                        CareSenseNoteRow(label: "Light", value: patient.preferredLight)
                                        CareSenseNoteRow(label: "Scent", value: patient.scentGuidance)
                                        CareSenseNoteRow(label: "Touch", value: patient.touchComfortNotes, isLast: true)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 14) {
                                BrandSectionHeader(title: "For next time", systemImage: "slider.horizontal.3")
                                BrandInsetTile {
                                    VStack(alignment: .leading, spacing: 14) {
                                        meterRow("Tempo — gentler ↔ slightly brighter", value: patient.musicTempoBias)
                                        meterRow("Nature ↔ abstract", value: patient.natureVsAbstract)
                                        meterRow("Instrumental ↔ voice", value: patient.voiceVsInstrumental)
                                    }
                                }
                                Text("After you’re together, note how they responded — these sliders help the next visit land softly.")
                                    .font(DetailTypography.secondary)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.logoCyan)
                                    .orbOverlayTextStyle()
                                    .accessibilityHidden(true)
                                Text("Previous sessions")
                                    .font(DetailTypography.section)
                                    .orbOverlayText()
                                    .accessibilityAddTraits(.isHeader)
                            }
                            .padding(.horizontal, 4)

                            let rows = state.recordsForPatient(patient.id)
                            if rows.isEmpty {
                                Text("Nothing here yet.")
                                    .font(DetailTypography.body)
                                    .orbOverlayText(muted: true)
                                    .padding(.horizontal, 8)
                            } else {
                                ForEach(rows) { rec in
                                    sessionHistoryCard(rec)
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        PrimaryButton(title: "Lights, headset & timing") {
                            state.openCareSessionPrep()
                        }
                        .accessibilityIdentifier("profile.prepSession")
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    } else {
                        FadeInLine(text: "No one’s selected.", delay: 0)
                    }
                }
                .padding(.vertical, 28)
            }
        }
    }

    private func discoveryRunSummary(for patientId: UUID, state: SessionPOCState) -> String? {
        guard state.selectedCarePatientId == patientId else { return nil }
        guard state.discoveryResults.count == DiscoveryFlowPOC.snippetCount else { return nil }
        let unpleasant = state.discoveryResults.filter { $0.sentiment == .unpleasant }.count
        let neutral = state.discoveryResults.filter { $0.sentiment == .neutral }.count
        let pleasant = state.discoveryResults.filter { $0.sentiment == .pleasant }.count
        return "Last pass: red (uncomfortable) \(unpleasant), amber (unsure) \(neutral), green (comforting) \(pleasant)."
    }

    private func patientSentimentSummaryCard(_ patient: CarePatientProfile) -> some View {
        let summary = state.sentimentSummary(for: patient.id)
        return Group {
            if summary.hasData {
                BrandCard {
                    VStack(alignment: .leading, spacing: 12) {
                        BrandSectionHeader(
                            title: "Carer observations",
                            systemImage: "heart.text.square",
                            subtitle: "Rolling averages of the 1–10 observations recorded after each session."
                        )
                        SentimentAverageTiles(summary: summary)
                        Text("Based on \(summary.sessionCount) rated session\(summary.sessionCount == 1 ? "" : "s") · \(BrandRatingTone.legend)")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    /// Participation in group activities plus the staff-set comfort flag the planner uses.
    private func groupActivitiesCard(_ patient: CarePatientProfile) -> some View {
        let participation = state.groupParticipationSummary(for: patient.id)
        return BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(title: "Group activities", systemImage: "person.3")
                Text(participation.line)
                    .font(DetailTypography.body)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("profile.groupActivities")

                VStack(alignment: .leading, spacing: 8) {
                    Text("In company")
                        .font(DetailTypography.label)
                        .foregroundStyle(BrandTheme.textSecondary)
                    BrandSegmentedChoice(
                        title: "In company",
                        selection: Binding(
                            get: { patient.groupComfort?.rawValue ?? "" },
                            set: { state.setResidentGroupComfort(for: patient.id, comfort: GroupComfort(rawValue: $0)) }
                        ),
                        options: [
                            BrandChoiceOption(value: "", label: "Not set"),
                            BrandChoiceOption(value: GroupComfort.enjoysGroups.rawValue, label: "Enjoys groups"),
                            BrandChoiceOption(value: GroupComfort.smallGroupsOnly.rawValue, label: "Small groups"),
                            BrandChoiceOption(value: GroupComfort.prefersOneToOne.rawValue, label: "One-to-one"),
                        ]
                    )
                    .accessibilityIdentifier("profile.groupComfort")
                    .chimeOnChange(of: patient.groupComfort)
                    Text("Shapes the group planner’s suggestions. Residents set to one-to-one are never invited automatically; small groups and gentle flags are shown to staff, not enforced.")
                        .font(DetailTypography.secondary)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func orderedPlaylistGroups(_ patient: CarePatientProfile) -> [CareGenrePlaylistGroup] {
        patient.genrePlaylistGroups.sorted { $0.genre.rawValue < $1.genre.rawValue }
    }

    private func genrePlaylistsCard(_ patient: CarePatientProfile) -> some View {
        let groups = orderedPlaylistGroups(patient)
        return BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                BrandSectionHeader(
                    title: "Playlists on file",
                    systemImage: "music.note.list",
                    subtitle: "By genre. These appear as floating instruments for the resident — staff do not change them here."
                )

                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        BrandHairline()
                    }
                    genrePlaylistSection(group: group)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    /// Supervisor-seeded likes that boost track order on the resident calm surface.
    private func suggestedLikedSongsCard(_ patient: CarePatientProfile) -> some View {
        let selected = patient.suggestedLikedTrackTitles
        let available = ResidentPlaybackTrackCatalog.allUniqueTitles.filter { !selected.contains($0) }

        return BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                BrandSectionHeader(
                    title: "Suggested liked songs",
                    systemImage: "heart",
                    subtitle: "Add tracks family or staff know they enjoy. These float earlier when a playlist starts — live sun taps still raise weight further."
                )

                if selected.isEmpty {
                    Text("None yet — add a song below.")
                        .font(DetailTypography.secondary)
                        .foregroundStyle(BrandTheme.textTertiary)
                } else {
                    // Content-sized chips (the fixed-column grid truncated titles to "Velvet…").
                    InsightChipFlow {
                        ForEach(selected, id: \.self) { title in
                            Button {
                                state.removeSuggestedLikedTrack(for: patient.id, title: title)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2.weight(.semibold))
                                    Text(title)
                                        .font(DetailTypography.pill)
                                        .lineLimit(1)
                                    Image(systemName: "xmark")
                                        .font(.caption2.weight(.bold))
                                        .opacity(0.75)
                                }
                                .foregroundStyle(BrandTheme.onPrimaryAction)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    BrandTheme.nebulaPink,
                                                    BrandTheme.nebulaMagenta,
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .expandedHitArea(vertical: 5)   // 34 pt chip, 44 pt target
                            }
                            .accessibilityIdentifier("profile.song.remove.\(title)")
                            .buttonStyle(ChimingPlainButtonStyle())
                            .accessibilityLabel("Remove \(title) from suggested liked songs")
                        }
                    }
                }

                if APIConfig.isConfigured {
                    Button {
                        CalmExperienceFeedback.buttonPress()
                        songSearchPatientId = patient.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass.circle.fill")
                                .foregroundStyle(BrandTheme.gold)
                            Text("Find a song they love")
                                .font(DetailTypography.body.weight(.medium))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.goldDeep.opacity(0.85))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BrandTheme.creamMid.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityIdentifier("profile.addSong")
                    .accessibilityLabel("Find a song they love")
                } else {
                Menu {
                    if available.isEmpty {
                        Text("All catalog songs are already suggested")
                    } else {
                        ForEach(available, id: \.self) { title in
                            Button {
                                // Menu items are UIKit-drawn (no button style) — chime explicitly.
                                CalmExperienceFeedback.buttonPress()
                                state.addSuggestedLikedTrack(for: patient.id, title: title)
                            } label: {
                                let genres = ResidentPlaybackTrackCatalog.genres(containing: title)
                                    .map(\.accessibilityLabel)
                                    .joined(separator: " · ")
                                Text("\(title)\(genres.isEmpty ? "" : "  (\(genres))")")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(BrandTheme.gold)
                        Text(available.isEmpty ? "All songs added" : "Add suggested song")
                            .font(DetailTypography.body.weight(.medium))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.goldDeep.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandTheme.creamMid.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                    )
                }
                .accessibilityIdentifier("profile.addSong")
                .disabled(available.isEmpty)
                .accessibilityLabel("Add suggested liked song")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .sheet(isPresented: Binding(get: { songSearchPatientId == patient.id }, set: { if !$0 { songSearchPatientId = nil } })) {
            SongSearchSheet(state: state, patient: state.carePatient(id: patient.id) ?? patient)
        }
    }

    private func genrePlaylistSection(group: CareGenrePlaylistGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(group.genre.artworkAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(BrandTheme.gold.opacity(0.35), lineWidth: 1))
                Text(group.genre.accessibilityLabel)
                    .font(DetailTypography.section)
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer(minLength: 0)
            }
            ForEach(group.playlists) { pl in
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "music.note.list")
                        .font(DetailTypography.body)
                        .foregroundStyle(BrandTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pl.title)
                            .font(DetailTypography.body.weight(.medium))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Text("\(pl.trackTitles.count) track\(pl.trackTitles.count == 1 ? "" : "s") in player · about \(pl.durationMinutes) min")
                            .font(DetailTypography.secondary)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func meterRow(_ title: String, value: Double) -> some View {
        BrandRatingRow(
            label: title,
            valueText: "\(Int((value * 100).rounded()))%",
            fraction: value,
            tint: BrandTheme.gold,
            spokenValue: "\(Int((value * 100).rounded())) percent"
        )
    }

    /// One past session as a handover note: when and how at ease in the header, the carer's 1–10
    /// observations as chips, the insight and next step on their own tiles, notes quoted.
    private func sessionHistoryCard(_ rec: CareSessionRecord) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(rec.date, style: .date)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    BrandStatusChip(
                        text: "\(rec.calmPercent)% at ease",
                        systemImage: "leaf.fill",
                        tint: CareAtEaseTone.tint(percent: rec.calmPercent)
                    )
                }
                BrandHairline()
                if !rec.moodSummary.isEmpty, rec.moodSummary != "—" {
                    Text("Mood tags: \(rec.moodSummary)")
                        .font(DetailTypography.body)
                        .foregroundStyle(BrandTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let ratings = sentimentRatings(rec)
                if !ratings.isEmpty {
                    InsightChipFlow {
                        ForEach(ratings) { rating in
                            BrandStatusChip(
                                text: "\(rating.label) \(rating.value)/10",
                                tint: BrandRatingTone.tint(outOfTen: Double(rating.value))
                            )
                        }
                    }
                }
                if let line = outcomeLine(rec) {
                    Text(line)
                        .font(DetailTypography.secondary)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let insight = rec.insightPreviewLine() {
                    BrandInsetTile {
                        Text(insight)
                            .font(DetailTypography.body)
                            .foregroundStyle(BrandTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let next = rec.insightSuggestedNextStep {
                    BrandInsetTile(accent: BrandTheme.statusCaution) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.subheadline)
                                .foregroundStyle(BrandTheme.statusCaution)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suggested next step")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text(next)
                                    .font(DetailTypography.body)
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if let context = rec.sessionContextSummary, !context.isEmpty {
                    Label {
                        Text(context)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "tag")
                    }
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                }
                if let note = rec.staffNote, !note.isEmpty {
                    BrandQuoteBlock(title: "Staff note", text: note)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The interaction summary is already the opening of the insight tile, so it only appears here
    /// for sessions recorded before insights existed.
    private func outcomeLine(_ rec: CareSessionRecord) -> String? {
        var parts: [String] = []
        if rec.insightPreviewLine() == nil, let line = rec.residentInteractionSummaryLine() { parts.append(line) }
        if rec.settledness != nil || rec.engagement != nil || rec.comfortTolerance != nil {
            if let s = rec.settledness { parts.append("Settled \(s)%") }
            if let e = rec.engagement { parts.append("Engaged \(e)%") }
            if let c = rec.comfortTolerance { parts.append("Comfort \(c)%") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func sentimentRatings(_ rec: CareSessionRecord) -> [CareSessionInsightSummary.Rating] {
        var items: [CareSessionInsightSummary.Rating] = []
        if let v = rec.moodRating { items.append(.init(label: "Mood/affect", value: v)) }
        if let v = rec.alertnessRating { items.append(.init(label: "Alertness", value: v)) }
        if let v = rec.emotionalStateRating { items.append(.init(label: "Emotional presentation", value: v)) }
        if let v = rec.lucidityRating { items.append(.init(label: "Orientation", value: v)) }
        return items
    }
}

/// Status tint for a "% at ease" figure.
enum CareAtEaseTone {
    static func tint(percent: Int) -> Color {
        if percent >= 70 { return BrandTheme.statusPositive }
        if percent >= 45 { return BrandTheme.statusCaution }
        return BrandTheme.statusAttention
    }
}

/// A 44 × 44 pt round "−" / "+" button for the profile's age.
private func ageStepButton(systemImage: String, label: String, identifier: String, enabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(BrandTheme.textPrimary)
            .frame(width: 44, height: 44)
            .background(Circle().fill(BrandTheme.surfaceInset))
            .overlay(Circle().stroke(BrandTheme.insetBorder, lineWidth: 1))
    }
    .buttonStyle(ChimingPlainButtonStyle())
    .disabled(!enabled)
    .opacity(enabled ? 1 : 0.4)
    .accessibilityLabel(label)
    .accessibilityIdentifier(identifier)
}

/// Label above a sentence of care guidance (light, scent, touch), with a hairline beneath.
struct CareSenseNoteRow: View {
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            if !isLast { BrandHairline() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The four carer-observation averages as tiles, each tinted by the rating tone.
struct SentimentAverageTiles: View {
    let summary: CareSessionSentimentSummary
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Item: Identifiable {
        let label: String
        let value: Double?
        var id: String { label }
    }

    private var items: [Item] {
        [
            Item(label: "Mood / affect", value: summary.averageMood),
            Item(label: "Alertness", value: summary.averageAlertness),
            Item(label: "Emotional presentation", value: summary.averageEmotionalState),
            Item(label: "Orientation", value: summary.averageLucidity),
        ]
    }

    var body: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: BrandLayout.statTileColumns(regularWidth: BrandLayout.isRegularWidth(horizontalSizeClass), dynamicTypeSize: dynamicTypeSize)
        )
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                BrandStatTile(
                    value: item.value.map { String(format: "%.1f", $0) } ?? "—",
                    label: item.label,
                    detail: "out of 10",
                    tint: item.value.map { BrandRatingTone.tint(outOfTen: $0) }
                )
            }
        }
    }
}

// MARK: - Sequential post-session sentiment (existing residents)

struct CareSessionSentimentFeedbackView: View {
    @ObservedObject var state: SessionPOCState
    @State private var autoAdvanceToken = 0

    private static let autoAdvanceDelay: TimeInterval = 0.42

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.activeCarePatientId ?? state.selectedCarePatientId)
    }

    private var currentStep: CareSessionSentimentStep {
        CareSessionSentimentStep(rawValue: state.sessionSentimentStep) ?? .mood
    }

    private var isLastStep: Bool {
        state.sessionSentimentStep >= CareSessionSentimentStep.allCases.count - 1
    }

    private var currentSelection: Int? {
        switch currentStep {
        case .mood: return state.sessionSentimentDraft.mood
        case .alertness: return state.sessionSentimentDraft.alertness
        case .emotionalState: return state.sessionSentimentDraft.emotionalState
        case .lucidity: return state.sessionSentimentDraft.lucidity
        }
    }

    var body: some View {
        ScreenFadeIn {
            // Top-aligned: the step card grows (note field on the last step), and a centred
            // layout would slide the rating buttons out from under the carer's finger.
            CenteredScrollScreen(
                backTitle: state.sessionSentimentStep > 0 ? "Back" : "Skip",
                backAccessibilityLabel: backLabel,
                onBack: handleBack,
                onLogout: { state.signOutSupervisor() },
                logoutWarning: "This observation hasn’t been saved yet.",
                topAligned: true
            ) {
                VStack(spacing: 24) {
                    if let patient {
                        FadeInTitle(text: "Post-session observation", delay: 0)
                        FadeInLine(
                            text: "Structured carer observations after \(patient.displayName)'s reminiscence music session — not a clinical assessment.",
                            delay: 0.06
                        )

                        if let metricsLine = state.residentSurfaceMetrics.interactionSummary() {
                            BrandCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    BrandSectionHeader(title: "Session captured automatically", systemImage: "waveform")
                                    BrandInsetTile {
                                        Text(metricsLine)
                                            .font(.body)
                                            .foregroundStyle(BrandTheme.textPrimary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 4)
                        }

                        SessionContextCaptureCard(context: $state.sessionContextDraft)
                            .padding(.horizontal, 4)

                        stepProgress

                        BrandCard {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Step \(state.sessionSentimentStep + 1) of \(CareSessionSentimentStep.allCases.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                                Text(currentStep.title)
                                    .font(.title2.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                                Text(currentStep.prompt)
                                    .font(.body)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                SentimentScalePicker(
                                    selection: state.sessionSentimentBinding(for: currentStep),
                                    lowCaption: currentStep.lowCaption,
                                    highCaption: currentStep.highCaption,
                                    onValueSelected: { _ in
                                        scheduleAutoAdvanceIfNeeded()
                                    }
                                )

                                if isLastStep {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Optional note")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BrandTheme.textSecondary)
                                        TextField("Note", text: $state.sessionSentimentDraft.note, prompt: BrandTheme.fieldPrompt("Anything else to remember?"), axis: .vertical)
                                        .accessibilityIdentifier("observation.note")
                                            .lineLimit(1 ... 4)
                                            .font(.body)
                                            .foregroundStyle(BrandTheme.textPrimary)
                                            .padding(12)
                                            .background(BrandTheme.creamMid.opacity(0.95))
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(BrandTheme.gold.opacity(0.25), lineWidth: 1)
                                            )
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(state.sessionSentimentStep)
                            .transition(.etherealAppear)
                        }
                        .padding(.horizontal, 4)
                        .animation(CalmMotion.gentle, value: state.sessionSentimentStep)
                        .onChange(of: state.sessionSentimentStep) { _, _ in
                            autoAdvanceToken += 1
                        }

                        PrimaryButton(title: isLastStep ? "Save observation" : "Next") {
                            if isLastStep {
                                state.saveSessionSentimentFeedback()
                                CalmExperienceFeedback.signInSuccess()
                            } else {
                                state.advanceSessionSentimentStep()
                            }
                        }
                        .accessibilityIdentifier("observation.save")
                        .disabled(currentSelection == nil)
                        .opacity(currentSelection == nil ? 0.45 : 1)
                        .animation(CalmMotion.subtle, value: currentSelection)
                        .padding(.horizontal, 24)

                        SecondaryButton(title: "Skip for now") {
                            state.skipSessionSentimentFeedback()
                        }
                        .accessibilityIdentifier("observation.skip")
                        .padding(.horizontal, 24)
                    } else {
                        FadeInLine(text: "No resident linked to this session.", delay: 0)
                    }
                }
                .padding(.vertical, 28)
            }
        }
    }

    private var stepProgress: some View {
        HStack(spacing: 8) {
            ForEach(CareSessionSentimentStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= state.sessionSentimentStep ? BrandTheme.gold : BrandTheme.meterTrack)
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, 4)
        .animation(CalmMotion.subtle, value: state.sessionSentimentStep)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("Step \(state.sessionSentimentStep + 1) of \(CareSessionSentimentStep.allCases.count)")
    }

    private var backLabel: String {
        state.sessionSentimentStep > 0
            ? "Previous question"
            : "Skip feedback — saves the session without ratings"
    }

    private func handleBack() {
        autoAdvanceToken += 1
        if state.sessionSentimentStep > 0 {
            state.retreatSessionSentimentStep()
        } else {
            state.skipSessionSentimentFeedback()
        }
    }

    private func scheduleAutoAdvanceIfNeeded() {
        let step = state.sessionSentimentStep
        guard step < CareSessionSentimentStep.allCases.count - 1 else { return }
        autoAdvanceToken += 1
        let token = autoAdvanceToken
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoAdvanceDelay) {
            guard token == autoAdvanceToken, state.sessionSentimentStep == step else { return }
            state.advanceSessionSentimentStep()
        }
    }
}

struct SentimentScalePicker: View {
    @Binding var selection: Int?
    let lowCaption: String
    let highCaption: String
    var onValueSelected: ((Int) -> Void)? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1 ... 10, id: \.self) { value in
                    let isSelected = selection == value
                    Button {
                        selection = value
                        CalmExperienceFeedback.discoveryPick()
                        onValueSelected?(value)
                    } label: {
                        Text("\(value)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(isSelected ? BrandTheme.textPrimary : BrandTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? BrandTheme.goldSoft.opacity(0.55) : BrandTheme.creamMid.opacity(0.95))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? BrandTheme.gold.opacity(0.7) : BrandTheme.insetBorder, lineWidth: isSelected ? 1.5 : 1)
                            )
                            .scaleEffect(isSelected ? 1.06 : 1)
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityLabel("\(value) out of 10")
                    .accessibilityHint(value <= 3 ? lowCaption : value >= 8 ? highCaption : "")
                    .accessibilityIdentifier("rating.\(value)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .animation(CalmMotion.gentle, value: selection)

            HStack {
                Text(lowCaption)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                Spacer(minLength: 8)
                Text(highCaption)
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

// MARK: - Post-session feedback & tuning

struct CareSessionFeedbackView: View {
    @ObservedObject var state: SessionPOCState
    @State private var settled: Double = 0.6
    @State private var engagement: Double = 0.55
    @State private var comfort: Double = 0.7
    @State private var tempo: Double = 0.5
    @State private var nature: Double = 0.5
    @State private var voice: Double = 0.5
    @State private var staffNote = ""

    private var targetPatient: CarePatientProfile? {
        state.carePatient(id: state.activeCarePatientId ?? state.selectedCarePatientId)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to ‘How that felt’",
                onBack: { state.phase = .insight },
                onLogout: { state.signOutSupervisor() },
                logoutWarning: "This feedback hasn’t been saved yet."
            ) {
                VStack(spacing: 22) {
                    if let patient = targetPatient {
                        FadeInLine(
                            text: "How did \(patient.displayName) seem? This isn’t a grade for you — it nudges the sound for next time.",
                            font: BrandTheme.orbHintFont(),
                            muted: true,
                            delay: 0.08
                        )

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                BrandSectionHeader(title: "In the moment", systemImage: "face.smiling")
                                outcomeSlider(
                                    title: "Seemed settled",
                                    caption: "Still unsettled  ←  →  More at ease",
                                    value: $settled
                                )
                                outcomeSlider(
                                    title: "With you",
                                    caption: "Withdrawn  ←  →  Present / connected",
                                    value: $engagement
                                )
                                outcomeSlider(
                                    title: "Comfort in the room",
                                    caption: "Struggling  ←  →  Comfortable throughout",
                                    value: $comfort
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        BrandCard {
                            VStack(alignment: .leading, spacing: 16) {
                                BrandSectionHeader(title: "Sound for next time", systemImage: "slider.horizontal.3")
                                tuningSlider(title: "Tempo — gentler ↔ slightly brighter", value: $tempo)
                                tuningSlider(title: "Nature ↔ abstract", value: $nature)
                                tuningSlider(title: "Instrumental ↔ voice", value: $voice)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your note (optional)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandTheme.textSecondary)
                            TextField("Staff note", text: $staffNote, prompt: BrandTheme.fieldPrompt("What helped — light, touch, sound? What would you soften next time?"), axis: .vertical)
                            .accessibilityIdentifier("feedback.note")
                                .lineLimit(1 ... 10)
                                .font(.body)
                                .foregroundStyle(BrandTheme.textPrimary)
                                .padding(12)
                                .background(BrandTheme.creamMid.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(BrandTheme.gold.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 4)

                        PrimaryButton(title: "Save note & sound tweaks") {
                            state.saveCareFeedback(
                                tempoBias: tempo,
                                natureVsAbstract: nature,
                                voiceVsInstrumental: voice,
                                settledness: Int((settled * 100).rounded()),
                                engagement: Int((engagement * 100).rounded()),
                                comfortTolerance: Int((comfort * 100).rounded()),
                                staffNote: staffNote
                            )
                        }
                        .accessibilityIdentifier("feedback.save")
                        .padding(.horizontal, 24)

                        SecondaryButton(title: "Skip — keep session only") {
                            state.skipCareFeedback()
                        }
                        .accessibilityIdentifier("feedback.skip")
                        .padding(.horizontal, 24)
                    } else {
                        FadeInLine(text: "Pick someone from the list to save a note.", delay: 0)
                    }
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            staffNote = ""
            syncFromPatient()
            settled = 0.55
            engagement = 0.55
            comfort = 0.65
        }
    }

    private func syncFromPatient() {
        guard let patient = targetPatient else { return }
        tempo = patient.musicTempoBias
        nature = patient.natureVsAbstract
        voice = patient.voiceVsInstrumental
    }

    private func outcomeSlider(title: String, caption: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(BrandTheme.textSecondary)
            Slider(value: value, in: 0 ... 1)
                .accessibilityIdentifier("feedback.outcome.\(title)")
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) percent")
                .tint(BrandTheme.goldDeep)
        }
    }

    private func tuningSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(BrandTheme.textPrimary)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
            Slider(value: value, in: 0 ... 1)
                .accessibilityIdentifier("feedback.tuning.\(title)")
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) percent")
                .tint(BrandTheme.goldDeep)
        }
    }
}

// MARK: - Session context capture (UK care-floor tags)

private struct SessionContextCaptureCard: View {
    @Binding var context: SessionContextDraft

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: "Session context",
                    systemImage: "tag",
                    subtitle: "Quick tags for nursing handover and care plan documentation — optional but valuable."
                )

                contextChipRow(title: "Time of day", items: SessionTimeOfDay.allCases) { item in
                    context.timeOfDay = item
                } selection: { context.timeOfDay == $0 }

                contextChipRow(title: "Pre-session presentation", items: SessionPriorState.allCases) { item in
                    context.priorState = context.priorState == item ? nil : item
                } selection: { context.priorState == $0 }

                environmentTagsRow

                Toggle(isOn: $context.residentLedSession) {
                    Text("Resident chose the music")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textPrimary)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .toggleStyle(BrandRowToggleStyle())
                .accessibilityIdentifier("observation.residentLed")
                .chimeOnChange(of: context.residentLedSession)

                Toggle(isOn: $context.distressOrPRNNearby) {
                    Text("Acute distress or PRN (as-required) medication nearby")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textPrimary)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .toggleStyle(BrandRowToggleStyle())
                .accessibilityIdentifier("observation.distress")
                .chimeOnChange(of: context.distressOrPRNNearby)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var environmentTagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environment")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            FlowLayoutChipWrap {
                ForEach(SessionEnvironmentTag.allCases) { tag in
                    let selected = context.environmentTags.contains(tag)
                    BrandSelectableChip(label: tag.label, selected: selected, tint: BrandTheme.goldDeep) {
                        if selected {
                            context.environmentTags.remove(tag)
                        } else {
                            context.environmentTags.insert(tag)
                        }
                    }
                    .accessibilityIdentifier("observation.chip.\(tag.label)")
                }
            }
        }
    }

    private func contextChipRow<T: Identifiable & Equatable>(
        title: String,
        items: [T],
        onSelect: @escaping (T) -> Void,
        selection: @escaping (T) -> Bool
    ) -> some View where T: Hashable {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            FlowLayoutChipWrap {
                ForEach(items) { item in
                    let selected = selection(item)
                    BrandSelectableChip(label: chipLabel(for: item), selected: selected, tint: BrandTheme.logoCyan) {
                        onSelect(item)
                    }
                    .accessibilityIdentifier("observation.chip.\(chipLabel(for: item))")
                }
            }
        }
    }

    private func chipLabel<T>(for item: T) -> String {
        if let time = item as? SessionTimeOfDay { return time.label }
        if let state = item as? SessionPriorState { return state.label }
        return "—"
    }
}

/// Wrapping chip row for context pickers — content-sized, so "Agitated / behavioural distress" is
/// never cut to "Agitated / beh…" the way the fixed-column grid did.
private struct FlowLayoutChipWrap<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        InsightChipFlow {
            content()
        }
    }
}

// MARK: - Post-session summary (handover + family export)

/// What the supervisor sees after rating a session: the essentials first (trend, time, music),
/// then carer ratings, what the resident responded to and one suggested next step. The three
/// write-ups (handover, family, care plan) sit behind one switcher with a single copy button,
/// so only one block of prose is ever on screen.
struct CareSessionInsightView: View {
    @ObservedObject var state: SessionPOCState
    @State private var shareKind: ShareKind = .handover
    @State private var copiedKind: ShareKind?
    @State private var copiedGeneration = 0
    @State private var narrativeExpanded = false

    private enum ShareKind: String, CaseIterable, Identifiable {
        case handover, family, carePlan

        var id: String { rawValue }

        var tabTitle: String {
            switch self {
            case .handover: return "Handover"
            case .family: return "Family"
            case .carePlan: return "Care plan"
            }
        }

        var purpose: String {
            switch self {
            case .handover: return "For the next shift's nursing handover."
            case .family: return "A plain-language update to share with family."
            case .carePlan: return "One entry for the resident's care plan review."
            }
        }

        var copyTitle: String {
            switch self {
            case .handover: return "Copy nursing handover"
            case .family: return "Copy family update"
            case .carePlan: return "Copy care plan entry"
            }
        }

        var copiedTitle: String {
            switch self {
            case .handover: return "Handover copied ✓"
            case .family: return "Family update copied ✓"
            case .carePlan: return "Care plan entry copied ✓"
            }
        }
    }

    private enum Tone {
        static let sun = BrandTheme.statusCaution
        static let cloud = BrandTheme.statusNeutral
        static let attention = BrandTheme.statusAttention
    }

    private var patient: CarePatientProfile? {
        state.carePatient(id: state.activeCarePatientId ?? state.selectedCarePatientId)
    }

    private var pack: CareSessionInsightPack? {
        state.pendingSessionInsight
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: state.isHouseholdAccount ? "Back to home" : "Back to roster",
                onBack: { state.completeSessionInsightReview() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 18) {
                    if let patient, let pack {
                        VStack(spacing: 8) {
                            FadeInTitle(text: "Session summary", delay: 0)
                            FadeInLine(text: "\(patient.displayName) · \(pack.summary.dateText)", delay: 0.06)
                        }
                        .padding(.bottom, 4)

                        glanceCard(pack.summary)
                        if !pack.summary.ratings.isEmpty || pack.summary.note != nil {
                            observationsCard(pack.summary)
                        }
                        if hasMusicDetail(pack.summary) {
                            respondedCard(pack.summary)
                        }
                        nextStepCard(pack.suggestedNextStep)
                        shareCard(pack)

                        PrimaryButton(title: state.isHouseholdAccount ? "Done — back to home" : "Done — back to roster") {
                            state.completeSessionInsightReview()
                        }
                        .accessibilityIdentifier("summary.done")
                        .padding(.horizontal, 24)
                        .padding(.top, 6)
                    } else {
                        FadeInLine(text: "No summary available for this session.", delay: 0)
                        PrimaryButton(title: state.isHouseholdAccount ? "Back to home" : "Back to roster") {
                            state.completeSessionInsightReview()
                        }
                        .accessibilityIdentifier("summary.back")
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 28)
            }
        }
    }

    // MARK: Cards

    private func glanceCard(_ summary: CareSessionInsightSummary) -> some View {
        sectionCard("At a glance", systemImage: "sparkles") {
            if let trend = summary.trend {
                trendBadge(trend)
            }

            BrandStatTileRow {
                BrandStatTile(value: summary.durationText ?? "—", label: "With music", centered: true)
                BrandStatTile(value: "\(summary.genres.count)", label: summary.genres.count == 1 ? "Genre" : "Genres", centered: true)
                BrandStatTile(value: "\(summary.liked.count)", label: "Liked", tint: Tone.sun, centered: true)
                BrandStatTile(value: "\(summary.skipped.count)", label: "Skipped", tint: Tone.cloud, centered: true)
            }

            if !summary.trendNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.trendNotes, id: \.self) { note in
                        bulletLine(note)
                    }
                }
            }

            if !summary.contextTags.isEmpty || summary.distressOrPRNNearby {
                InsightChipFlow {
                    ForEach(summary.contextTags, id: \.self) { tag in
                        chip(Text(tag))
                    }
                    if summary.distressOrPRNNearby {
                        chip(
                            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(" Distress or PRN medication nearby"),
                            tint: Tone.attention
                        )
                    }
                }
            }
        }
    }

    private func observationsCard(_ summary: CareSessionInsightSummary) -> some View {
        sectionCard("Carer observations", systemImage: "heart.text.square") {
            if !summary.ratings.isEmpty {
                BrandInsetTile {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(summary.ratings) { rating in
                            BrandRatingRow(
                                label: rating.label,
                                valueText: "\(rating.value)/10",
                                fraction: Double(rating.value) / 10,
                                tint: BrandRatingTone.tint(outOfTen: Double(rating.value)),
                                spokenValue: "\(rating.value) out of 10"
                            )
                        }
                    }
                }
                Text("1 = low or distressed · 10 = settled and responsive. \(BrandRatingTone.legend).")
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note = summary.note {
                BrandQuoteBlock(title: "Carer note", text: note)
            }
        }
    }

    private func respondedCard(_ summary: CareSessionInsightSummary) -> some View {
        sectionCard("What they responded to", systemImage: "music.note") {
            if !summary.genres.isEmpty {
                InsightChipFlow {
                    ForEach(summary.genres) { play in
                        genreChip(play)
                    }
                }
            }
            if !summary.liked.isEmpty {
                trackGroup("Enjoyed", glyph: .sun, tint: Tone.sun, tracks: summary.liked)
            }
            if !summary.skipped.isEmpty {
                trackGroup(
                    "Moved on from",
                    glyph: .cloud,
                    tint: Tone.cloud,
                    tracks: summary.skipped.map { .init(title: $0, detail: nil) }
                )
            }
            if !summary.longestListening.isEmpty {
                trackGroup("Longest listening", systemImage: "headphones", tint: BrandTheme.logoCyan, tracks: summary.longestListening)
            }
            if summary.calmRoomVisits > 0 {
                Label(
                    "Visited the calm nature room \(summary.calmRoomVisits) time\(summary.calmRoomVisits == 1 ? "" : "s")",
                    systemImage: "leaf.fill"
                )
                .font(.footnote)
                .foregroundStyle(BrandTheme.textSecondary)
            }
            if summary.frustrationBursts > 0 {
                Label(
                    "Rapid repeated taps \(summary.frustrationBursts)× — read as frustration, not preference",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(Tone.attention)
            }
        }
    }

    private func nextStepCard(_ step: String) -> some View {
        sectionCard("Suggested next step", systemImage: "lightbulb.fill", highlighted: true) {
            Text(step)
                .font(.body)
                .foregroundStyle(BrandTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shareCard(_ pack: CareSessionInsightPack) -> some View {
        sectionCard("Share & record", systemImage: "square.and.arrow.up") {
            BrandSegmentedChoice(
                title: "Write-up",
                selection: $shareKind,
                options: ShareKind.allCases.map { BrandChoiceOption(value: $0, label: $0.tabTitle) }
            )
            .chimeOnChange(of: shareKind)
            .accessibilityIdentifier("summary.shareKind")

            Text(shareKind.purpose)
                .font(.footnote)
                .foregroundStyle(BrandTheme.textSecondary)

            BrandInsetTile(padding: 14) {
                shareContent(pack)
            }
            .id(shareKind)
            .transition(.opacity)

            SecondaryButton(title: copiedKind == shareKind ? shareKind.copiedTitle : shareKind.copyTitle) {
                copy(text(for: shareKind, in: pack), kind: shareKind)
            }
            .accessibilityIdentifier("summary.copy")

            Text("Carer-observed data only — not a clinical assessment.")
                .font(.caption)
                .foregroundStyle(BrandTheme.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .animation(CalmMotion.subtle, value: shareKind)
    }

    @ViewBuilder
    private func shareContent(_ pack: CareSessionInsightPack) -> some View {
        switch shareKind {
        case .handover:
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(pack.handoverSections.enumerated()), id: \.element.id) { index, section in
                    let isNarrative = section.title == "Narrative"
                    if index > 0 { BrandHairline() }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(section.title.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(BrandTheme.textSecondary)
                            .accessibilityAddTraits(.isHeader)
                        // On screen only — the copied text keeps its original wording.
                        Text(section.body.prefix(1).uppercased() + section.body.dropFirst())
                            .font(.callout)
                            .foregroundStyle(BrandTheme.textPrimary)
                            .lineLimit(isNarrative && !narrativeExpanded ? 3 : nil)
                            .fixedSize(horizontal: false, vertical: true)
                        if isNarrative {
                            Button {
                                withAnimation(CalmMotion.subtle) { narrativeExpanded.toggle() }
                            } label: {
                                Text(narrativeExpanded ? "Show less" : "Read full narrative")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(BrandTheme.logoCyan)
                                    .frame(minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(ChimingPlainButtonStyle())
                        }
                    }
                }
            }
        case .family:
            Text(pack.familyText)
                .font(.body)
                .foregroundStyle(BrandTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .carePlan:
            Text(pack.carePlanBullet)
                .font(.body)
                .foregroundStyle(BrandTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Pieces

    private func sectionCard<Content: View>(
        _ title: String,
        systemImage: String,
        highlighted: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(title: title, systemImage: systemImage, tint: highlighted ? Tone.sun : BrandTheme.logoCyan)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Tone.sun.opacity(0.55), BrandTheme.logoPink.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .padding(.horizontal, 4)
    }

    private func trendBadge(_ trend: CareSessionInsightSummary.Trend) -> some View {
        let (icon, title, detail, tint): (String, String, String, Color) = {
            switch trend {
            case .firstRated:
                return ("flag.fill", "First rated session", "Sets the baseline for future comparisons", BrandTheme.logoCyan)
            case let .higher(now, usual):
                return ("arrow.up.right", "Better than usual", "Wellbeing \(score(now))/10 · usual \(score(usual))", BrandTheme.statusPositive)
            case let .steady(now, usual):
                return ("equal", "In line with usual", "Wellbeing \(score(now))/10 · usual \(score(usual))", BrandTheme.statusNeutral)
            case let .lower(now, usual):
                return ("arrow.down.right", "Lower than usual", "Wellbeing \(score(now))/10 · usual \(score(usual))", Tone.attention)
            }
        }()
        return BrandInsetTile(accent: tint) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(tint.opacity(0.18)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(BrandTheme.textPrimary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func genreChip(_ play: CareSessionInsightSummary.GenrePlay) -> some View {
        HStack(spacing: 8) {
            if let genre = play.genre {
                Image(genre.artworkAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .clipShape(Circle())
            }
            Text(play.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BrandTheme.textPrimary)
            if play.count > 1 {
                Text("×\(play.count)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(BrandTheme.textSecondary)
            }
        }
        .padding(.leading, play.genre == nil ? 12 : 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(Capsule().fill(BrandTheme.surfaceInset))
        .overlay(Capsule().stroke(BrandTheme.insetBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func trackGroup(
        _ title: String,
        systemImage: String? = nil,
        glyph: ComfortGlyphKind? = nil,
        tint: Color,
        tracks: [CareSessionInsightSummary.TrackListen]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
                    .foregroundStyle(BrandTheme.textSecondary)
            } icon: {
                if let glyph {
                    ComfortGlyph(kind: glyph, color: tint).frame(width: 18, height: 18)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
            }
            .font(.subheadline.weight(.semibold))
            ForEach(tracks) { track in
                HStack(alignment: .firstTextBaseline) {
                    Text(track.title)
                        .font(.callout)
                        .foregroundStyle(BrandTheme.textPrimary)
                    Spacer(minLength: 8)
                    if let detail = track.detail {
                        Text(detail)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                }
                .padding(.leading, 30)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func bulletLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(BrandTheme.logoCyan.opacity(0.7))
                .frame(width: 5, height: 5)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            Text(text)
                .font(.footnote)
                .foregroundStyle(BrandTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ text: Text, tint: Color = BrandTheme.textSecondary) -> some View {
        text
            .font(.footnote.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint == BrandTheme.textSecondary ? BrandTheme.surfaceInset : tint.opacity(0.16)))
            .overlay(Capsule().stroke(tint == BrandTheme.textSecondary ? BrandTheme.insetBorder : tint.opacity(0.55), lineWidth: 1))
    }

    // MARK: Helpers

    private func hasMusicDetail(_ summary: CareSessionInsightSummary) -> Bool {
        !summary.genres.isEmpty || !summary.liked.isEmpty || !summary.skipped.isEmpty
            || !summary.longestListening.isEmpty || summary.calmRoomVisits > 0 || summary.frustrationBursts > 0
    }

    private func text(for kind: ShareKind, in pack: CareSessionInsightPack) -> String {
        switch kind {
        case .handover: return pack.handoverText
        case .family: return pack.familyText
        case .carePlan: return pack.carePlanBullet
        }
    }

    private func score(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func copy(_ text: String, kind: ShareKind) {
        UIPasteboard.general.string = text
        copiedGeneration += 1
        let generation = copiedGeneration
        withAnimation(CalmMotion.subtle) {
            copiedKind = kind
        }
        // The button's title changes; VoiceOver users hear it too.
        UIAccessibility.post(notification: .announcement, argument: kind.copiedTitle.replacingOccurrences(of: " ✓", with: ""))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard generation == copiedGeneration else { return }
            withAnimation(CalmMotion.subtle) { copiedKind = nil }
        }
    }
}

/// Left-aligned wrapping row for chips of varying width.
struct InsightChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            widest = max(widest, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
