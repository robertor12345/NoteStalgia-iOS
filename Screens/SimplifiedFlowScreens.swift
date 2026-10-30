import SwiftUI

// MARK: - Home — supervisor username + PIN → roster

struct HomeView: View {
    @ObservedObject var state: SessionPOCState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Only the signed-in flag is observed here, so Log out takes its place in the top bar the moment
    /// someone signs in, while typing in the sign-in fields still re-renders just the panel below.
    @State private var signedIn = false

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(onLogout: signedIn ? { state.signOutSupervisor() } : nil) {
                GeometryReader { geo in
                    homeScrollContent(viewportHeight: max(geo.size.height, 400))
                        .frame(maxWidth: .infinity, minHeight: max(geo.size.height, 400))
                }
            }
        }
        .onReceive(state.auth.$isSignedIn.removeDuplicates()) { signedIn = $0 }
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
                // A stale "Enter your work email." should not linger once they start fixing it.
                // PIN edits only clear it below six digits — the sixth digit itself submits.
                .onChange(of: auth.supervisorEmail) { _, _ in
                    clearSignInError()
                }
                .onChange(of: auth.supervisorPIN) { _, pin in
                    if pin.count < SupervisorAuth.pinDigitCount {
                        clearSignInError()
                    }
                }
        }
    }

    private func clearSignInError() {
        guard auth.supervisorSignInError != nil else { return }
        auth.supervisorSignInError = nil
    }

    private var signedInContent: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            signedInCard
                .padding(.horizontal, 24)

            PrimaryButton(title: state.isHouseholdAccount ? "Open Care at home" : "Open the resident roster") {
                state.enterOneToOneCalmFlow()
            }
            .accessibilityIdentifier("home.oneToOne")
            .padding(.horizontal, 24)
        }
    }

    /// Who is signed in, on the same card grammar as every other page. Log out lives in the top bar.
    private var signedInCard: some View {
        let household = state.currentHouseholdAccount()
        let staff = state.currentSupervisorAccount()
        let name = household?.displayName ?? staff?.displayName
        let email = household?.email ?? staff?.email
        return BrandCard {
            VStack(alignment: .leading, spacing: 8) {
                BrandSectionHeader(title: "Signed in", systemImage: "person.crop.circle.badge.checkmark")
                VStack(spacing: 0) {
                    if let name {
                        BrandKeyValueRow(label: "Name", value: name, isLast: email == nil && roleLabel == nil && homeName == nil)
                    }
                    if let email {
                        BrandKeyValueRow(label: "Email", value: email, isLast: roleLabel == nil && homeName == nil)
                    }
                    if let roleLabel {
                        BrandKeyValueRow(label: "Role", value: roleLabel, isLast: homeName == nil)
                    }
                    if let homeName {
                        BrandKeyValueRow(label: state.isHouseholdAccount ? "Care at home" : "Care home", value: homeName, isLast: true)
                    }
                }
            }
        }
        .accessibilityIdentifier("home.signedIn")
    }

    private var roleLabel: String? {
        if state.isHouseholdAccount {
            return state.currentHouseholdAccount()?.relationship.label
        }
        switch state.currentSupervisorAccount()?.role {
        case .supervisor: return "Care staff"
        case .homeLead: return "Home lead"
        case .orgAdmin: return "Organisation admin"
        case .household: return "Care at home"
        case nil: return nil
        }
    }

    private var homeName: String? {
        state.currentHome()?.name
    }

    private var supervisorSignInContent: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            FadeInLine(
                text: "Sign in with your email and 6-digit PIN.",
                delay: 0.06
            )
            .multilineTextAlignment(.center)
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            BrandCard {
                VStack(alignment: .leading, spacing: 18) {
                    labeledField(
                        title: "Email",
                        content: {
                            TextField("Work email", text: $auth.supervisorEmail, prompt: BrandTheme.fieldPrompt("name@sunrise-care.co.uk"))
                                .accessibilityIdentifier("signin.email")
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
                BrandMessageTile(text: error)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Sign-in error")
                    .accessibilityValue(error)
            }

            PrimaryButton(title: auth.isAuthenticating ? "Signing in…" : "Continue", action: attemptSignIn)
                .accessibilityIdentifier("signin.continue")
                .disabled(auth.isAuthenticating)
                .padding(.horizontal, 24)

            Button {
                state.beginSupervisorPinReset()
            } label: {
                Text("Forgot PIN?")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BrandTheme.gold)
                    // 44pt touch target without moving the form: hit area only, no layout height.
                    .expandedHitArea(vertical: 14, horizontal: 16)
            }
            .accessibilityIdentifier("signin.forgotPin")
            .buttonStyle(ChimingPlainButtonStyle())
            .padding(.top, 4)
            .accessibilityLabel("Forgot PIN")
            .accessibilityHint("Reset your PIN with your email")

            Button {
                state.beginHouseholdSignUp()
            } label: {
                Text("Caring for someone at home? Create an account")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BrandTheme.gold)
                    .multilineTextAlignment(.center)
                    .expandedHitArea(vertical: 14, horizontal: 16)
            }
            .accessibilityIdentifier("signin.createHousehold")
            .buttonStyle(ChimingPlainButtonStyle())
            .padding(.top, 2)
            .accessibilityLabel("Create a Care at home account")
            .accessibilityHint("For family members and private carers supporting one person at home")

            // Organisation onboarding needs the backend; offline the links would lead nowhere.
            if state.usesBackend {
                Button {
                    state.beginOrgRequest()
                } label: {
                    Text("Setting up a care home or organisation? Request a workspace")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BrandTheme.gold)
                        .multilineTextAlignment(.center)
                        .expandedHitArea(vertical: 14, horizontal: 16)
                }
                .accessibilityIdentifier("signin.requestWorkspace")
                .buttonStyle(ChimingPlainButtonStyle())
                .padding(.top, 2)
                .accessibilityLabel("Request a workspace for a care home or organisation")
                .accessibilityHint("Verifies your work email, then an activation code is sent")

                Button {
                    state.beginOrgCode()
                } label: {
                    Text("I have an invite or activation code")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BrandTheme.gold)
                        .multilineTextAlignment(.center)
                        .expandedHitArea(vertical: 14, horizontal: 16)
                }
                .accessibilityIdentifier("signin.haveCode")
                .buttonStyle(ChimingPlainButtonStyle())
                .padding(.top, 2)
                .accessibilityLabel("I have an invite or activation code")
                .accessibilityHint("Codes start with ORG- or INV-")
            }
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
        Task { @MainActor in
            if await state.signIn() == nil {
                CalmExperienceFeedback.signInSuccess()
            }
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
                BrandMessageTile(text: error)
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
                .accessibilityIdentifier("pinReset.backToSignIn")
                .padding(.horizontal, 24)
            } else {
                PrimaryButton(title: primaryActionTitle, action: submitCurrentStep)
                .accessibilityIdentifier("pinReset.primary")
                    .padding(.horizontal, 24)

                Button {
                    state.cancelSupervisorPinReset()
                } label: {
                    Text("Cancel")
                        .font(SignInPageLayout.captionFont.weight(.medium))
                        .foregroundStyle(BrandTheme.textSecondary)
                        .frame(minWidth: 88, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ChimingPlainButtonStyle())
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
            if let code = auth.pinResetDevCode { return "Enter the 6-digit code we sent. Demo code: \(code)." }
            if APIConfig.isConfigured { return "Enter the 6-digit code we sent to that email." }
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
                    TextField("Work email", text: $auth.pinResetEmail, prompt: BrandTheme.fieldPrompt("name@sunrise-care.co.uk"))
                    .accessibilityIdentifier("pinReset.email")
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
                    TextField("Verification code", text: $auth.pinResetCode, prompt: BrandTheme.fieldPrompt("000000"))
                    .accessibilityIdentifier("pinReset.code")
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
            Task { @MainActor in await state.pinResetSubmitEmail() }
        case .verificationCode:
            state.pinResetSubmitCode()
        case .newPIN:
            state.submitSupervisorPinResetNewPIN()
        case .confirmPIN:
            Task { @MainActor in await state.pinResetConfirm() }
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
                            .brandCardSurface(cornerRadius: 20, opacity: BrandTheme.rowOpacity)
                        }
                        .accessibilityIdentifier("homePicker.\(home.name)")
                        .buttonStyle(ChimingPlainButtonStyle())
                    }
                    .padding(.horizontal, 4)

                    if state.usesBackend, state.currentSupervisorAccount()?.role == .orgAdmin {
                        SecondaryButton(title: "Organisation set-up") {
                            state.openOrgSetup(resume: true)
                        }
                        .accessibilityIdentifier("homePicker.orgSetup")
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                    }
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
    @State private var didAnimateEntrance = false
    /// Shown only when the readiness gate runs past `RosterWarmUp.longWaitHintDelay`.
    @State private var showsLongerWaitHint = false

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

                // Space is reserved so the greeting never shifts when the hint fades in.
                Text(state.isHouseholdAccount ? "Preparing their home…" : "Preparing the roster…")
                    .font(BrandTheme.orbHintFont())
                    .orbOverlayText(muted: true)
                    .opacity(showsLongerWaitHint ? 1 : 0)
                    .accessibilityHidden(!showsLongerWaitHint)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(welcomeAccessibilityLabel)
        .onAppear {
            StreamAudioCache.prefetchWarmCatalog()
            if !didAnimateEntrance {
                didAnimateEntrance = true
                withAnimation(CalmMotion.softFade.delay(0.12)) {
                    loaderVisible = true
                }
                withAnimation(CalmMotion.gentle.delay(0.28)) {
                    greetingVisible = true
                }
            }
        }
        // Moves on when the roster is genuinely ready (seeded, portraits decoded, presentation
        // cached) — never before the minimum dwell, never after the cap. Cancelled with the view.
        .task {
            let start = Date()
            let hint = Task { @MainActor in
                try? await Task.sleep(for: .seconds(RosterWarmUp.longWaitHintDelay))
                guard !Task.isCancelled else { return }
                withAnimation(CalmMotion.softFade) { showsLongerWaitHint = true }
            }
            _ = await RosterWarmUp.awaitRosterReady(state: state, start: start)
            hint.cancel()
            guard !Task.isCancelled, state.phase == .supervisorWelcome else { return }
            if let jump = DemoLaunchOptions.jump, state.performDemoJump(jump) { return }
            state.transitionToPhase(state.staffHubPhase())
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
                            VStack(alignment: .leading, spacing: 8) {
                                BrandSectionHeader(
                                    title: "Together for a little while",
                                    systemImage: "cross.case.fill",
                                    subtitle: "\(patient.displayName) — \(patient.careContextLabel)"
                                )
                                Text("Their notes cover light, scent, touch, and sound — keep things soft. Mood tags are just for today.")
                                    .font(.caption)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
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
    @Environment(\.flowContainerSize) private var flowContainerSize
    @Environment(\.flowAmbientPaused) private var flowAmbientPaused

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
                            .font(.subheadline.weight(.medium))
                            .orbOverlayText(muted: true)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    TimelineView(.animation(minimumInterval: 1 / OrbRenderBudget.contentFramesPerSecond, paused: flowAmbientPaused)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Group {
                            if BrandLayout.isRegularWidth(horizontalSizeClass)
                                || BrandLayout.compactPhoneScale(for: flowContainerSize) > 1 {
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
                    .accessibilityIdentifier("mood.begin")
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
            let isSelected = state.selectedMoods.contains(mood)
            OrbMoodNavOrb(
                title: mood,
                index: index,
                isSelected: isSelected
            ) {
                state.toggleMoodSelection(mood)
            }
            .modifier(MoodOrbFloat(index: index, phase: t, isSelected: isSelected))
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
                    .accessibilityIdentifier("insight.returnToPlaylists")
                    .padding(.bottom, 32)
                    .safeAreaPadding(.bottom, 16)
                }
                .padding(.horizontal, BrandTheme.contentGutter)
            }
        } else {
            ScreenFadeIn {
                CenteredScrollScreen(
                    backTitle: "Skip",
                    backAccessibilityLabel: "Skip for now — saves the session and returns to the profile",
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
                        .accessibilityIdentifier("insight.note")
                        .padding(.horizontal, 24)

                        SecondaryButton(title: "Skip for now — back to profile") {
                            state.skipCareFeedback()
                        }
                        .accessibilityIdentifier("insight.skip")
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 28)
                }
            }
        }
    }
}