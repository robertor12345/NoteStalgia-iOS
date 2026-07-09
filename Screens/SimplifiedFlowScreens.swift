import SwiftUI

// MARK: - Home — supervisor username + PIN → roster

struct HomeView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen {
                GeometryReader { geo in
                    homeScrollContent(viewportHeight: max(geo.size.height, 400))
                        .frame(maxWidth: .infinity, minHeight: max(geo.size.height, 400))
                }
            }
        }
    }

    @ViewBuilder
    private func homeScrollContent(viewportHeight: CGFloat) -> some View {
        VStack(spacing: SignInPageLayout.sectionSpacing) {
            Spacer(minLength: BrandLayout.homeTopSpacer(min: viewportHeight, horizontalSizeClass: horizontalSizeClass) * 0.35)

            FadeInNoteStalgiaWordmark(magnification: SignInPageLayout.scale, delay: 0)

            // Observes the `auth` store directly, so typing in the sign-in / PIN fields re-renders
            // only this panel — not the wordmark above, not `HomeView`, and not `FlowRootView`'s
            // 60fps orb/sparkle canvases (the coordinator no longer forwards `auth` changes).
            SupervisorAuthPanel(state: state, auth: state.auth, horizontalSizeClass: horizontalSizeClass)

            Spacer(minLength: SignInPageLayout.sectionSpacing)
        }
    }
}

/// The reactive part of the home screen: sign-in form, signed-in shortcuts, and the PIN-reset
/// entry. Observes `auth` so it (and only it) refreshes as the supervisor types.
private struct SupervisorAuthPanel: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var auth: SupervisorAuthStore
    var horizontalSizeClass: UserInterfaceSizeClass?
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email, pin }

    var body: some View {
        if auth.isSignedIn {
            signedInContent
        } else if auth.pinResetActive {
            SupervisorPinResetView(state: state, auth: auth, horizontalSizeClass: horizontalSizeClass)
        } else {
            supervisorSignInContent
        }
    }

    private var signedInContent: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            FadeInLine(
                text: "Signed in — open the resident roster or sign out.",
                delay: 0.06
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            PrimaryButton(title: "One-to-one calm") {
                state.enterOneToOneCalmFlow()
            }
            .padding(.horizontal, 24)

            SecondaryButton(title: "Sign out") {
                state.signOutSupervisor()
            }
            .padding(.horizontal, 24)
        }
    }

    private var supervisorSignInContent: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            FadeInLine(
                text: "Supervisor sign-in for this care home.",
                delay: 0.06
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            BrandCard {
                VStack(alignment: .leading, spacing: 18) {
                    labeledField(
                        title: "Work email",
                        content: {
                            TextField("name@sunrise-care.co.uk", text: $auth.supervisorEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .pin }
                        }
                    )
                    SixDigitPinInput(
                        pin: $auth.supervisorPIN,
                        isError: supervisorPinShowsError,
                        focus: $focusedField,
                        focusValue: Field.pin,
                        onComplete: attemptSignIn
                    )
                }
            }
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            if let error = auth.supervisorSignInError, !error.isEmpty {
                Text(error)
                    .font(SignInPageLayout.captionFont)
                    .foregroundStyle(BrandTheme.nebulaSalmon)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Sign-in error")
                    .accessibilityValue(error)
            }

            PrimaryButton(title: "Continue", action: attemptSignIn)
                .padding(.horizontal, 24)

            Button {
                state.beginSupervisorPinReset()
            } label: {
                Text("Forgot PIN?")
                    .font(.system(size: SignInPageLayout.points(4.5), weight: .medium, design: .default))
                    .foregroundStyle(BrandTheme.gold)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("Forgot PIN")
            .accessibilityHint("Reset your supervisor PIN with your work email")
        }
    }

    private var supervisorPinShowsError: Bool {
        guard let error = auth.supervisorSignInError, !error.isEmpty else { return false }
        return error.localizedCaseInsensitiveContains("pin")
    }

    private func labeledField(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            content()
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
    }

    private func attemptSignIn() {
        if state.completeSupervisorSignIn() == nil {
            CalmExperienceFeedback.signInSuccess()
        }
    }
}

// MARK: - Supervisor PIN reset (POC)

private struct SupervisorPinResetView: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var auth: SupervisorAuthStore
    var horizontalSizeClass: UserInterfaceSizeClass?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, code, newPIN, confirmPIN
    }

    var body: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            FadeInLine(text: stepTitle, delay: 0.06)
                .multilineTextAlignment(.center)
                .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            if let hint = stepHint {
                FadeInLine(text: hint, muted: true, delay: 0.1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
            }

            BrandCard {
                stepContent
            }
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            if let error = auth.pinResetError, !error.isEmpty {
                Text(error)
                    .font(SignInPageLayout.captionFont)
                    .foregroundStyle(BrandTheme.nebulaSalmon)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Reset error")
                    .accessibilityValue(error)
            }

            if auth.pinResetStep == .complete {
                if let message = auth.pinResetSuccessMessage {
                    Text(message)
                        .font(SignInPageLayout.captionFont)
                        .foregroundStyle(BrandTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                PrimaryButton(title: "Back to sign in") {
                    state.finishSupervisorPinReset()
                }
                .padding(.horizontal, 24)
            } else {
                PrimaryButton(title: primaryActionTitle, action: submitCurrentStep)
                    .padding(.horizontal, 24)

                Button {
                    state.cancelSupervisorPinReset()
                } label: {
                    Text("Cancel")
                        .font(SignInPageLayout.captionFont.weight(.medium))
                        .foregroundStyle(BrandTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .onAppear {
            focusedField = initialFocus
        }
        .onChange(of: auth.pinResetStep) { _, _ in
            focusedField = initialFocus
        }
    }

    private var stepTitle: String {
        switch auth.pinResetStep {
        case .email:
            return "Reset your PIN"
        case .verificationCode:
            return "Check your email"
        case .newPIN:
            return "Choose a new PIN"
        case .confirmPIN:
            return "Confirm your new PIN"
        case .complete:
            return "PIN updated"
        }
    }

    private var stepHint: String? {
        switch auth.pinResetStep {
        case .email:
            return "Enter the work email on your supervisor account. We’ll send a verification code."
        case .verificationCode:
            return "Enter the 6-digit code we sent. Demo code: \(SupervisorCredentialStore.demoResetCode)."
        case .newPIN, .confirmPIN:
            return "Pick a new \(SupervisorAuth.pinDigitCount)-digit PIN you’ll use to sign in."
        case .complete:
            return nil
        }
    }

    private var primaryActionTitle: String {
        switch auth.pinResetStep {
        case .email, .verificationCode, .newPIN:
            return "Continue"
        case .confirmPIN:
            return "Update PIN"
        case .complete:
            return "Back to sign in"
        }
    }

    private var initialFocus: Field? {
        switch auth.pinResetStep {
        case .email: return .email
        case .verificationCode: return .code
        case .newPIN: return .newPIN
        case .confirmPIN: return .confirmPIN
        case .complete: return nil
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch auth.pinResetStep {
        case .email:
            labeledField(
                title: "Work email",
                content: {
                    TextField("name@sunrise-care.co.uk", text: $auth.pinResetEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { submitCurrentStep() }
                }
            )
        case .verificationCode:
            labeledField(
                title: "Verification code",
                content: {
                    TextField("000000", text: $auth.pinResetCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .code)
                        .onChange(of: auth.pinResetCode) { _, newValue in
                            let sanitized = String(newValue.filter(\.isWholeNumber).prefix(SupervisorAuth.pinDigitCount))
                            if sanitized != newValue {
                                auth.pinResetCode = sanitized
                            }
                        }
                        .onSubmit { submitCurrentStep() }
                }
            )
        case .newPIN:
            SixDigitPinInput(
                pin: $auth.pinResetNewPIN,
                isError: pinResetShowsError,
                focus: $focusedField,
                focusValue: Field.newPIN,
                onComplete: { state.submitSupervisorPinResetNewPIN() }
            )
        case .confirmPIN:
            SixDigitPinInput(
                pin: $auth.pinResetConfirmPIN,
                isError: pinResetShowsError,
                focus: $focusedField,
                focusValue: Field.confirmPIN,
                onComplete: { submitCurrentStep() }
            )
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(BrandTheme.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
        }
    }

    private var pinResetShowsError: Bool {
        guard let error = auth.pinResetError, !error.isEmpty else { return false }
        return error.localizedCaseInsensitiveContains("pin")
    }

    private func submitCurrentStep() {
        switch auth.pinResetStep {
        case .email:
            state.submitSupervisorPinResetEmail()
        case .verificationCode:
            state.submitSupervisorPinResetCode()
        case .newPIN:
            state.submitSupervisorPinResetNewPIN()
        case .confirmPIN:
            state.submitSupervisorPinResetConfirm()
        case .complete:
            state.finishSupervisorPinReset()
        }
    }

    private func labeledField(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            content()
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
    }
}

// MARK: - Care home picker (multi-home supervisors)

struct CareHomePickerView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back",
                onBack: { state.navigateStaffToHome() },
                onLogout: { state.signOutSupervisor() }
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Which home today?", delay: 0)

                    if let account = state.currentSupervisorAccount() {
                        FadeInLine(
                            text: account.role.isHomeAdmin
                                ? "Signed in as \(account.displayName). Choose the home you’re reviewing."
                                : "Signed in as \(account.displayName). Choose the home you’re working at.",
                            muted: true,
                            delay: 0.06
                        )
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                    }

                    ForEach(state.assignedHomes()) { home in
                        let count = CareRosterEngine.activeResidents(in: home.id, from: state.carePatients).count
                        Button {
                            state.selectHome(home.id)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "building.2.fill")
                                    .font(.title2)
                                    .foregroundStyle(BrandTheme.gold)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(home.name)
                                        .font(BrandTheme.title(.headline))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Text("\(count) active residents · \(home.wings.count) wings")
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(BrandTheme.gold.opacity(0.8))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(BrandTheme.cream.opacity(0.94))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(ChimingPlainButtonStyle())
                    }
                    .padding(.horizontal, 4)
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

// MARK: - Supervisor welcome (post sign-in, before roster)

struct SupervisorWelcomeView: View {
    @ObservedObject var state: SessionPOCState
    @State private var greetingVisible = false
    @State private var loaderVisible = false
    @State private var didScheduleExit = false

    private var displayName: String {
        state.currentSupervisorAccount()?.displayName ?? "Supervisor"
    }

    private var homeName: String? {
        state.currentHome()?.name
    }

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                CalmCircularLoader(diameter: 76)
                    .opacity(loaderVisible ? 1 : 0)
                    .scaleEffect(loaderVisible ? 1 : 0.92)

                Text(welcomeLine)
                    .font(BrandTheme.orbTitleFont(.largeTitle))
                    .tracking(2)
                    .orbOverlayText()
                    .multilineTextAlignment(.center)
                    .opacity(greetingVisible ? 1 : 0)
                    .offset(y: greetingVisible ? 0 : 14)
                    .scaleEffect(greetingVisible ? 1 : 0.97)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(welcomeAccessibilityLabel)
        .onAppear {
            StreamAudioCache.prefetchWarmCatalog()
            withAnimation(CalmMotion.softFade.delay(0.12)) {
                loaderVisible = true
            }
            withAnimation(CalmMotion.gentle.delay(0.28)) {
                greetingVisible = true
            }
            guard !didScheduleExit else { return }
            didScheduleExit = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                guard state.phase == .supervisorWelcome else { return }
                state.transitionToPhase(.carePatientList)
            }
        }
    }

    private var welcomeLine: String {
        if let homeName {
            return "Welcome \(displayName)\n\(homeName)"
        }
        return "Welcome \(displayName)"
    }

    private var welcomeAccessibilityLabel: String {
        if let homeName {
            return "Welcome \(displayName) at \(homeName). Loading roster."
        }
        return "Welcome \(displayName). Loading roster."
    }
}

// MARK: - Entry mode — Camera vs Quick Start

struct EntryModeView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                onBack: { state.goBackFromEntryMode() },
                onLogout: state.isSignedIn ? { state.signOutSupervisor() } : nil
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "How would you like to begin?", delay: 0)
                    FadeInLine(
                        text: "Use a photo as a gentle anchor, or skip straight to how you’re feeling.",
                        delay: 0.06
                    )

                    if state.isCareStaffSession, let patient = state.carePatient(id: state.activeCarePatientId) {
                        BrandCard {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "cross.case.fill")
                                    .font(.title3)
                                    .foregroundStyle(BrandTheme.goldDeep)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Together for a little while")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Text("\(patient.displayName) — \(patient.careContextLabel)")
                                        .font(.caption)
                                        .foregroundStyle(BrandTheme.textSecondary)
                                    Text("Their notes cover light, scent, touch, and sound — keep things soft. Mood tags are just for today.")
                                        .font(.caption2)
                                        .foregroundStyle(BrandTheme.textSecondary.opacity(0.95))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(spacing: 14) {
                        OrbNavTile(
                            title: "Camera",
                            subtitle: "Pick or take a photo, then we’ll shape the session around it.",
                            systemImage: "camera.fill"
                        ) {
                            state.phase = .captureMoment
                        }
                        OrbNavTile(
                            title: "Quick start",
                            subtitle: "No photo — just tell us how you’re doing.",
                            systemImage: "bolt.fill"
                        ) {
                            state.phase = .moodSelect
                        }
                    }
                    .padding(.horizontal, 20)

                }
                .padding(.vertical, 28)
            }
        }
    }
}

// MARK: - Mood select

struct MoodSelectView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                onBack: {
                    state.phase = state.capturedImage != nil ? .captureMoment : .entryMode
                },
                onLogout: state.isSignedIn ? { state.signOutSupervisor() } : nil
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "How are you feeling?", delay: 0)

                    if state.isCareStaffSession, let patient = state.carePatient(id: state.activeCarePatientId) {
                        Text("With \(patient.displayName) — mood tags are just for today.")
                            .font(.caption)
                            .foregroundStyle(BrandTheme.goldDeep)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    TimelineView(.animation(minimumInterval: 1 / OrbRenderBudget.contentFramesPerSecond, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Group {
                            if BrandLayout.isRegularWidth(horizontalSizeClass) {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 20),
                                        GridItem(.flexible(), spacing: 20),
                                    ],
                                    spacing: 24
                                ) {
                                    moodOrbButtons(phase: t)
                                }
                            } else {
                                VStack(spacing: 26) {
                                    moodOrbButtons(phase: t)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 8)

                    PrimaryButton(title: "Begin") {
                        state.beginSession()
                        state.phase = .processingFast
                    }
                    .disabled(state.selectedMoods.isEmpty)
                    .opacity(state.selectedMoods.isEmpty ? 0.45 : 1)
                    .padding(.horizontal, 24)

                }
                .padding(.vertical, 28)
            }
        }
    }

    @ViewBuilder
    private func moodOrbButtons(phase t: TimeInterval) -> some View {
        ForEach(Array(state.moodOptions.enumerated()), id: \.offset) { index, mood in
            OrbMoodNavOrb(
                title: mood,
                index: index,
                phase: t,
                isSelected: state.selectedMoods.contains(mood)
            ) {
                state.toggleMoodSelection(mood)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: state.selectedMoods)
        }
    }
}

// MARK: - End session → Insight (simple + visual)

struct InsightView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        if state.isResidentSession {
            ScreenFadeIn {
                VStack {
                    Spacer()
                    OrbIconNavButton(
                        systemImage: "square.grid.2x2.fill",
                        accessibilityLabel: "Return to playlists",
                        diameter: 64
                    ) {
                        state.returnToResidentProfile()
                    }
                    .padding(.bottom, 32)
                    .safeAreaPadding(.bottom, 16)
                }
                .padding(.horizontal, BrandTheme.contentGutter)
            }
        } else {
            ScreenFadeIn {
                CenteredScrollScreen(
                    backAccessibilityLabel: "Back to profile",
                    onBack: { state.skipCareFeedback() },
                    onLogout: { state.signOutSupervisor() }
                ) {
                    VStack(spacing: 24) {
                        FadeInTitle(text: "How that felt", delay: 0)
                        FadeInLine(
                            text: "A small pause — not a report card.",
                            delay: 0.1
                        )

                        PrimaryButton(title: "Jot a note & nudge the next session") {
                            state.phase = .careSessionFeedback
                        }
                        .padding(.horizontal, 24)

                        SecondaryButton(title: "Skip for now — back to profile") {
                            state.skipCareFeedback()
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 28)
                }
            }
        }
    }
}