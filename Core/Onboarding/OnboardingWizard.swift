import Foundation

// MARK: - Coordinator: moving around the set-up wizard
//
// Every way out of a page — Next, the previous-page button, a stepper circle, the top-left exit, Finish —
// goes through `requestSetupNavigation`. Moving between pages that share unsent work (the three "add a
// home" pages, the two "invite one person" pages, the organisation pages) keeps that work in the store.
// Leaving the group with unsent work (an unsaved profile, a half-filled home or invite, a checked but
// unimported spreadsheet, an iPad label) asks instead of dropping it.

extension SessionPOCState {
    typealias SetupDestination = OnboardingStore.SetupDestination

    func requestSetupNavigation(_ destination: SetupDestination) {
        let ob = onboarding
        if case .page(let target) = destination {
            if target == ob.page { return }
            if let scope = ob.page.draftScope, scope == target.draftScope {
                performSetupNavigation(destination)
                return
            }
        }
        if let draft = ob.draftInProgress(on: ob.page) {
            ob.error = nil
            ob.notice = nil
            ob.pendingLeave = OnboardingStore.PendingLeave(draft: draft, destination: destination)
            return
        }
        performSetupNavigation(destination)
    }

    func performSetupNavigation(_ destination: SetupDestination) {
        switch destination {
        case .page(let page): goToSetupPage(page)
        case .exit: exitOrgSetup()
        case .finish: finishOrgSetup()
        }
    }

    /// The bar's "Next". On the organisation pages it saves what was typed first, so a wrong CQC
    /// number is reported on the page that has it rather than three pages later.
    @MainActor
    func advanceSetup() async {
        let ob = onboarding
        guard let next = ob.nextPage(of: ob.page) else { return }
        if ob.page.section == .organisation {
            // Check what is on this page first, so a missing address is flagged on the address page
            // rather than as a banner with nothing to point at.
            let problems = ob.organisationProblems(onPage: ob.page)
            if !problems.isEmpty { ob.report(problems); return }
            if ob.organisationIsDirty {
                guard await saveOrganisationProfile() else { return }
            }
        }
        requestSetupNavigation(.page(next))
    }

    /// Starts one of the side journeys (add a home, invite someone, check a spreadsheet).
    func startSetupDetour(_ detour: OnboardingStore.SetupDetour) {
        let ob = onboarding
        ob.error = nil
        ob.notice = nil
        switch detour {
        case .addHome: ob.resetHomeDraft()
        case .inviteOne:
            ob.resetInviteDraft()
            ob.reconcileHomeSelections()
        case .inviteMany: ob.bulkErrors = []
        case .reviewImport: break
        }
        ob.page = detour.pages[0]
    }

    /// The commit on the last page of a detour; on success it returns to the overview it started from
    /// and keeps the confirmation ("Hand Lodge added.") on screen.
    @MainActor
    func commitSetupDetour() async {
        let ob = onboarding
        let succeeded: Bool
        let destination: OnboardingStore.SetupPage
        switch ob.page {
        case .homeLead: succeeded = await createHome(); destination = .homesOverview
        case .inviteAccess: succeeded = await sendInvite(); destination = .teamOverview
        case .inviteBulk: succeeded = await sendBulkInvites(); destination = .teamOverview
        case .residentsReview: succeeded = applyResidentImport(); destination = .residentsImport
        default: return
        }
        guard succeeded else { return }
        let confirmation = ob.notice
        goToSetupPage(destination)
        ob.notice = confirmation
    }

    /// The admin's answer to the "unsent work" prompt. `pending` is passed in because the alert
    /// clears `pendingLeave` as it dismisses.
    @MainActor
    func resolvePendingLeave(_ pending: OnboardingStore.PendingLeave, save: Bool) async {
        let ob = onboarding
        ob.pendingLeave = nil
        var confirmation: String?
        if save {
            guard await saveSetupDraft(pending.draft) else { return }   // the reason is in the banner; stay put
            confirmation = ob.notice   // "Invite sent to …" should survive the page change
        } else {
            discardSetupDraft(pending.draft)
        }
        performSetupNavigation(pending.destination)
        if let confirmation { ob.notice = confirmation }
    }

    @MainActor
    private func saveSetupDraft(_ draft: OnboardingStore.SetupDraft) async -> Bool {
        let ob = onboarding
        switch draft {
        case .organisation:
            return await saveOrganisationProfile()
        case .home:
            return await createHome()
        case .invite:
            var ok = true
            if !ob.inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ok = await sendInvite() }
            if ok, !ob.bulkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ok = await sendBulkInvites() }
            return ok
        case .importPreview:
            return applyResidentImport()
        case .device:
            return await registerThisIPad()
        }
    }

    private func discardSetupDraft(_ draft: OnboardingStore.SetupDraft) {
        let ob = onboarding
        switch draft {
        case .organisation: ob.revertOrganisationDrafts()
        case .home: ob.resetHomeDraft()
        case .invite: ob.clearInviteDraft()
        case .importPreview: discardResidentImport()
        case .device: ob.deviceLabel = ""
        }
        ob.error = nil
    }
}
