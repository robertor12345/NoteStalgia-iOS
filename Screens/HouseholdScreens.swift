import PhotosUI
import SwiftUI

// MARK: - Care at home — create an account

struct HouseholdSignUpView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to sign-in",
                onBack: { state.cancelHouseholdSignUp() }
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Care at home", delay: 0)
                    FadeInLine(
                        text: "Create an account to support one person at home — a parent, a partner or a client.",
                        delay: 0.08
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                    HouseholdSignUpForm(state: state, household: state.householdUI)
                }
                .padding(.vertical, 28)
            }
        }
    }
}

/// Observes the household draft store directly so each keystroke re-renders only this form.
private struct HouseholdSignUpForm: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var household: HouseholdFlowStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focused: Field?
    private enum Field: Hashable { case name, email, pin, confirmPin }

    var body: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            BrandCard {
                VStack(alignment: .leading, spacing: 18) {
                    HouseholdTextField(
                        title: "Your name",
                        text: $household.signUpName,
                        prompt: "First name is fine",
                        identifier: "household.name",
                        contentType: .givenName
                    )
                    .focused($focused, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focused = .email }

                    HouseholdTextField(
                        title: "Email",
                        text: $household.signUpEmail,
                        prompt: "you@example.com",
                        identifier: "household.email",
                        contentType: .emailAddress,
                        keyboard: .emailAddress,
                        autocapitalises: false
                    )
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .pin }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("I am a")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandTheme.textSecondary)
                        BrandSegmentedChoice(
                            title: "I am a",
                            selection: $household.signUpRelationship,
                            options: HouseholdRelationship.allCases.map { BrandChoiceOption(value: $0, label: $0.label) }
                        )
                        .accessibilityIdentifier("household.relationship")
                        .chimeOnChange(of: household.signUpRelationship)
                    }

                    SixDigitPinInput(
                        pin: $household.signUpPIN,
                        isError: pinShowsError,
                        focus: $focused,
                        focusValue: Field.pin,
                        onComplete: { focused = .confirmPin },
                        accessibilityIdentifier: "household.pin",
                        label: "Choose a PIN",
                        hint: "Six digits you’ll remember"
                    )

                    SixDigitPinInput(
                        pin: $household.signUpConfirmPIN,
                        isError: pinShowsError,
                        focus: $focused,
                        focusValue: Field.confirmPin,
                        onComplete: create,
                        accessibilityIdentifier: "household.confirmPin",
                        label: "Confirm your PIN",
                        hint: "Enter the same six digits again"
                    )
                }
            }
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            if let error = household.signUpError, !error.isEmpty {
                BrandMessageTile(text: error)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Sign-up error")
                    .accessibilityValue(error)
            }

            PrimaryButton(title: "Create account", action: create)
                .accessibilityIdentifier("household.create")
                .padding(.horizontal, 24)

            Text("In this prototype the account stays on this iPad — nothing is sent anywhere.")
                .font(.footnote)
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .onChange(of: household.signUpName) { _, _ in clearError() }
        .onChange(of: household.signUpEmail) { _, _ in clearError() }
        .onChange(of: household.signUpPIN) { _, _ in clearError() }
        .onChange(of: household.signUpConfirmPIN) { _, _ in clearError() }
        .onAppear {
            // Land in the first field once the screen has faded in.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if focused == nil { focused = .name }
            }
        }
    }

    private var pinShowsError: Bool {
        guard let error = household.signUpError, !error.isEmpty else { return false }
        return error.localizedCaseInsensitiveContains("pin")
    }

    private func clearError() {
        guard household.signUpError != nil else { return }
        household.signUpError = nil
    }

    private func create() {
        Task { @MainActor in
            if await state.signUpHousehold() == nil {
                CalmExperienceFeedback.signInSuccess()
            }
        }
    }
}

// MARK: - Care at home — register the resident

struct HouseholdResidentSetupView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(onLogout: { state.signOutSupervisor() }) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Who are you caring for?", delay: 0)
                    FadeInLine(
                        text: "Their age and background shape the music discovery; the photo is just for you.",
                        delay: 0.08
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                    HouseholdResidentSetupForm(state: state, household: state.householdUI)
                }
                .padding(.vertical, 28)
            }
        }
        .onAppear {
            if !state.isSignedIn {
                state.phase = .home
            }
        }
    }
}

private struct HouseholdResidentSetupForm: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var household: HouseholdFlowStore
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isLoadingPhoto = false
    @State private var photoLoadError: String?
    @FocusState private var focused: Field?
    private enum Field: Hashable { case name, age }

    var body: some View {
        VStack(spacing: 22) {
            BrandCard {
                VStack(spacing: 18) {
                    photoSection

                    HouseholdTextField(
                        title: "Name",
                        text: $household.residentName,
                        prompt: "Full name or preferred name",
                        identifier: "household.residentName",
                        contentType: .name
                    )
                    .focused($focused, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focused = .age }

                    HouseholdTextField(
                        title: "Age",
                        text: $household.residentAge,
                        prompt: "Age",
                        identifier: "household.residentAge",
                        keyboard: .numberPad
                    )
                    .focused($focused, equals: .age)

                    ResidentNationalityMenuField(
                        title: "Nationality",
                        selection: $household.residentNationality,
                        caption: "Used with age to put the music of their youth first."
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)

            if let error = household.residentSetupError, !error.isEmpty {
                BrandMessageTile(text: error)
                    .padding(.horizontal, 12)
                    .accessibilityLabel("Setup error")
                    .accessibilityValue(error)
            }

            PrimaryButton(title: "Start listening discovery") {
                focused = nil
                if state.completeHouseholdResidentSetup(startDiscovery: true) == nil {
                    CalmExperienceFeedback.signInSuccess()
                }
            }
            .accessibilityIdentifier("household.startDiscovery")
            .padding(.horizontal, 24)

            SecondaryButton(title: "Set up without discovery") {
                focused = nil
                if state.completeHouseholdResidentSetup(startDiscovery: false) == nil {
                    CalmExperienceFeedback.signInSuccess()
                }
            }
            .accessibilityIdentifier("household.skipDiscovery")
            .padding(.horizontal, 24)

            Text("Discovery plays seven short clips, one per genre; they tap a face for each and their playlists take shape. You can run it any time from their home screen.")
                .font(.footnote)
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)   // was cut off after one line ("… and their…")
                .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $household.residentPhoto)
                .ignoresSafeArea()
        }
        .onChange(of: household.residentName) { _, _ in clearError() }
        .onChange(of: household.residentAge) { _, _ in clearError() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if focused == nil, household.residentName.isEmpty { focused = .name }
            }
        }
        .onChange(of: photoItem) { _, new in
            guard let new else { return }
            isLoadingPhoto = true
            photoLoadError = nil
            Task.detached(priority: .userInitiated) {
                let data = try? await new.loadTransferable(type: Data.self)
                let image = data.flatMap { UIImage.decodedThumbnail(from: $0, maxDimension: 600) }
                await MainActor.run {
                    isLoadingPhoto = false
                    if let image {
                        household.residentPhoto = image
                    } else {
                        photoLoadError = "That photo couldn’t be opened. Try another one."
                    }
                }
            }
        }
    }

    private func clearError() {
        guard household.residentSetupError != nil else { return }
        household.residentSetupError = nil
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 14) {
            if let photo = household.residentPhoto {
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
                OrbPickerLabel(title: "Choose photo (optional)", systemImage: "photo.stack")
            }
            .accessibilityIdentifier("household.choosePhoto")
            .buttonStyle(ChimingPlainButtonStyle())

            PhotoLoadStatusLine(isLoading: isLoadingPhoto, error: photoLoadError)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { showCamera = true } label: {
                    OrbPickerLabel(title: "Take photo", systemImage: "camera.fill")
                }
                .accessibilityIdentifier("household.takePhoto")
                .buttonStyle(ChimingPlainButtonStyle())
            }
        }
    }
}

// MARK: - Care at home — home screen (one resident)

struct HouseholdHomeView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var resident: CarePatientProfile? {
        state.householdResident()
    }

    private var portraitSize: CGFloat {
        BrandLayout.scaled(112, regular: 144, horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(onLogout: { state.signOutSupervisor() }) {
                VStack(spacing: 24) {
                    if let resident {
                        CarePatientPortraitView(
                            assetName: resident.stockPortraitAssetName,
                            customImage: state.portraitImage(for: resident.id),
                            size: portraitSize
                        )
                        .shadow(color: BrandTheme.brown.opacity(0.12), radius: 10, y: 4)

                        VStack(spacing: 6) {
                            Text(resident.displayName)
                                .font(BrandTheme.orbTitleFont(.title))
                                .orbOverlayText()
                                .multilineTextAlignment(.center)
                            Text(carerLine)
                                .font(BrandTheme.orbLineFont())
                                .orbOverlayText(muted: true)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        PrimaryButton(title: "Open calm surface") {
                            state.selectedCarePatientId = resident.id
                            state.openResidentProfile()
                        }
                        .accessibilityIdentifier("household.openSurface")
                        .padding(.horizontal, 24)

                        lastSessionCard(resident)

                        actionCard(
                            title: "Insights & trends",
                            subtitle: insightsSubtitle(resident),
                            systemImage: "chart.line.uptrend.xyaxis",
                            identifier: "household.insights"
                        ) {
                            state.openHouseholdInsights()
                        }

                        actionCard(
                            title: "Profile & preferences",
                            subtitle: "Playlists, liked songs, comfort notes and every session on file.",
                            systemImage: "person.text.rectangle",
                            identifier: "household.profile"
                        ) {
                            state.selectedCarePatientId = resident.id
                            state.transitionToPhase(.carePatientDetail)
                        }

                        actionCard(
                            title: "Listening discovery",
                            subtitle: "Seven short clips — they tap a face for each, and their playlists reshape from what they enjoy.",
                            systemImage: "waveform",
                            identifier: "household.discovery"
                        ) {
                            state.selectedCarePatientId = resident.id
                            state.startDiscoveryCalibration(for: resident.id)
                        }

                        actionCard(
                            title: "Log an activity",
                            subtitle: "A walk, a visit, a game — anything done away from the app. Say how they were and it shows in their insights.",
                            systemImage: "figure.walk.circle",
                            identifier: "household.logActivity"
                        ) {
                            state.selectedCarePatientId = resident.id
                            state.beginActivityLog()
                        }

                        FeedbackPreferencesCard()
                    } else {
                        FadeInTitle(text: "Care at home", delay: 0)
                        FadeInLine(text: "Register the person you care for to begin.", delay: 0.08)
                        PrimaryButton(title: "Register them now") {
                            state.transitionToPhase(.householdResidentSetup)
                        }
                        .accessibilityIdentifier("household.register")
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .onAppear {
            if !state.isSignedIn {
                state.phase = .home
            } else if let resident, state.selectedCarePatientId != resident.id {
                state.selectedCarePatientId = resident.id
            }
        }
    }

    private var carerLine: String {
        guard let account = state.currentHouseholdAccount() else { return "Cared for at home" }
        return "\(account.displayName) · \(account.relationship.label.lowercased()) · cared for at home"
    }

    private func insightsSubtitle(_ resident: CarePatientProfile) -> String {
        let records = state.recordsForPatient(resident.id)
        let windowStart = Date().addingTimeInterval(-Double(CareHomeAnalytics.dashboardWindowDays) * 86_400)
        let recent = records.filter { $0.date >= windowStart }.count
        guard recent > 0 else { return "Trends, at-ease and wellbeing over time — from the first session on." }
        return "\(recent) session\(recent == 1 ? "" : "s") in the last \(CareHomeAnalytics.dashboardWindowDays) days · at-ease and wellbeing trends"
    }

    @ViewBuilder
    private func lastSessionCard(_ resident: CarePatientProfile) -> some View {
        if let last = state.recordsForPatient(resident.id).first {
            BrandCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        BrandSectionHeader(title: "Last session", systemImage: "clock")
                        Text(relativeDay(last.date))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                    BrandStatTileRow {
                        BrandStatTile(
                            value: "\(last.calmPercent)%",
                            label: "At ease",
                            tint: CareAtEaseTone.tint(percent: last.calmPercent)
                        )
                        BrandStatTile(value: last.moodSummary == "—" ? "None noted" : last.moodSummary, label: "Mood tags")
                    }
                    if let step = last.insightSuggestedNextStep {
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
                                    Text(step)
                                        .font(.callout)
                                        .foregroundStyle(BrandTheme.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
        } else {
            BrandCard {
                VStack(alignment: .leading, spacing: 8) {
                    BrandSectionHeader(title: "No sessions yet", systemImage: "clock")
                    Text("Open the calm surface and hand over the iPad. When you take it back, a few quick observations build their history.")
                        .font(.callout)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
        }
    }

    private func actionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(BrandTheme.gold)
                    .frame(width: 34)
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
                    .foregroundStyle(BrandTheme.gold.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCardSurface(cornerRadius: 20, opacity: BrandTheme.rowOpacity)
        }
        .accessibilityIdentifier(identifier)
        .buttonStyle(ChimingPlainButtonStyle())
        .padding(.horizontal, 4)
    }

    private func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        return days < 7 ? "\(days) days ago" : date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Care at home — insights & trends for the one resident

struct HouseholdInsightsView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var presentation: ResidentInsightsPresentation? {
        state.householdInsightsPresentation()
    }

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to home",
                onBack: { state.returnToHouseholdHome() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    if let p = presentation {
                        header(p)
                        if p.hasSessionData {
                            DashboardTrendGraphsStrip(
                                series: p.trendSeries,
                                title: "\(firstName(p.residentName))’s trends",
                                subtitle: "Tap a chart to expand — tap again to collapse."
                            )
                            .padding(.horizontal, 4)
                            kpiGrid(p)
                            observationsCard(p)
                            respondedToCard(p)
                            if let step = p.suggestedNextStep {
                                nextStepCard(step)
                            }
                            recentSessionsCard(p)
                        } else {
                            emptyState(p)
                        }
                        activitiesCard(p)
                    }
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

    /// What was done away from the app and how they were: the household's own log (`ActivityInsights`), over 30 days.
    private func activitiesCard(_ p: ResidentInsightsPresentation) -> some View {
        let activities = state.householdActivityInsights()
        return BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(
                    title: "Outside the app",
                    systemImage: "figure.walk.circle",
                    subtitle: "What you have done together away from the app, and how \(firstName(p.residentName)) was, over the last 30 days.",
                    identifier: "household.activities"
                )
                if let activities, !activities.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 10) {
                        BrandStatTile(value: "\(activities.count)", label: "Activities", detail: "in 30 days")
                        BrandStatTile(
                            value: activities.averageEngagement.map { String(format: "%.1f", $0) } ?? "—",
                            label: "How they were",
                            detail: "out of 10",
                            tint: activities.averageEngagement.map { BrandRatingTone.tint(outOfTen: $0) }
                        )
                    }
                    InsightChipFlow(spacing: 8) {
                        ForEach(GroupParticipantState.activityOptions) { option in
                            if let n = activities.byResponse[option], n > 0 {
                                BrandStatusChip(text: "\(n) · \(option.label)", systemImage: option.systemImage, tint: option.brandTint)
                            }
                        }
                    }
                    BrandRowsTile {
                        ForEach(Array(activities.rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 { BrandHairline() }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(row.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Spacer(minLength: 8)
                                    Text(row.date.formatted(.dateTime.day().month(.abbreviated)))
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.textSecondary)
                                }
                                if let response = row.response {
                                    BrandStatusChip(text: response.label, systemImage: response.systemImage, tint: response.brandTint)
                                }
                                if let note = row.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                } else {
                    Text("Nothing logged yet. Log a walk, a visit or a game and how \(firstName(p.residentName)) was will show here.")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                SecondaryButton(title: "Log an activity") {
                    state.beginActivityLog()
                }
                .accessibilityIdentifier("household.insights.logActivity")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func header(_ p: ResidentInsightsPresentation) -> some View {
        VStack(spacing: 8) {
            FadeInTitle(text: "\(firstName(p.residentName))’s insights", delay: 0)
            FadeInLine(
                text: "\(p.periodLabel) · \(p.totalSessions) session\(p.totalSessions == 1 ? "" : "s") on file",
                font: BrandTheme.orbHintFont(),
                muted: true,
                delay: 0.04
            )
            .multilineTextAlignment(.center)
            if p.hasSessionData {
                VStack(spacing: 6) {
                    DashboardTrendChip(trend: p.trend)
                    Text(p.trendLine)
                        .font(.caption.weight(.medium))
                        .orbOverlayText(muted: true)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func kpiGrid(_ p: ResidentInsightsPresentation) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(p.kpis.enumerated()), id: \.element.id) { index, kpi in
                DashboardKPICardView(card: kpi, delay: 0.05 + Double(index) * 0.04)
            }
        }
        .padding(.horizontal, 4)
    }

    private func observationsCard(_ p: ResidentInsightsPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: "Your observations",
                    systemImage: "heart.text.square",
                    subtitle: p.observations.hasData ? "Averages of the 1–10 ratings you give after each session." : nil
                )
                if p.observations.hasData {
                    BrandInsetTile {
                        VStack(alignment: .leading, spacing: 14) {
                            observationRow("Mood / affect", p.observations.averageMood)
                            observationRow("Alertness", p.observations.averageAlertness)
                            observationRow("Emotional presentation", p.observations.averageEmotionalState)
                            observationRow("Orientation", p.observations.averageLucidity)
                        }
                    }
                    Text("Based on \(p.observations.sessionCount) rated session\(p.observations.sessionCount == 1 ? "" : "s") · \(BrandRatingTone.legend)")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Rate a session when you take the iPad back and the averages appear here.")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func observationRow(_ label: String, _ value: Double?) -> some View {
        BrandRatingRow(
            label: label,
            valueText: value.map { String(format: "%.1f", $0) } ?? "—",
            fraction: (value ?? 0) / 10,
            tint: value.map { BrandRatingTone.tint(outOfTen: $0) } ?? BrandTheme.textSecondary,
            spokenValue: value.map { String(format: "%.1f out of 10", $0) } ?? "no rating yet"
        )
    }

    private func respondedToCard(_ p: ResidentInsightsPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(title: "What they respond to", systemImage: "music.note")
                if p.genreHighlights.isEmpty, p.likedLine == nil {
                    Text("Genres and songs they choose on the calm surface show up here.")
                        .font(.caption)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(p.genreHighlights.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { BrandHairline() }
                        HStack(spacing: 12) {
                            if let genre = item.genre {
                                Image(genre.artworkAssetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundStyle(BrandTheme.gold)
                                    .frame(width: 30, height: 30)
                                    .accessibilityHidden(true)
                            }
                            Text(item.name)
                                .font(.body)
                                .foregroundStyle(BrandTheme.textPrimary)
                            Spacer()
                            BrandStatusChip(text: "\(item.plays) play\(item.plays == 1 ? "" : "s")", systemImage: "play.fill")
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                    if let liked = p.likedLine {
                        Label {
                            Text("Liked · \(liked)")
                        } icon: {
                            ComfortGlyph(kind: .sun, color: BrandTheme.statusCaution).frame(width: 16, height: 16)
                        }
                        .font(.caption)
                        .foregroundStyle(BrandTheme.statusCaution)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let skipped = p.skippedLine {
                        Label {
                            Text("Moved on from · \(skipped)")
                        } icon: {
                            ComfortGlyph(kind: .cloud, color: BrandTheme.statusNeutral).frame(width: 16, height: 16)
                        }
                        .font(.caption)
                        .foregroundStyle(BrandTheme.statusNeutral)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func nextStepCard(_ step: String) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 10) {
                BrandSectionHeader(title: "Suggested next step", systemImage: "lightbulb.fill", tint: BrandTheme.statusCaution)
                BrandInsetTile(accent: BrandTheme.statusCaution) {
                    Text(step)
                        .font(.body)
                        .foregroundStyle(BrandTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func recentSessionsCard(_ p: ResidentInsightsPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 10) {
                BrandSectionHeader(title: "Recent sessions", systemImage: "clock")
                BrandRowsTile(spacing: 10) {
                    ForEach(Array(p.recentSessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { BrandHairline() }
                        DashboardRecentSessionRow(session: session)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func emptyState(_ p: ResidentInsightsPresentation) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 10) {
                BrandSectionHeader(title: "Insights appear after the first session", systemImage: "chart.line.uptrend.xyaxis")
                Text("Open \(firstName(p.residentName))’s calm surface, hand over the iPad, and rate the session when you take it back. Trends build from there.")
                    .font(.body)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton(title: "Back to home") {
                    state.returnToHouseholdHome()
                }
                .accessibilityIdentifier("household.insightsBack")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func firstName(_ name: String) -> String {
        String(name.split(separator: " ").first ?? Substring(name))
    }
}

// MARK: - Shared field

private struct HouseholdTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let identifier: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var autocapitalises: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            TextField(title, text: $text, prompt: BrandTheme.fieldPrompt(prompt))
                .accessibilityIdentifier(identifier)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalises ? .words : .never)
                .autocorrectionDisabled(!autocapitalises)
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
