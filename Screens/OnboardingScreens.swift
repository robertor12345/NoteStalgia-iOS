import SwiftUI
import UniformTypeIdentifiers

// MARK: - Request a workspace (sign-in screen → form → verification code → approved)

struct OrgRequestView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to sign-in",
                onBack: { state.cancelOnboardingEntry() }
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Request a workspace", delay: 0)
                    FadeInLine(
                        text: "For care homes and groups. We verify your work email, check the organisation, then send an activation code.",
                        delay: 0.08
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                    OrgRequestForm(state: state, onboarding: state.onboarding)
                }
                .padding(.vertical, 28)
            }
        }
    }
}

private struct OrgRequestForm: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var onboarding: OnboardingStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focused: Field?
    private enum Field: Hashable { case org, name, email, phone, cqc, notes, code }

    var body: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            switch onboarding.requestStep {
            case .form: formCard
            case .verify: verifyCard
            case .done: doneCard
            }

            OnboardingMessages(onboarding: onboarding, errorLabel: "Request error")

            switch onboarding.requestStep {
            case .form:
                PrimaryButton(title: onboarding.isBusy ? "Sending…" : "Send request", action: submit)
                    .accessibilityIdentifier("onboarding.request.submit")
                    .disabled(onboarding.isBusy)
                    .padding(.horizontal, 24)
            case .verify:
                PrimaryButton(title: onboarding.isBusy ? "Checking…" : "Verify", action: verify)
                    .accessibilityIdentifier("onboarding.verify")
                    .disabled(onboarding.isBusy)
                    .padding(.horizontal, 24)
                OnboardingActionLink(title: "Edit the request") {
                    onboarding.error = nil
                    onboarding.requestStep = .form
                }
            case .done:
                if onboarding.activationCodeFromServer != nil {
                    PrimaryButton(title: "Activate the workspace") {
                        state.continueToActivation()
                    }
                    .accessibilityIdentifier("onboarding.activate")
                    .padding(.horizontal, 24)
                } else {
                    SecondaryButton(title: "Back to sign-in") {
                        state.cancelOnboardingEntry()
                    }
                    .accessibilityIdentifier("onboarding.request.backToSignIn")
                    .padding(.horizontal, 24)
                }
            }
        }
        .fieldFeedback(from: onboarding)
        .onChange(of: onboarding.orgNameDraft) { _, _ in clearError() }
        .onChange(of: onboarding.requesterName) { _, _ in clearError() }
        .onChange(of: onboarding.requestEmail) { _, _ in clearError() }
        .onChange(of: onboarding.verifyCode) { _, _ in clearError() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if focused == nil, onboarding.requestStep == .form { focused = .org }
            }
        }
    }

    private var formCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 18) {
                OnboardingField(title: "Organisation name", text: $onboarding.orgNameDraft, prompt: "Willow Care Group", identifier: "onboarding.request.org", contentType: .organizationName, maxLength: 120)
                    .focused($focused, equals: .org)
                    .submitLabel(.next)
                    .onSubmit { focused = .name }
                OnboardingField(title: "Your name", text: $onboarding.requesterName, prompt: "First and last name", identifier: "onboarding.request.name", contentType: .name, maxLength: 80)
                    .focused($focused, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focused = .email }
                OnboardingField(title: "Work email", text: $onboarding.requestEmail, prompt: "you@willow-care.co.uk", identifier: "onboarding.request.email", contentType: .emailAddress, keyboard: .emailAddress, autocapitalises: false, filter: .email)
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .phone }
                OnboardingField(title: "Phone (optional)", text: $onboarding.requestPhone, prompt: "0161 000 0000", identifier: "onboarding.request.phone", contentType: .telephoneNumber, keyboard: .phonePad, autocapitalises: false, filter: .phone)
                    .focused($focused, equals: .phone)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your role").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                    BrandSegmentedChoice(title: "Your role", selection: $onboarding.requesterRole, options: OrgRequesterRole.allCases.map { BrandChoiceOption(value: $0, label: $0.label) })
                        .accessibilityIdentifier("onboarding.request.role")
                        .chimeOnChange(of: onboarding.requesterRole)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("How many homes").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                    BrandSegmentedChoice(title: "How many homes", selection: $onboarding.homesBand, options: OrgHomesBand.allCases.map { BrandChoiceOption(value: $0, label: $0.label) })
                        .accessibilityIdentifier("onboarding.request.homes")
                        .chimeOnChange(of: onboarding.homesBand)
                }

                OnboardingField(title: "CQC provider ID (optional)", text: $onboarding.requestCqc, prompt: "1-123456789", identifier: "onboarding.request.cqc", keyboard: .numbersAndPunctuation, autocapitalises: false, filter: .cqcId)
                    .focused($focused, equals: .cqc)
                OnboardingField(title: "Anything we should know (optional)", text: $onboarding.requestNotes, prompt: "Two homes in Stockport, opening a third in spring", identifier: "onboarding.request.notes", axis: .vertical, maxLength: 1000)
                    .focused($focused, equals: .notes)

                OnboardingToggleRow(
                    title: "We can use these details to set up your workspace and contact you about it.",
                    isOn: $onboarding.requestConsent,
                    identifier: "onboarding.request.consent"
                )
            }
        }
        .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
    }

    private var verifyCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                BrandSectionHeader(title: "Check your email", systemImage: "envelope", subtitle: "We sent a six-digit code to \(onboarding.requestEmail.lowercased()). It expires in 10 minutes.")
                SixDigitPinInput(
                    pin: $onboarding.verifyCode,
                    isError: (onboarding.error ?? "").localizedCaseInsensitiveContains("code"),
                    focus: $focused,
                    focusValue: Field.code,
                    onComplete: verify,
                    accessibilityIdentifier: "onboarding.code",
                    label: "Verification code",
                    hint: onboarding.verifyDevCode.map { "Demo code: \($0)" } ?? "Six digits from the email"
                )
            }
        }
        .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = .code }
        }
    }

    private var doneCard: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                BrandSectionHeader(
                    title: onboarding.activationCodeFromServer == nil ? "Thanks — we’re checking" : "Approved",
                    systemImage: onboarding.activationCodeFromServer == nil ? "clock" : "checkmark.seal",
                    tint: onboarding.activationCodeFromServer == nil ? BrandTheme.statusCaution : BrandTheme.statusPositive,
                    subtitle: onboarding.requestMessage
                )
                if let code = onboarding.activationCodeFromServer {
                    OnboardingCodeTile(code: code, caption: "Your activation code. It works once and expires in 7 days — it has also been emailed to \(onboarding.requestEmail.lowercased()).", identifier: "onboarding.activationCode")
                } else {
                    Text("Once an operator has approved \(onboarding.orgNameDraft), the activation code goes to \(onboarding.requestEmail.lowercased()). Come back to “I have an invite or activation code” to finish.")
                        .font(.footnote)
                        .foregroundStyle(BrandTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))
    }

    private func clearError() {
        guard onboarding.error != nil else { return }
        onboarding.error = nil
    }

    private func submit() {
        focused = nil
        Task { @MainActor in await state.submitOrgRequest() }
    }

    private func verify() {
        Task { @MainActor in
            await state.verifyOrgRequest()
            if state.onboarding.requestStep == .done { CalmExperienceFeedback.signInSuccess() }
        }
    }
}

// MARK: - "I have an invite or activation code"

struct OrgCodeView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            CenteredScrollScreen(
                backAccessibilityLabel: "Back to sign-in",
                onBack: { state.cancelOnboardingEntry() }
            ) {
                VStack(spacing: 22) {
                    FadeInTitle(text: "Join with a code", delay: 0)
                    FadeInLine(
                        text: "Activation codes start with ORG-, staff invites with INV-. Enter the email the code was sent to and choose your PIN.",
                        delay: 0.08
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                    OrgCodeForm(state: state, onboarding: state.onboarding)
                }
                .padding(.vertical, 28)
            }
        }
    }
}

private struct OrgCodeForm: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var onboarding: OnboardingStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var focused: Field?
    private enum Field: Hashable { case email, code, name, pin, confirmPin }

    var body: some View {
        VStack(spacing: SignInPageLayout.stackSpacing) {
            BrandCard {
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingField(title: "Email the code was sent to", text: $onboarding.codeEmail, prompt: "you@willow-care.co.uk", identifier: "onboarding.codeEmail", contentType: .emailAddress, keyboard: .emailAddress, autocapitalises: false, filter: .email)
                        .focused($focused, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focused = .code }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Code").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                        TextField("Code", text: $onboarding.code, prompt: BrandTheme.fieldPrompt("ORG-XXXX-XXXX or INV-XXXX-XXXX"))
                            .accessibilityIdentifier("onboarding.codeField")
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(BrandTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(BrandTheme.creamMid.opacity(0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(BrandTheme.gold.opacity(0.28), lineWidth: 1))
                            .focused($focused, equals: .code)
                            .submitLabel(.next)
                            .onSubmit { focused = .name }
                        if let kind = onboarding.codeKind {
                            BrandStatusChip(
                                text: kind == .activation ? "Organisation activation" : "Staff invite",
                                systemImage: kind == .activation ? "building.columns" : "person.badge.plus",
                                tint: BrandTheme.logoCyan,
                                filled: true
                            )
                        }
                    }

                    if let preview = onboarding.invitePreview {
                        BrandInsetTile(accent: BrandTheme.statusPositive) {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(preview.orgName, systemImage: "building.2")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textPrimary)
                                Text("\(preview.role.onboardingLabel)" + (preview.homeNames.isEmpty ? "" : " · " + preview.homeNames.joined(separator: ", ")))
                                    .font(.footnote)
                                    .foregroundStyle(BrandTheme.textSecondary)
                                if let ends = preview.endsAt {
                                    Text("Temporary cover until \(OnboardingFormat.day(ends))")
                                        .font(.footnote)
                                        .foregroundStyle(BrandTheme.statusCaution)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    OnboardingField(title: onboarding.codeKind == .activation ? "Your name" : "Your name (as the roster shows it)", text: $onboarding.codeDisplayName, prompt: onboarding.invitePreview?.displayName ?? "First and last name", identifier: "onboarding.codeName", contentType: .name, maxLength: 80)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .pin }

                    SixDigitPinInput(
                        pin: $onboarding.codePIN,
                        isError: pinShowsError,
                        focus: $focused,
                        focusValue: Field.pin,
                        onComplete: { focused = .confirmPin },
                        accessibilityIdentifier: "onboarding.codePin",
                        label: "Choose a PIN",
                        hint: "Six digits you’ll remember — never share it"
                    )
                    SixDigitPinInput(
                        pin: $onboarding.codeConfirmPIN,
                        isError: pinShowsError,
                        focus: $focused,
                        focusValue: Field.confirmPin,
                        onComplete: { focused = nil },
                        accessibilityIdentifier: "onboarding.codeConfirmPin",
                        label: "Confirm your PIN",
                        hint: "Enter the same six digits again"
                    )

                    BrandInsetTile {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("How resident data is handled", systemImage: "lock.shield")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandTheme.textPrimary)
                            Text(OnboardingConsent.summary)
                                .font(.footnote)
                                .foregroundStyle(BrandTheme.textSecondary)
                            OnboardingToggleRow(title: "I have read this and will follow it (terms \(OnboardingConsent.termsVersion)).", isOn: $onboarding.acceptedTerms, identifier: "onboarding.terms")
                        }
                    }
                }
            }
            .padding(.horizontal, BrandLayout.contentGutter(for: horizontalSizeClass))

            OnboardingMessages(onboarding: onboarding, errorLabel: "Code error")

            PrimaryButton(title: continueTitle, action: redeem)
                .accessibilityIdentifier("onboarding.redeem")
                .disabled(onboarding.isBusy)
                .padding(.horizontal, 24)
        }
        .fieldFeedback(from: onboarding)
        .onChange(of: onboarding.code) { _, _ in
            clearError()
            Task { @MainActor in await state.previewInviteCode() }
        }
        .onChange(of: onboarding.codeEmail) { _, _ in
            clearError()
            Task { @MainActor in await state.previewInviteCode() }
        }
        .onChange(of: onboarding.codePIN) { _, _ in clearError() }
        .onChange(of: onboarding.codeConfirmPIN) { _, _ in clearError() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if focused == nil {
                    focused = onboarding.codeEmail.isEmpty ? .email : (onboarding.code.isEmpty ? .code : .name)
                }
            }
            Task { @MainActor in await state.previewInviteCode() }
        }
    }

    private var continueTitle: String {
        if onboarding.isBusy { return "Please wait…" }
        switch onboarding.codeKind {
        case .activation: return "Activate the organisation"
        case .invite: return onboarding.invitePreview.map { "Join \($0.orgName)" } ?? "Accept the invite"
        case nil: return "Continue"
        }
    }

    private var pinShowsError: Bool {
        guard let error = onboarding.error, !error.isEmpty else { return false }
        return error.localizedCaseInsensitiveContains("pin")
    }

    private func clearError() {
        guard onboarding.error != nil else { return }
        onboarding.error = nil
    }

    private func redeem() {
        focused = nil
        Task { @MainActor in
            await state.redeemCode()
            if state.isSignedIn { CalmExperienceFeedback.signInSuccess() }
        }
    }
}

// MARK: - Shared pieces

/// A highlighted note that stands on its own over the orb. Inset tiles are built for sitting inside a
/// card; out here their near-transparent fill let the orb's gradient wash the text out, so a callout is
/// a full card with an accent edge instead.
struct OnboardingCallout<Content: View>: View {
    var accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        BrandCard(content: content)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent.opacity(0.75), lineWidth: 1.5)
            )
    }
}

/// What is wrong with each field, by accessibility identifier, and how a field clears its own message
/// once the person starts correcting it. Set once per screen; `OnboardingField` reads it.
struct FieldFeedback {
    var errors: [String: String] = [:]
    var clear: (String) -> Void = { _ in }
}

private struct FieldFeedbackKey: EnvironmentKey {
    static let defaultValue = FieldFeedback()
}

extension EnvironmentValues {
    var fieldFeedback: FieldFeedback {
        get { self[FieldFeedbackKey.self] }
        set { self[FieldFeedbackKey.self] = newValue }
    }
}

extension View {
    /// Lets the `OnboardingField`s inside show `store.fieldErrors` under themselves.
    func fieldFeedback(from store: OnboardingStore) -> some View {
        environment(\.fieldFeedback, FieldFeedback(errors: store.fieldErrors) { id in
            if store.fieldErrors[id] != nil { store.fieldErrors[id] = nil }
        })
    }
}

struct OnboardingField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let identifier: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var autocapitalises: Bool = true
    var axis: Axis = .horizontal
    /// Characters that can never be right are dropped as they are typed or pasted.
    var filter: InputFilter? = nil
    var maxLength: Int? = nil
    /// Off when a parent lays the message out itself (a field beside its button).
    var showsError = true

    @Environment(\.fieldFeedback) private var feedback

    /// Single-line fields and the buttons beside them share this content height (plus 24pt of padding).
    static let contentMinHeight: CGFloat = 24

    private var errorMessage: String? { feedback.errors[identifier] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandTheme.textSecondary)
            TextField(title, text: $text, prompt: BrandTheme.fieldPrompt(prompt), axis: axis)
                .accessibilityIdentifier(identifier)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalises ? .words : .never)
                .autocorrectionDisabled(!autocapitalises)
                .lineLimit(axis == .vertical ? 2 ... 6 : 1 ... 1)
                .font(.body)
                .foregroundStyle(BrandTheme.textPrimary)
                .frame(minHeight: OnboardingField.contentMinHeight)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(BrandTheme.creamMid.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(errorMessage == nil ? BrandTheme.gold.opacity(0.28) : BrandTheme.statusAttention, lineWidth: errorMessage == nil ? 1 : 2)
                )
                .onChange(of: text) { _, new in
                    var cleaned = InputFilter.withoutMarkup(new, allowsLineBreaks: axis == .vertical)
                    cleaned = filter?.apply(cleaned) ?? cleaned
                    if let maxLength, cleaned.count > maxLength { cleaned = String(cleaned.prefix(maxLength)) }
                    if cleaned != new { text = cleaned }
                    feedback.clear(identifier)
                }
            if showsError, let errorMessage { FieldErrorLabel(message: errorMessage, identifier: identifier) }
        }
    }
}

/// The message under a field: icon plus words, never colour alone.
struct FieldErrorLabel: View {
    let message: String
    let identifier: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(BrandTheme.statusAttention)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("\(identifier).error")
    }
}

/// A text field with its action button: side by side where there is room, stacked on a phone so
/// neither is squeezed and the button is a full-width target under the field.
struct OnboardingFieldWithAction: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let identifier: String
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var autocapitalises: Bool = true
    var filter: InputFilter? = nil
    var maxLength: Int? = nil
    let buttonTitle: String
    let buttonIdentifier: String
    var onSubmit: (() -> Void)? = nil
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.fieldFeedback) private var feedback

    var body: some View {
        let field = OnboardingField(title: title, text: $text, prompt: prompt, identifier: identifier, contentType: contentType, keyboard: keyboard, autocapitalises: autocapitalises, filter: filter, maxLength: maxLength, showsError: false)
        let button = SecondaryButton(title: buttonTitle, minContentHeight: OnboardingField.contentMinHeight, action: action)
            .accessibilityIdentifier(buttonIdentifier)
        let error = feedback.errors[identifier]
        VStack(alignment: .leading, spacing: 8) {
            if horizontalSizeClass == .compact {
                // Field, then why it was refused, then the button: the message stays with the field.
                field.onSubmit { onSubmit?() }
                if let error { FieldErrorLabel(message: error, identifier: identifier) }
                button
            } else {
                HStack(alignment: .bottom, spacing: 12) {
                    field.onSubmit { onSubmit?() }
                    button.frame(maxWidth: 180)
                }
                if let error { FieldErrorLabel(message: error, identifier: identifier) }
            }
        }
    }
}

struct OnboardingToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let identifier: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isOn ? BrandTheme.statusPositive : BrandTheme.textSecondary)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 2)
            .expandedHitArea(vertical: 8)   // a 44pt target without 44pt of empty space in the card
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "Ticked" : "Not ticked")
    }
}

struct OnboardingMessages: View {
    @ObservedObject var onboarding: OnboardingStore
    let errorLabel: String

    var body: some View {
        if let error = onboarding.error, !error.isEmpty {
            Text(error)
                .font(.footnote)
                .foregroundStyle(BrandTheme.nebulaSalmon)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .accessibilityLabel(errorLabel)
                .accessibilityValue(error)
                .accessibilityIdentifier("onboarding.error")
        }
        if let notice = onboarding.notice, !notice.isEmpty {
            Label(notice, systemImage: "checkmark.circle")
                .font(.footnote.weight(.medium))
                .foregroundStyle(BrandTheme.statusPositive)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .accessibilityIdentifier("onboarding.notice")
        }
    }
}

struct OnboardingCodeTile: View {
    let code: String
    let caption: String
    var identifier: String = "onboarding.codeTile"

    var body: some View {
        BrandInsetTile(accent: BrandTheme.gold) {
            VStack(alignment: .leading, spacing: 6) {
                Text(code)
                    .font(.system(.title2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(BrandTheme.textPrimary)
                    .textSelection(.enabled)
                    .accessibilityIdentifier(identifier)
                    .accessibilityLabel("Code \(code.map(String.init).joined(separator: " "))")
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingActionLink: View {
    let title: String
    var tint: Color = BrandTheme.gold
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .expandedHitArea(vertical: 12, horizontal: 10)
        }
        .buttonStyle(ChimingPlainButtonStyle())
    }
}

struct OnboardingStatusChip: View {
    let status: String

    var body: some View {
        switch status {
        case "active", "accepted", "verified":
            BrandStatusChip(text: status == "accepted" ? "Accepted" : status == "verified" ? "Verified" : "Active", systemImage: "checkmark.circle", tint: BrandTheme.statusPositive)
        case "pending", "settingUp":
            BrandStatusChip(text: status == "pending" ? "Pending" : "Setting up", systemImage: "hourglass", tint: BrandTheme.statusCaution)
        case "suspended", "expired":
            BrandStatusChip(text: status == "expired" ? "Expired" : "Suspended", systemImage: "pause.circle", tint: BrandTheme.statusAttention)
        case "archived", "revoked", "removed":
            BrandStatusChip(text: status.capitalized, systemImage: "archivebox", tint: BrandTheme.textSecondary)
        default:
            BrandStatusChip(text: status.capitalized, tint: BrandTheme.textSecondary)
        }
    }
}

// MARK: - Admin dashboard: set-up progress card (org admins, backend only)

/// Sits on the home admin dashboard until the checklist is complete, then collapses to one line.
/// Observes the onboarding store directly so the dashboard does not re-render on its loads.
struct OrgSetupDashboardCard: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var onboarding: OnboardingStore

    var body: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                if let payload = onboarding.organisation {
                    let checklist = payload.checklist
                    if checklist.complete {
                        HStack(spacing: 10) {
                            BrandSectionHeader(title: "Set-up complete", systemImage: "checkmark.seal", tint: BrandTheme.statusPositive, subtitle: "\(payload.organisation.name) · organisation since \(OnboardingFormat.day(payload.organisation.createdAt))")
                            Spacer(minLength: 8)
                            OnboardingActionLink(title: "Open") { state.openOrgSetup(resume: true) }
                                .accessibilityIdentifier("admin.orgSetup")
                        }
                    } else {
                        BrandSectionHeader(title: "Organisation set-up", systemImage: "building.columns", subtitle: "Finish the lines marked to do — nothing blocks a session.")
                        InsightChipFlow(spacing: 8) {
                            chip("\(checklist.homes) home\(checklist.homes == 1 ? "" : "s")", done: checklist.homes > 0)
                            chip("\(checklist.staffActive) staff · \(checklist.invitesPending) invited", done: onboarding.isSectionDone(.team))
                            chip("\(checklist.residents) residents", done: checklist.residents > 0)
                            chip("\(checklist.devices) iPad\(checklist.devices == 1 ? "" : "s")", done: checklist.devices > 0)
                        }
                        SecondaryButton(title: "Continue set-up") { state.openOrgSetup(resume: true) }
                            .accessibilityIdentifier("admin.orgSetup")
                    }
                } else {
                    BrandSectionHeader(title: "Organisation set-up", systemImage: "building.columns", subtitle: "Homes, team invites, resident import, iPads and the audit trail.")
                    SecondaryButton(title: "Open organisation set-up") { state.openOrgSetup(resume: true) }
                        .accessibilityIdentifier("admin.orgSetup")
                }
            }
        }
        .onAppear {
            if onboarding.organisation == nil, !onboarding.isBusy {
                Task { @MainActor in await state.loadOrganisation() }
            }
        }
    }

    private func chip(_ text: String, done: Bool) -> some View {
        BrandStatusChip(text: text, systemImage: done ? "checkmark.circle" : "circle", tint: done ? BrandTheme.statusPositive : BrandTheme.statusCaution)
    }
}
