import SwiftUI
import UniformTypeIdentifiers

// MARK: - Organisation set-up wizard
//
// Eighteen short pages in six sections (see `OnboardingStore.SetupPage`). Each page is one task, so
// nothing needs a long scroll and nothing is easy to skip past. Phone-first: a compact stepper, a page
// title, the page, and one pinned bar with the previous page as a quiet text button and a single
// primary action named for where it goes.

struct OrgSetupView: View {
    @ObservedObject var state: SessionPOCState

    var body: some View {
        ScreenFadeIn {
            OrgSetupContent(state: state, onboarding: state.onboarding)
        }
        .onAppear {
            if !state.isSignedIn { state.phase = .home }
        }
    }
}

private struct OrgSetupContent: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var onboarding: OnboardingStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// While the keyboard is up on a phone the bar gives its room back (see `stepBar`).
    @State private var keyboardVisible = false

    /// Admin screens are designed phone-first: tighter rhythm on a compact width, then the same
    /// layout opens up on the iPad.
    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var barShowsButtons: Bool { !(isCompact && keyboardVisible) }
    private var barHasMessage: Bool { onboarding.error != nil || onboarding.notice != nil }
    private var canExit: Bool { !state.assignedHomes().isEmpty }

    /// Top-left leaves the wizard and says where it goes; moving between pages lives in the bottom bar,
    /// so the two never share a label.
    private var exitTitle: String { state.currentHomeId == nil ? "Home list" : "Dashboard" }

    var body: some View {
        CenteredScrollScreen(
            backTitle: exitTitle,
            backAccessibilityLabel: state.currentHomeId == nil ? "Leave set-up and go to home selection" : "Leave set-up and go to the dashboard",
            onBack: canExit ? { state.requestSetupNavigation(.exit) } : nil,
            onLogout: { state.signOutSupervisor() },
            topAligned: true
        ) {
            VStack(spacing: isCompact ? 14 : 22) {
                stepper
                pageHeader
                OrgSetupPageBody(state: state, onboarding: onboarding)
                    .fieldFeedback(from: onboarding)
            }
            .padding(.vertical, isCompact ? 10 : 20)
        }
        // A new page starts at the top instead of inheriting the last page's scroll offset.
        .id(onboarding.page)
        .scrollDismissesKeyboard(.interactively)
        // Room under the field being edited: the system scrolls a focused field to the keyboard's edge,
        // which here also sits under the page's bottom fade.
        .contentMargins(.bottom, keyboardVisible ? 56 : 0, for: .scrollContent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if barShowsButtons || barHasMessage { stepBar }
        }
        .toolbar {
            // "Done" rides on the keyboard itself, so on a phone the bar can step aside while typing.
            // The iPad keeps its bar on screen, and the pill would only float beside it.
            if isCompact {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .accessibilityIdentifier("onboarding.keyboardDone")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .alert(
            onboarding.pendingLeave?.title ?? "",
            isPresented: Binding(
                get: { onboarding.pendingLeave != nil },
                set: { if !$0 { onboarding.pendingLeave = nil } }
            ),
            presenting: onboarding.pendingLeave
        ) { pending in
            Button(pending.saveLabel) { Task { @MainActor in await state.resolvePendingLeave(pending, save: true) } }
            Button("Discard", role: .destructive) { Task { @MainActor in await state.resolvePendingLeave(pending, save: false) } }
            Button("Keep editing", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
        }
    }

    // MARK: Stepper and header

    /// Six circles, one per section: a tick when the section is done, the filled ring where you are.
    private var stepper: some View {
        HStack(spacing: 0) {
            ForEach(OnboardingStore.SetupSection.allCases) { section in
                SetupSectionDot(
                    section: section,
                    isCurrent: section == onboarding.section,
                    isDone: isDone(section)
                ) {
                    state.requestSetupNavigation(.page(section.firstPage))
                }
                if section != OnboardingStore.SetupSection.allCases.last {
                    Capsule(style: .continuous)
                        .fill(isDone(section) ? BrandTheme.statusPositive.opacity(0.7) : BrandTheme.hairline)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Set-up sections")
    }

    /// The server's checklist, plus the residents already on this iPad's roster (an import reaches the
    /// server a moment after it lands on the roster, and the tick should not lag behind what was just done).
    private func isDone(_ section: OnboardingStore.SetupSection) -> Bool {
        if onboarding.isSectionDone(section) { return true }
        guard section == .residents else { return false }
        let homeIds = Set(onboarding.liveHomes.compactMap { UUID(uuidString: $0.id) })
        return state.carePatients.contains { homeIds.contains($0.homeId) && $0.isActive && !$0.isProvisional }
    }

    private var caption: String {
        if onboarding.page == .homesOverview, onboarding.liveHomes.isEmpty { return "Start by adding your first home." }
        return onboarding.page.caption
    }

    /// Plain text rather than the fade-in lines: the page is rebuilt on every change and a re-fading
    /// title would flicker each time.
    private var pageHeader: some View {
        VStack(spacing: isCompact ? 5 : 8) {
            Text(onboarding.pageEyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .orbOverlayText(muted: true)
                .multilineTextAlignment(.center)
            Text(onboarding.page.title)
                .font(BrandTheme.orbTitleFont(isCompact ? .title2 : .title))
                .tracking(1)
                .orbOverlayText()
                .multilineTextAlignment(.center)
            Text(caption)
                .font(.footnote)
                .orbOverlayText(muted: true)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Bar

    private struct Primary {
        var title: String
        var identifier: String
        var label: String?
        var isEnabled = true
        var action: () -> Void
    }

    /// The one primary action of the page: the commit on a detour's last page, otherwise the way on.
    private var primary: Primary {
        let page = onboarding.page
        switch page {
        case .homeLead:
            return Primary(title: onboarding.isBusy ? "Adding…" : "Add home", identifier: "onboarding.addHome", isEnabled: !onboarding.isBusy) {
                Task { @MainActor in await state.commitSetupDetour() }
            }
        case .inviteAccess:
            return Primary(title: onboarding.isBusy ? "Sending…" : "Send invite", identifier: "onboarding.invite.send", isEnabled: !onboarding.isBusy) {
                Task { @MainActor in await state.commitSetupDetour() }
            }
        case .inviteBulk:
            return Primary(title: onboarding.isBusy ? "Sending…" : "Send all", identifier: "onboarding.invite.sendAll", isEnabled: !onboarding.isBusy) {
                Task { @MainActor in await state.commitSetupDetour() }
            }
        case .residentsReview:
            let count = onboarding.importPreview?.validRows.count ?? 0
            return Primary(title: "Import \(count) resident\(count == 1 ? "" : "s")", identifier: "onboarding.import.apply", isEnabled: count > 0) {
                Task { @MainActor in await state.commitSetupDetour() }
            }
        case .homesOverview where onboarding.liveHomes.isEmpty:
            return Primary(title: "Add your first home", identifier: "onboarding.addHome.start") {
                state.startSetupDetour(.addHome)
            }
        default:
            if let next = onboarding.nextPage(of: page) {
                return Primary(title: "Next: \(next.shortTitle)", identifier: "onboarding.next", label: "Continue to \(next.title)") {
                    Task { @MainActor in await state.advanceSetup() }
                }
            }
            return Primary(title: "Finish set-up", identifier: "onboarding.done") {
                state.requestSetupNavigation(.finish)
            }
        }
    }

    /// One pinned bar: feedback on top (next to the buttons the admin just used), then the previous
    /// page as a quiet text button and the single primary action, each named for where it goes.
    private var stepBar: some View {
        VStack(spacing: 10) {
            SetupBanner(onboarding: onboarding)
            if barShowsButtons {
                HStack(spacing: 12) {
                    if let previous = onboarding.previousPage(of: onboarding.page) {
                        Button {
                            state.requestSetupNavigation(.page(previous))
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.footnote.weight(.bold))
                                Text(previous.shortTitle).font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(BrandTheme.gold)
                            .padding(.trailing, 6)
                            .frame(minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(ChimingPlainButtonStyle())
                        .accessibilityIdentifier("onboarding.back")
                        .accessibilityLabel("Back to \(previous.title)")
                    }
                    let primary = primary
                    PrimaryButton(title: primary.title, action: primary.action)
                        .accessibilityIdentifier(primary.identifier)
                        .accessibilityLabel(primary.label ?? primary.title)
                        .disabled(!primary.isEnabled)
                        .opacity(primary.isEnabled ? 1 : 0.6)
                }
            }
        }
        .frame(maxWidth: BrandLayout.menuColumnMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 6)
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

/// One stop in the stepper. Words and an icon, never colour alone: a ticked circle is a finished
/// section, the filled ring with its icon is where you are, the rest show their icon quietly.
private struct SetupSectionDot: View {
    let section: OnboardingStore.SetupSection
    let isCurrent: Bool
    let isDone: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isCurrent ? BrandTheme.logoCyan.opacity(0.30) : (isDone ? BrandTheme.statusPositive.opacity(0.22) : BrandTheme.surfaceInset))
                Circle()
                    .stroke(isCurrent ? BrandTheme.logoCyan : (isDone ? BrandTheme.statusPositive : BrandTheme.insetBorder), lineWidth: isCurrent ? 2.5 : 1.5)
                Image(systemName: isDone && !isCurrent ? "checkmark" : section.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDone && !isCurrent ? BrandTheme.statusPositive : BrandTheme.textPrimary.opacity(isCurrent ? 1 : 0.8))
            }
            .frame(width: 38, height: 38)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChimingPlainButtonStyle())
        .accessibilityIdentifier("onboarding.section.\(section.number)")
        .accessibilityLabel("\(section.title), section \(section.number) of \(OnboardingStore.SetupSection.allCases.count)\(isDone ? ", done" : "")")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// Feedback for the wizard, sitting right above the buttons so it is on screen wherever the page is
/// scrolled and never shoves the content around. Notices clear themselves; an error stays until the
/// admin dismisses it, edits something or acts again.
struct SetupBanner: View {
    @ObservedObject var onboarding: OnboardingStore

    private var message: (text: String, isError: Bool)? {
        if let error = onboarding.error, !error.isEmpty { return (error, true) }
        if let notice = onboarding.notice, !notice.isEmpty { return (notice, false) }
        return nil
    }

    var body: some View {
        Group {
            if let message {
                let tint = message.isError ? BrandTheme.statusAttention : BrandTheme.statusPositive
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Text(message.text)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BrandTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        onboarding.error = nil
                        onboarding.notice = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(BrandTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ChimingPlainButtonStyle())
                    .accessibilityLabel("Dismiss message")
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(BrandTheme.surfaceInset)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.85), lineWidth: 1.5)
                )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(message.isError ? "onboarding.error" : "onboarding.notice")
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: onboarding.error)
        .animation(.easeOut(duration: 0.2), value: onboarding.notice)
        .onChange(of: onboarding.error) { _, text in
            if let text, !text.isEmpty { UIAccessibility.post(notification: .announcement, argument: text) }
        }
        .onChange(of: onboarding.notice) { _, text in
            if let text, !text.isEmpty { UIAccessibility.post(notification: .announcement, argument: text) }
        }
        .task(id: onboarding.notice) {
            guard let current = onboarding.notice, !current.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if onboarding.notice == current { onboarding.notice = nil }
        }
    }
}


// MARK: - The pages

/// One short page per task. Each is a card or two, sized for a phone; the container supplies the title.
private struct OrgSetupPageBody: View {
    @ObservedObject var state: SessionPOCState
    @ObservedObject var onboarding: OnboardingStore
    @State private var showsImporter = false
    @State private var templateCopied = false

    private let yesNo = [BrandChoiceOption(value: true, label: "Yes"), BrandChoiceOption(value: false, label: "No")]
    private let leadOptions = [BrandChoiceOption(value: true, label: "That’s me"), BrandChoiceOption(value: false, label: "Invite someone")]
    private var idleOptions: [BrandChoiceOption<Int>] {
        [BrandChoiceOption(value: 0, label: "Off"), BrandChoiceOption(value: 5, label: "5 min"), BrandChoiceOption(value: 10, label: "10 min"), BrandChoiceOption(value: 20, label: "20 min")]
    }
    private var retentionOptions: [BrandChoiceOption<Int>] {
        [BrandChoiceOption(value: 365, label: "1 year"), BrandChoiceOption(value: 730, label: "2 years"), BrandChoiceOption(value: 1095, label: "3 years")]
    }
    private var roleOptions: [BrandChoiceOption<SupervisorRole>] {
        [BrandChoiceOption(value: .supervisor, label: "Supervisor"), BrandChoiceOption(value: .homeLead, label: "Home lead"), BrandChoiceOption(value: .orgAdmin, label: "Org admin")]
    }

    @ViewBuilder
    var body: some View {
        switch onboarding.page {
        case .orgDetails: orgDetails
        case .orgAddress: orgAddress
        case .orgDomains: orgDomains
        case .orgDefaults: orgDefaults
        case .homesOverview: homesOverview
        case .homeDetails: homeDetails
        case .homeAddress: homeAddress
        case .homeWings: homeWings
        case .homeLead: homeLead
        case .teamOverview: teamOverview
        case .inviteWho: inviteWho
        case .inviteAccess: inviteAccess
        case .inviteBulk: inviteBulk
        case .residentsImport: residentsImport
        case .residentsReview: residentsReview
        case .ipadGuidance: ipadGuidance
        case .ipadRegister: ipadRegister
        case .readyChecklist: readyChecklist
        case .readyAudit: readyAudit
        }
    }

    // MARK: Organisation

    private var orgDetails: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingField(title: "Name", text: $onboarding.orgName, prompt: "Willow Care Group", identifier: "onboarding.org.name", contentType: .organizationName, maxLength: 120)
                OnboardingField(title: "Trading name (optional)", text: $onboarding.tradingName, prompt: "Willow Care", identifier: "onboarding.org.trading", maxLength: 120)
                OnboardingField(title: "CQC provider ID (optional)", text: $onboarding.cqcProviderId, prompt: "1-123456789", identifier: "onboarding.org.cqc", keyboard: .numbersAndPunctuation, autocapitalises: false, filter: .cqcId)
            }
        }
    }

    private var orgAddress: some View {
        VStack(spacing: 16) {
            BrandCard {
                VStack(alignment: .leading, spacing: 16) {
                    OnboardingField(title: "Address", text: $onboarding.addressLine1, prompt: "1 Willow Street", identifier: "onboarding.org.address", contentType: .streetAddressLine1, maxLength: 120)
                    HStack(alignment: .top, spacing: 12) {
                        OnboardingField(title: "Town", text: $onboarding.addressTown, prompt: "Stockport", identifier: "onboarding.org.town", contentType: .addressCity, maxLength: 60)
                        OnboardingField(title: "Postcode", text: $onboarding.addressPostcode, prompt: "SK1 1AA", identifier: "onboarding.org.postcode", contentType: .postalCode, autocapitalises: false, filter: .postcode)
                            .frame(maxWidth: 160)
                    }
                    VStack(spacing: 0) {
                        BrandKeyValueRow(label: "Data region", value: "United Kingdom")
                        BrandKeyValueRow(label: "Plan", value: planLine, isLast: true)
                    }
                }
            }
            OnboardingCallout(accent: BrandTheme.logoLavenderBlue) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("What is stored, and where", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                    Text(OnboardingConsent.summary)
                        .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var planLine: String {
        guard let org = onboarding.organisation?.organisation else { return "—" }
        let plan = org.plan == "trial" ? "Trial" : org.plan.capitalized
        if let ends = org.trialEndsAt, org.plan == "trial" { return "\(plan) · ends \(OnboardingFormat.day(ends))" }
        if let seats = org.seatsPerHome { return "\(plan) · \(seats) seats per home" }
        return plan
    }

    private var orgDomains: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                if let payload = onboarding.organisation {
                    ForEach(Array(payload.domains.enumerated()), id: \.element.id) { index, domain in
                        if index > 0 { BrandHairline() }
                        HStack(spacing: 10) {
                            Text(domain.domain).font(.subheadline.weight(.medium)).foregroundStyle(BrandTheme.textPrimary)
                            Spacer(minLength: 8)
                            BrandStatusChip(text: "Verified", systemImage: "checkmark.seal", tint: BrandTheme.statusPositive)
                            OnboardingActionLink(title: "Remove", tint: BrandTheme.statusAttention) {
                                Task { @MainActor in await state.removeDomain(domain.domain) }
                            }
                        }
                    }
                    ForEach(Array(payload.pendingDomains.enumerated()), id: \.element.id) { index, pending in
                        if index > 0 || !payload.domains.isEmpty { BrandHairline() }
                        HStack(spacing: 10) {
                            Text(pending.domain).font(.subheadline.weight(.medium)).foregroundStyle(BrandTheme.textPrimary)
                            Spacer(minLength: 8)
                            BrandStatusChip(
                                text: pending.method == "dns" ? "Awaiting DNS" : "Awaiting code",
                                systemImage: pending.method == "dns" ? "globe" : "envelope",
                                tint: BrandTheme.statusCaution
                            )
                            OnboardingActionLink(title: pending.method == "dns" ? "Show record" : "Enter code") {
                                state.resumeDomainClaim(pending)
                            }
                        }
                    }
                    if payload.domains.isEmpty, payload.pendingDomains.isEmpty {
                        Text("No domain yet. Requests from free-mail addresses need the work domain confirmed here.")
                            .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let pending = onboarding.pendingDomain {
                    BrandInsetTile(accent: BrandTheme.statusCaution) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let record = onboarding.pendingDomainRecord {
                                Text("Add this TXT record at your DNS provider for \(pending), then check. The token is meant to be public.")
                                    .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                VStack(spacing: 0) {
                                    BrandKeyValueRow(label: "Name", value: record.name)
                                    BrandKeyValueRow(label: "Type", value: record.type)
                                    BrandKeyValueRow(label: "Value", value: record.value, isLast: true)
                                }
                                .font(.system(.footnote, design: .monospaced))
                                HStack(spacing: 18) {
                                    OnboardingActionLink(title: "Copy value") {
                                        UIPasteboard.general.string = record.value
                                        onboarding.notice = "Record value copied."
                                    }
                                    OnboardingActionLink(title: "Copy name") {
                                        UIPasteboard.general.string = record.name
                                        onboarding.notice = "Record name copied."
                                    }
                                }
                                SecondaryButton(title: onboarding.isBusy ? "Checking…" : "Check DNS") {
                                    Task { @MainActor in await state.verifyDomain() }
                                }
                                .accessibilityIdentifier("onboarding.domain.checkDns")
                                .disabled(onboarding.isBusy)
                            } else {
                                Text("Code emailed to postmaster@\(pending) and admin@\(pending)" + (onboarding.domainDevCode.map { " · Demo code: \($0)" } ?? ""))
                                    .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                OnboardingFieldWithAction(
                                    title: "Six-digit code", text: $onboarding.domainCode, prompt: "000000",
                                    identifier: "onboarding.domain.code", keyboard: .numberPad, autocapitalises: false, filter: .digits(max: 6),
                                    buttonTitle: "Verify", buttonIdentifier: "onboarding.domain.verify"
                                ) {
                                    Task { @MainActor in await state.verifyDomain() }
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to prove a domain").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                    BrandSegmentedChoice(
                        title: "How to prove a domain",
                        selection: $onboarding.domainMethod,
                        options: DomainClaimMethod.allCases.map { BrandChoiceOption(value: $0, label: $0.label) }
                    )
                    .accessibilityIdentifier("onboarding.domain.method")
                    Text(onboarding.domainMethod == .email
                         ? "A six-digit code goes to postmaster@ and admin@ at that domain."
                         : "You publish a TXT record at _notestalgia.<domain>; the record stays as proof.")
                        .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                OnboardingFieldWithAction(
                    title: "Add a domain", text: $onboarding.newDomain, prompt: "willow-care.co.uk",
                    identifier: "onboarding.domain.new", keyboard: .URL, autocapitalises: false, filter: .domain,
                    buttonTitle: onboarding.domainMethod == .email ? "Send code" : "Get record",
                    buttonIdentifier: "onboarding.domain.send"
                ) {
                    Task { @MainActor in await state.claimDomain() }
                }
            }
        }
    }

    private var orgDefaults: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                settingRow("PIN re-prompt on shared iPads", "After this long idle, the next person signs in again.") {
                    BrandSegmentedChoice(title: "PIN re-prompt on shared iPads", selection: $onboarding.settings.idlePinMinutes, options: idleOptions)
                }
                settingRow("Home leads may invite staff", nil) {
                    BrandSegmentedChoice(title: "Home leads may invite staff", selection: $onboarding.settings.homeLeadsMayInvite, options: yesNo)
                }
                settingRow("Supervisors may add residents", nil) {
                    BrandSegmentedChoice(title: "Supervisors may add residents", selection: $onboarding.settings.supervisorsMayAddResidents, options: yesNo)
                }
                settingRow("Keep session records for", "Older records are deleted; residents’ preferences are kept while they are on the roster.") {
                    BrandSegmentedChoice(title: "Keep session records for", selection: $onboarding.settings.retentionDays, options: retentionOptions)
                }
            }
        }
    }

    private func settingRow(_ title: String, _ subtitle: String?, @ViewBuilder control: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
            control()
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Homes

    @ViewBuilder
    private var homesOverview: some View {
        if onboarding.liveHomes.isEmpty {
            BrandCard {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 34))
                        .foregroundStyle(BrandTheme.logoCyan)
                        .accessibilityHidden(true)
                    Text("No homes yet")
                        .font(.headline).foregroundStyle(BrandTheme.textPrimary)
                    Text("Adding a home takes three short pages: its name, its wings, and who leads it.")
                        .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                    OnboardingActionLink(title: "Skip for now") {
                        Task { @MainActor in await state.advanceSetup() }
                    }
                    .accessibilityIdentifier("onboarding.homes.skip")
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            ForEach(onboarding.homes) { home in homeCard(home) }
            SecondaryButton(title: "Add another home") { state.startSetupDetour(.addHome) }
                .accessibilityIdentifier("onboarding.home.addAnother")
        }
    }

    private func homeCard(_ home: OrgHome) -> some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    BrandSectionHeader(title: home.name, systemImage: "building.2")
                    Spacer(minLength: 8)
                    OnboardingStatusChip(status: home.status)
                }
                InsightChipFlow(spacing: 8) {
                    ForEach(home.wings, id: \.id) { wing in
                        BrandStatusChip(text: wing.name, systemImage: "door.left.hand.open", tint: BrandTheme.logoCyan)
                    }
                }
                VStack(spacing: 0) {
                    BrandKeyValueRow(label: "Residents", value: "\(home.residentCount)")
                    BrandKeyValueRow(label: "Staff with access", value: "\(home.staffCount)")
                    BrandKeyValueRow(label: "Address", value: OnboardingFormat.address(home.address))
                    BrandKeyValueRow(label: "CQC location", value: home.cqcLocationId ?? "—")
                    BrandKeyValueRow(label: "Capacity", value: home.capacity.map { "\($0) beds" } ?? "—", isLast: true)
                }
                BrandHairline()
                Text("Export")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandTheme.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                InsightChipFlow(spacing: 18) {
                    OnboardingActionLink(title: onboarding.exportingHomeId == home.id ? "Exporting…" : "Residents (CSV)") {
                        Task { @MainActor in await state.exportHome(home, format: "csv", kind: "residents") }
                    }
                    .accessibilityIdentifier("onboarding.export.residents.\(home.name)")
                    OnboardingActionLink(title: "Sessions (CSV)") {
                        Task { @MainActor in await state.exportHome(home, format: "csv", kind: "sessions") }
                    }
                    OnboardingActionLink(title: "Everything (JSON)") {
                        Task { @MainActor in await state.exportHome(home, format: "json", kind: "residents") }
                    }
                    .accessibilityIdentifier("onboarding.export.json.\(home.name)")
                }
                .disabled(onboarding.isBusy)
                if let file = onboarding.exportFile, file.homeName == home.name {
                    BrandInsetTile(accent: BrandTheme.statusPositive) {
                        HStack(spacing: 12) {
                            ShareLink(item: file.url) {
                                Label("Share \(file.url.lastPathComponent)", systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BrandTheme.textPrimary)
                            }
                            .accessibilityIdentifier("onboarding.export.share")
                            Spacer(minLength: 8)
                            OnboardingActionLink(title: "Done") { state.clearExport() }
                        }
                    }
                }
                if home.status != "archived", home.residentCount == 0 {
                    BrandHairline()
                    OnboardingActionLink(title: "Archive this home", tint: BrandTheme.statusAttention) {
                        Task { @MainActor in await state.archiveHome(home) }
                    }
                }
            }
        }
    }

    private var homeDetails: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingField(title: "Home name", text: $onboarding.homeName, prompt: "Willow Lodge", identifier: "onboarding.home.name", contentType: .organizationName, maxLength: 80)
                OnboardingField(title: "CQC location ID (optional)", text: $onboarding.homeCqc, prompt: "1-987654321", identifier: "onboarding.home.cqc", keyboard: .numbersAndPunctuation, autocapitalises: false, filter: .cqcId)
                OnboardingField(title: "Beds (optional)", text: $onboarding.homeCapacity, prompt: "40", identifier: "onboarding.home.capacity", keyboard: .numberPad, autocapitalises: false, filter: .digits(max: 4))
            }
        }
    }

    private var homeAddress: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingField(title: "Address", text: $onboarding.homeAddressLine1, prompt: "1 Willow Street", identifier: "onboarding.home.address", contentType: .streetAddressLine1, maxLength: 120)
                HStack(alignment: .top, spacing: 12) {
                    OnboardingField(title: "Town", text: $onboarding.homeAddressTown, prompt: "Stockport", identifier: "onboarding.home.town", contentType: .addressCity, maxLength: 60)
                    OnboardingField(title: "Postcode", text: $onboarding.homeAddressPostcode, prompt: "SK1 1AA", identifier: "onboarding.home.postcode", contentType: .postalCode, autocapitalises: false, filter: .postcode)
                        .frame(maxWidth: 160)
                }
                if onboarding.storedAddressIsComplete {
                    OnboardingActionLink(title: "Use the head-office address") { onboarding.useOrganisationAddressForHome() }
                        .accessibilityIdentifier("onboarding.home.useOfficeAddress")
                }
            }
        }
    }

    private var homeWings: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tap a wing to remove it").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                InsightChipFlow(spacing: 8) {
                    ForEach(onboarding.homeWings, id: \.self) { wing in
                        Button {
                            onboarding.homeWings.removeAll { $0 == wing }
                        } label: {
                            HStack(spacing: 6) {
                                Text(wing)
                                Image(systemName: "xmark").font(.caption2.weight(.bold))
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(BrandTheme.logoCyan.opacity(0.18)))
                            .overlay(Capsule().stroke(BrandTheme.logoCyan.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(ChimingPlainButtonStyle())
                        .accessibilityLabel("Remove wing \(wing)")
                    }
                }
                OnboardingFieldWithAction(
                    title: "Add a wing", text: $onboarding.newWing, prompt: "Garden suite",
                    identifier: "onboarding.home.newWing", maxLength: 40,
                    buttonTitle: "Add wing", buttonIdentifier: "onboarding.home.addWing",
                    onSubmit: { state.addWingToDraft() }
                ) { state.addWingToDraft() }
            }
        }
    }

    private var homeLead: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                BrandSegmentedChoice(title: "Home lead", selection: $onboarding.homeLeadIsMe, options: leadOptions)
                    .accessibilityIdentifier("onboarding.home.lead")
                    .chimeOnChange(of: onboarding.homeLeadIsMe)
                if onboarding.homeLeadIsMe {
                    Text("You’ll lead \(onboarding.homeName.isEmpty ? "this home" : onboarding.homeName) yourself and can invite its supervisors next.")
                        .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    OnboardingField(title: "Home lead’s work email", text: $onboarding.homeLeadEmail, prompt: "lead@willow-care.co.uk", identifier: "onboarding.home.leadEmail", contentType: .emailAddress, keyboard: .emailAddress, autocapitalises: false, filter: .email)
                    OnboardingField(title: "Their name (optional)", text: $onboarding.homeLeadName, prompt: "Lee Morgan", identifier: "onboarding.home.leadName", contentType: .name, maxLength: 80)
                    Text("They get an INV- code by email, choose their own PIN and land on this home’s dashboard.")
                        .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Team

    @ViewBuilder
    private var teamOverview: some View {
        if onboarding.liveHomes.isEmpty {
            OnboardingCallout(accent: BrandTheme.statusCaution) {
                Label("Add a home first — invites are scoped to homes.", systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(BrandTheme.textPrimary)
            }
        }

        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                BrandSectionHeader(title: "Add people", systemImage: "person.badge.plus")
                SecondaryButton(title: "Invite one person") { state.startSetupDetour(.inviteOne) }
                    .accessibilityIdentifier("onboarding.invite.start")
                SecondaryButton(title: "Invite several at once") { state.startSetupDetour(.inviteMany) }
                    .accessibilityIdentifier("onboarding.invite.startMany")
            }
        }
        .disabled(onboarding.liveHomes.isEmpty)
        .opacity(onboarding.liveHomes.isEmpty ? 0.6 : 1)

        if !onboarding.pendingInvites.isEmpty {
            BrandCard {
                VStack(alignment: .leading, spacing: 12) {
                    BrandSectionHeader(title: "Waiting to be accepted", systemImage: "hourglass", subtitle: "\(onboarding.pendingInvites.count) pending · codes work once and expire after 7 days.")
                    ForEach(onboarding.pendingInvites) { invite in
                        inviteRow(invite, isLast: invite.id == onboarding.pendingInvites.last?.id)
                    }
                }
            }
        }

        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    BrandSectionHeader(title: "Staff", systemImage: "person.2", subtitle: "\(onboarding.accounts.filter { $0.status == "active" }.count) active")
                    Spacer(minLength: 8)
                    OnboardingActionLink(title: onboarding.showsStaff ? "Hide" : "Show \(onboarding.accounts.count)") {
                        onboarding.showsStaff.toggle()
                    }
                    .accessibilityIdentifier("onboarding.staff.toggle")
                }
                if onboarding.showsStaff {
                    let visibleAccounts = onboarding.accounts.filter { $0.status != "removed" }
                    ForEach(visibleAccounts) { account in
                        accountRow(account, isLast: account.id == visibleAccounts.last?.id)
                    }
                    if !onboarding.settledInvites.isEmpty {
                        BrandHairline()
                        Text("Earlier invites: " + onboarding.settledInvites.prefix(6).map { "\($0.email) (\($0.status))" }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var inviteWho: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingField(title: "Work email", text: $onboarding.inviteEmail, prompt: "sam@willow-care.co.uk", identifier: "onboarding.invite.email", contentType: .emailAddress, keyboard: .emailAddress, autocapitalises: false, filter: .email)
                OnboardingField(title: "Name (optional)", text: $onboarding.inviteName, prompt: "Sam Jones", identifier: "onboarding.invite.name", contentType: .name, maxLength: 80)
            }
        }
    }

    private var inviteAccess: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Role").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                    BrandSegmentedChoice(title: "Role", selection: $onboarding.inviteRole, options: roleOptions)
                        .accessibilityIdentifier("onboarding.invite.role")
                        .chimeOnChange(of: onboarding.inviteRole)
                }
                if onboarding.inviteRole != .orgAdmin {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Homes").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                        InsightChipFlow(spacing: 8) {
                            ForEach(onboarding.liveHomes) { home in
                                BrandSelectableChip(label: home.name, selected: onboarding.inviteHomeIds.contains(home.id)) {
                                    if onboarding.inviteHomeIds.contains(home.id) { onboarding.inviteHomeIds.remove(home.id) } else { onboarding.inviteHomeIds.insert(home.id) }
                                }
                                .accessibilityIdentifier("onboarding.invite.home.\(home.name)")
                            }
                        }
                    }
                } else {
                    Text("Organisation admins reach every home and this set-up.")
                        .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                OnboardingToggleRow(title: "Temporary cover — access ends on a date", isOn: $onboarding.inviteHasEndDate, identifier: "onboarding.invite.temporary")
                if onboarding.inviteHasEndDate {
                    DatePicker("Access ends", selection: $onboarding.inviteEndsAt, in: Date()..., displayedComponents: .date)
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textPrimary)
                        .tint(BrandTheme.gold)
                }
            }
        }
    }

    private var inviteBulk: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Role is supervisor, home lead or admin. Leave the home out and they join your first home.")
                    .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                OnboardingField(title: "Paste from a spreadsheet", text: $onboarding.bulkText, prompt: "amy@willow-care.co.uk, Amy Shah, supervisor, Willow Lodge", identifier: "onboarding.invite.bulk", autocapitalises: false, axis: .vertical, maxLength: 8000)
                if !onboarding.bulkErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(onboarding.bulkErrors) { error in
                            Label("\(error.email.isEmpty ? "(blank)" : error.email): \(error.message)", systemImage: "exclamationmark.triangle")
                                .font(.footnote).foregroundStyle(BrandTheme.statusAttention)
                        }
                    }
                }
            }
        }
    }

    private func inviteRow(_ invite: OrgInvite, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.displayName ?? invite.email).font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                    if invite.displayName != nil {
                        Text(invite.email).font(.caption).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("\(invite.role.onboardingLabel) · \(homeNames(invite.homeIds)) · expires \(OnboardingFormat.day(invite.expiresAt))")
                        .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                OnboardingStatusChip(status: invite.status)
            }
            if let code = onboarding.issuedCodes[invite.email] {
                OnboardingCodeTile(code: code, caption: "Give them this code if the email hasn’t arrived.", identifier: "onboarding.invite.code")
            }
            HStack(spacing: 18) {
                OnboardingActionLink(title: "Resend") { Task { @MainActor in await state.resendInvite(invite) } }
                    .accessibilityLabel("Resend invite to \(invite.displayName ?? invite.email)")
                    .accessibilityIdentifier("onboarding.invite.resend.\(invite.email)")
                OnboardingActionLink(title: "Revoke", tint: BrandTheme.statusAttention) { Task { @MainActor in await state.revokeInvite(invite) } }
                    .accessibilityLabel("Revoke invite for \(invite.displayName ?? invite.email)")
                    .accessibilityIdentifier("onboarding.invite.revoke.\(invite.email)")
            }
            if !isLast { BrandHairline() }
        }
        .accessibilityElement(children: .contain)
    }

    private func accountRow(_ account: OrgAccount, isLast: Bool) -> some View {
        let isSelf = account.id.lowercased() == state.signedInSupervisorId?.uuidString.lowercased()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName + (isSelf ? " (you)" : "")).font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                    Text("\(account.email) · \(account.role.onboardingLabel)" + (account.role == .orgAdmin ? "" : " · \(homeNames(account.homeIds))"))
                        .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let ends = account.accessEndsAt {
                        Text("Access ends \(OnboardingFormat.day(ends))").font(.caption).foregroundStyle(BrandTheme.statusCaution)
                    }
                }
                Spacer(minLength: 8)
                OnboardingStatusChip(status: account.status)
            }
            if !isSelf {
                InsightChipFlow(spacing: 18) {
                    if account.status == "suspended" {
                        OnboardingActionLink(title: "Restore") { Task { @MainActor in await state.changeAccount(account, .restore) } }
                    } else {
                        OnboardingActionLink(title: "Suspend", tint: BrandTheme.statusCaution) { Task { @MainActor in await state.changeAccount(account, .suspend) } }
                    }
                    OnboardingActionLink(title: "Reset PIN") { Task { @MainActor in await state.adminPinReset(account) } }
                    OnboardingActionLink(title: "Remove", tint: BrandTheme.statusAttention) { Task { @MainActor in await state.changeAccount(account, .remove) } }
                }
            }
            if !isLast { BrandHairline() }
        }
        .accessibilityElement(children: .contain)
    }

    private func homeNames(_ ids: [String]) -> String {
        let names = ids.compactMap { onboarding.home(id: $0)?.name }
        return names.isEmpty ? "no home" : names.joined(separator: ", ")
    }

    // MARK: Residents

    @ViewBuilder
    private var residentsImport: some View {
        if onboarding.liveHomes.isEmpty {
            OnboardingCallout(accent: BrandTheme.statusCaution) {
                Label("Add a home first — residents belong to a home and a wing.", systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(BrandTheme.textPrimary)
            }
        } else {
            if onboarding.liveHomes.count > 1 {
                BrandCard {
                    VStack(alignment: .leading, spacing: 14) {
                        BrandSectionHeader(title: "Which home", systemImage: "building.2")
                        InsightChipFlow(spacing: 8) {
                            ForEach(onboarding.liveHomes) { home in
                                BrandSelectableChip(label: "\(home.name) · \(home.residentCount)", selected: onboarding.importHomeId == home.id) {
                                    onboarding.importHomeId = home.id
                                    onboarding.importPreview = nil
                                }
                                .accessibilityIdentifier("onboarding.import.home.\(home.name)")
                                .accessibilityLabel("\(home.name), \(home.residentCount) residents")
                            }
                        }
                    }
                }
            }

            BrandCard {
                VStack(alignment: .leading, spacing: 14) {
                    BrandSectionHeader(
                        title: "Import from a spreadsheet",
                        systemImage: "tablecells",
                        subtitle: "Adding to \(onboarding.home(id: onboarding.importHomeId)?.name ?? "your home"). Residents arrive on the roster with “discovery not yet run”."
                    )
                    BrandInsetTile {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("One row per resident. Columns: name, room, wing, age, nationality, favourite genre, notes. Name and age are required.")
                                .font(.footnote)
                                .foregroundStyle(BrandTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            OnboardingActionLink(title: templateCopied ? "Template copied" : "Copy the template") {
                                UIPasteboard.general.string = ResidentCSVImport.templateCSV
                                templateCopied = true
                            }
                            .accessibilityIdentifier("onboarding.import.template")
                        }
                    }
                    SecondaryButton(title: "Choose a CSV file") { showsImporter = true }
                        .accessibilityIdentifier("onboarding.import.pick")
                        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [UTType.commaSeparatedText, .plainText, .text], allowsMultipleSelection: false) { result in
                            if case .success(let urls) = result, let url = urls.first {
                                state.importResidentsCSV(from: url)
                            }
                        }
                    OnboardingActionLink(title: "Try it with the sample spreadsheet") {
                        state.importResidentsSample()
                    }
                    .accessibilityIdentifier("onboarding.import.sample")
                    if let result = onboarding.importResult {
                        BrandInsetTile(accent: BrandTheme.statusPositive) {
                            Label(result, systemImage: "checkmark.circle")
                                .font(.subheadline).foregroundStyle(BrandTheme.textPrimary)
                        }
                        .accessibilityIdentifier("onboarding.import.result")
                    }
                }
            }

            BrandCard {
                VStack(alignment: .leading, spacing: 12) {
                    BrandSectionHeader(title: "Add one at a time", systemImage: "person.crop.circle.badge.plus", subtitle: "The roster’s “Start discovery for new resident” plays seven short pieces and builds their first playlist.")
                    if let home = onboarding.home(id: onboarding.importHomeId), let id = UUID(uuidString: home.id) {
                        SecondaryButton(title: "Open the roster for \(home.name)") {
                            state.openRosterForHome(id)
                        }
                        .accessibilityIdentifier("onboarding.import.roster")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var residentsReview: some View {
        if let preview = onboarding.importPreview {
            BrandCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        BrandStatusChip(text: "\(preview.validRows.count) ready", systemImage: "checkmark.circle", tint: BrandTheme.statusPositive, filled: true)
                        if preview.skippedCount > 0 {
                            BrandStatusChip(text: "\(preview.skippedCount) skipped", systemImage: "exclamationmark.circle", tint: BrandTheme.statusAttention, filled: true)
                        }
                        Spacer(minLength: 0)
                        Text(preview.fileName).font(.caption).foregroundStyle(BrandTheme.textSecondary).lineLimit(1)
                    }
                    ForEach(Array(preview.rows.prefix(40))) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.name.isEmpty ? "Line \(row.line)" : row.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(row.isValid ? BrandTheme.textPrimary : BrandTheme.textSecondary)
                                .strikethrough(!row.isValid)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text([row.room, row.wing?.name ?? "", row.age.map { "\($0)" } ?? "", row.nationality.displayName, row.genre.rawValue.capitalized].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if !row.problems.isEmpty || !row.warnings.isEmpty {
                                InsightChipFlow(spacing: 6) {
                                    ForEach(row.problems, id: \.self) { problem in
                                        BrandStatusChip(text: problem, systemImage: "xmark.circle", tint: BrandTheme.statusAttention)
                                    }
                                    ForEach(row.warnings, id: \.self) { warning in
                                        BrandStatusChip(text: warning, systemImage: "info.circle", tint: BrandTheme.statusCaution)
                                    }
                                }
                            }
                            if row.id != preview.rows.prefix(40).last?.id { BrandHairline() }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if preview.rows.count > 40 {
                        Text("… and \(preview.rows.count - 40) more rows").font(.caption).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    BrandHairline()
                    OnboardingActionLink(title: "Discard this spreadsheet") {
                        state.discardResidentImport()
                        state.goToSetupPage(.residentsImport)
                    }
                    .accessibilityIdentifier("onboarding.import.discard")
                }
            }
        } else {
            BrandCard {
                Text("No spreadsheet to check.").font(.footnote).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: iPads

    private var guidance: [(String, String, String)] {
        [
            ("lock.rotation", "Guided Access", "Triple-click the side button so a resident can’t leave the app."),
            ("moon.zzz", "Auto-lock and a passcode", "Auto-Lock at 5 minutes and a passcode only staff know."),
            ("person.crop.circle.badge.xmark", "No personal accounts", "No personal Apple ID, mail or photos on a shared iPad."),
            ("timer", "PIN re-prompt", "After \(onboarding.settings.idlePinMinutes == 0 ? "— off" : "\(onboarding.settings.idlePinMinutes) minutes idle"), the next person signs in again."),
            ("building.columns", "Managed deployment", "Apple Business Manager and your MDM can push the app and lock a lost iPad."),
        ]
    }

    private var ipadGuidance: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(guidance.enumerated()), id: \.element.1) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.0)
                            .font(.title3)
                            .foregroundStyle(BrandTheme.logoCyan)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1).font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                            Text(item.2).font(.footnote).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    if index < guidance.count - 1 { BrandHairline() }
                }
            }
        }
    }

    @ViewBuilder
    private var ipadRegister: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 14) {
                if let mine = state.thisDevice() {
                    BrandInsetTile(accent: BrandTheme.statusPositive) {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(mine.label, systemImage: "checkmark.seal").font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                            Text("\(onboarding.home(id: mine.homeId)?.name ?? "No home") · \(mine.model ?? "iPad") · \(mine.os ?? "")")
                                .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    OnboardingActionLink(title: "Remove this iPad", tint: BrandTheme.statusAttention) {
                        Task { @MainActor in await state.removeDevice(mine) }
                    }
                } else if onboarding.liveHomes.isEmpty {
                    Text("Add a home first.").font(.footnote).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    OnboardingField(title: "Label", text: $onboarding.deviceLabel, prompt: "\(onboarding.home(id: onboarding.deviceHomeId)?.name ?? "Home") · Day room", identifier: "onboarding.device.label", maxLength: 60)
                    if onboarding.liveHomes.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Home").font(.caption.weight(.semibold)).foregroundStyle(BrandTheme.textSecondary)
                            InsightChipFlow(spacing: 8) {
                                ForEach(onboarding.liveHomes) { home in
                                    BrandSelectableChip(label: home.name, selected: onboarding.deviceHomeId == home.id) {
                                        onboarding.deviceHomeId = home.id
                                    }
                                }
                            }
                        }
                    }
                    SecondaryButton(title: onboarding.isBusy ? "Registering…" : "Register this iPad") {
                        Task { @MainActor in await state.registerThisIPad() }
                    }
                    .accessibilityIdentifier("onboarding.device.register")
                    .disabled(onboarding.isBusy)
                }
            }
        }

        if !onboarding.devices.isEmpty {
            BrandCard {
                VStack(alignment: .leading, spacing: 10) {
                    BrandSectionHeader(title: "Registered iPads", systemImage: "list.bullet", subtitle: "\(onboarding.devices.count) in the organisation")
                    ForEach(onboarding.devices) { device in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.label).font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                                Text("\(onboarding.home(id: device.homeId)?.name ?? "No home") · last seen \(OnboardingFormat.dayAndTime(device.lastSeenAt))")
                                    .font(.caption).foregroundStyle(BrandTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            if device.id == AuthSession.deviceId.lowercased() {
                                BrandStatusChip(text: "This iPad", systemImage: "ipad", tint: BrandTheme.statusPositive)
                            }
                        }
                        if device.id != onboarding.devices.last?.id { BrandHairline() }
                    }
                }
            }
        }
    }

    // MARK: Ready

    private var withoutDiscovery: Int {
        state.carePatients.filter { $0.isActive && !$0.isProvisional && $0.careContextLabel.localizedCaseInsensitiveContains("discovery not yet run") }.count
    }

    @ViewBuilder
    private var readyChecklist: some View {
        let checklist = onboarding.organisation?.checklist
        BrandCard {
            VStack(alignment: .leading, spacing: 12) {
                readyRow("Organisation profile", detail: onboarding.storedAddressIsComplete ? (onboarding.organisation?.organisation.name ?? "—") : "Address needed", done: (checklist?.organisation ?? false) && onboarding.storedAddressIsComplete)
                readyRow("Homes", detail: "\(checklist?.homes ?? 0) added", done: (checklist?.homes ?? 0) > 0)
                readyRow("Team", detail: "\(checklist?.invitesAccepted ?? 0) joined · \(checklist?.invitesPending ?? 0) invited", done: onboarding.isSectionDone(.team))
                readyRow("Residents", detail: "\(max(checklist?.residents ?? 0, state.carePatients.filter { $0.isActive && !$0.isProvisional }.count)) on the roster" + (withoutDiscovery > 0 ? " · \(withoutDiscovery) without discovery" : ""), done: (checklist?.residents ?? 0) > 0 || !state.carePatients.isEmpty)
                readyRow("iPads", detail: "\(checklist?.devices ?? 0) registered", done: (checklist?.devices ?? 0) > 0)
                readyRow("Email domains", detail: "\(checklist?.domainsVerified ?? 0) verified", done: (checklist?.domainsVerified ?? 0) > 0, isLast: true)
            }
        }

        if (checklist?.invitesPending ?? 0) > 0 || withoutDiscovery > 0 {
            OnboardingCallout(accent: BrandTheme.statusCaution) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("First week", systemImage: "sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(BrandTheme.textPrimary)
                    if let pending = checklist?.invitesPending, pending > 0 {
                        Text("\(pending) invite\(pending == 1 ? "" : "s") still waiting — resend from the Team page if the email didn’t arrive.")
                            .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if withoutDiscovery > 0 {
                        Text("\(withoutDiscovery) resident\(withoutDiscovery == 1 ? " hasn’t" : "s haven’t") had a discovery pass yet — their first one-to-one starts with it.")
                            .font(.footnote).foregroundStyle(BrandTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var readyAudit: some View {
        BrandCard {
            VStack(alignment: .leading, spacing: 10) {
                if onboarding.audit.isEmpty {
                    Text("Nothing logged yet.").font(.footnote).foregroundStyle(BrandTheme.textSecondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(onboarding.audit.prefix(12)) { entry in
                        BrandKeyValueRow(label: entry.label, value: OnboardingFormat.dayAndTime(entry.at), isLast: entry.id == onboarding.audit.prefix(12).last?.id)
                    }
                }
            }
        }
        .onAppear { Task { @MainActor in await state.loadAudit() } }

        if let home = onboarding.liveHomes.first, let id = UUID(uuidString: home.id), state.assignedHomes().contains(where: { $0.id == id }) {
            SecondaryButton(title: "Open the roster for \(home.name)") {
                state.openRosterForHome(id)
            }
            .accessibilityIdentifier("onboarding.ready.roster")
        }
    }

    private func readyRow(_ title: String, detail: String, done: Bool, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(BrandTheme.textPrimary)
                Spacer(minLength: 8)
                Text(detail).font(.caption).foregroundStyle(BrandTheme.textSecondary).multilineTextAlignment(.trailing)
                BrandStatusChip(text: done ? "Done" : "To do", systemImage: done ? "checkmark.circle" : "circle", tint: done ? BrandTheme.statusPositive : BrandTheme.statusCaution)
            }
            .padding(.vertical, 8)
            if !isLast { BrandHairline() }
        }
        .accessibilityElement(children: .combine)
    }
}
