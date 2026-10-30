import Foundation
import UIKit

// MARK: - Coordinator: organisation & home onboarding
//
// Request a workspace → verify → (approval) → activate with an ORG- code → the six-step set-up;
// staff join with an INV- code. Everything here needs the backend (`APIConfig.isConfigured`); the
// sign-in screen only shows the entry links when it is there. State lives in `OnboardingStore`.

extension SessionPOCState {
    // MARK: Entry points (sign-in screen)

    func beginOrgRequest() {
        let typed = supervisorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        onboarding.resetRequest(prefillEmail: typed.contains("@") ? typed : "")
        supervisorSignInError = nil
        transitionToPhase(.orgRequest)
    }

    func beginOrgCode(prefillEmail: String? = nil, prefillCode: String = "") {
        let typed = supervisorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        onboarding.resetCode(prefillEmail: prefillEmail ?? (typed.contains("@") ? typed : ""), prefillCode: prefillCode)
        supervisorSignInError = nil
        transitionToPhase(.orgCode)
    }

    func cancelOnboardingEntry() {
        onboarding.error = nil
        transitionToPhase(.home)
    }

    // MARK: Request a workspace

    @MainActor
    func submitOrgRequest() async {
        let ob = onboarding
        let problems = ob.requestProblems()
        if !problems.isEmpty { ob.report(problems); return }
        let orgName = InputRules.tidy(ob.orgNameDraft)
        let name = InputRules.tidy(ob.requesterName)
        let email = ob.requestEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cqc = ob.requestCqc.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = InputRules.tidy(ob.requestPhone)
        let notes = ob.requestNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ob.isBusy else { return }
        ob.isBusy = true
        defer { ob.isBusy = false }
        do {
            let response = try await OnboardingClient.requestWorkspace(OrgRequestBody(
                orgName: orgName,
                requesterName: name,
                email: email,
                phone: phone.isEmpty ? nil : phone,
                requesterRole: ob.requesterRole.rawValue,
                homesBand: ob.homesBand.rawValue,
                cqcProviderId: cqc.isEmpty ? nil : cqc,
                notes: notes.isEmpty ? nil : notes,
                consentVersion: OnboardingConsent.termsVersion
            ))
            ob.error = nil
            ob.requestMessage = response.message
            ob.verifyDevCode = response.devCode
            ob.verifyCode = ""
            ob.requestStep = .verify
        } catch let error as APIError {
            ob.error = offlineAware(error, fallback: "Couldn’t send the request. Try again.")
        } catch {
            ob.error = "Couldn’t send the request. Try again."
        }
    }

    @MainActor
    func verifyOrgRequest() async {
        let ob = onboarding
        let code = String(ob.verifyCode.filter(\.isWholeNumber).prefix(6))
        guard code.count == 6 else { ob.error = "Enter the 6-digit verification code."; return }
        guard !ob.isBusy else { return }
        ob.isBusy = true
        defer { ob.isBusy = false }
        do {
            let email = ob.requestEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let response = try await OnboardingClient.verifyRequest(email: email, code: code)
            ob.error = nil
            ob.requestMessage = response.message
            ob.activationCodeFromServer = response.activationCode
            ob.requestStep = .done
        } catch let error as APIError {
            ob.error = offlineAware(error, fallback: "That code didn’t match or has expired. Request a new one.")
        } catch {
            ob.error = "Couldn’t verify the code. Try again."
        }
    }

    /// From the "approved" screen straight into activation with the code the backend exposed.
    func continueToActivation() {
        let email = onboarding.requestEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        beginOrgCode(prefillEmail: email, prefillCode: onboarding.activationCodeFromServer ?? "")
    }

    // MARK: Codes (activation / invite)

    @MainActor
    func previewInviteCode() async {
        let ob = onboarding
        let email = ob.codeEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard ob.codeKind == .invite, ob.codeIsComplete, email.contains("@") else {
            ob.invitePreview = nil
            return
        }
        do {
            ob.invitePreview = try await OnboardingClient.previewInvite(email: email, code: ob.normalisedCode)
        } catch {
            ob.invitePreview = nil
        }
    }

    @MainActor
    func redeemCode() async {
        let ob = onboarding
        let email = ob.codeEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let problems = ob.codeProblems()
        if !problems.isEmpty { ob.report(problems); return }
        guard let kind = ob.codeKind, ob.codeIsComplete else { ob.error = "Codes start with ORG- or INV- and have eight more letters and digits."; return }
        if ob.codePIN.count != SupervisorAuth.pinDigitCount { ob.error = "Choose a \(SupervisorAuth.pinDigitCount)-digit PIN."; return }
        if ob.codePIN != ob.codeConfirmPIN { ob.error = "PINs don’t match. Enter the same PIN twice."; return }
        if !ob.acceptedTerms { ob.error = "Please confirm you have read how resident data is handled."; return }
        guard !ob.isBusy, !auth.isAuthenticating else { return }
        ob.isBusy = true
        auth.isAuthenticating = true
        defer {
            ob.isBusy = false
            auth.isAuthenticating = false
        }
        let displayName = InputRules.tidy(ob.codeDisplayName)
        do {
            let principal: Principal
            switch kind {
            case .activation:
                principal = try await AuthSession.shared.activateOrganisation(email: email, code: ob.normalisedCode, pin: ob.codePIN, displayName: displayName.isEmpty ? nil : displayName)
            case .invite:
                principal = try await AuthSession.shared.acceptInvite(email: email, code: ob.normalisedCode, pin: ob.codePIN, displayName: displayName.isEmpty ? nil : displayName)
            }
            ob.error = nil
            ob.codePIN = ""
            ob.codeConfirmPIN = ""
            adopt(principal)
        } catch let error as APIError {
            ob.error = offlineAware(error, fallback: "Couldn’t use that code. Try again.")
        } catch {
            ob.error = "Couldn’t use that code. Try again."
        }
    }

    // MARK: Set-up wizard

    /// The organisation admin's set-up. Also the landing phase for a freshly activated organisation.
    /// `resume: true` (the dashboard card, the home picker) opens at the first step still to do instead
    /// of the top; a fresh activation starts at step 1.
    func openOrgSetup(resume: Bool = false) {
        let ob = onboarding
        ob.beginSetup()
        if resume, ob.organisation != nil { ob.page = ob.firstIncompletePage }
        transitionToPhase(.orgSetup)
        Task { @MainActor in
            let hadPayload = ob.organisation != nil
            await loadOrganisation()
            // Nothing cached yet: jump once the checklist arrives, unless the admin already moved.
            if resume, !hadPayload, ob.page == .orgDetails { ob.page = ob.firstIncompletePage }
        }
    }

    /// Back from set-up: the dashboard when a home is open, the picker when there are homes.
    func exitOrgSetup() {
        if currentHomeId != nil {
            careHomeAdminWelcomeIsManual = false
            transitionToPhase(.careHomeAdminDashboard)
        } else if !assignedHomes().isEmpty {
            transitionToPhase(.careHomePicker)
        }
    }

    func finishOrgSetup() {
        let homes = assignedHomes()
        guard let first = homes.first else {
            onboarding.error = "Add at least one home before finishing."
            onboarding.page = .homesOverview
            return
        }
        onboarding.error = nil
        if homes.count == 1 {
            currentHomeId = first.id
            careHomeAdminWelcomeIsManual = false
            transitionToPhase(.careHomeAdminWelcome)
        } else {
            transitionToPhase(.careHomePicker)
        }
    }

    func goToSetupPage(_ page: OnboardingStore.SetupPage) {
        onboarding.error = nil
        onboarding.notice = nil
        onboarding.page = page
    }

    @MainActor
    func loadOrganisation() async {
        let ob = onboarding
        ob.isBusy = true
        defer { ob.isBusy = false }
        do {
            async let org = OnboardingClient.organisation()
            async let homes = OnboardingClient.homes()
            async let invites = OnboardingClient.invites()
            async let accounts = OnboardingClient.accounts()
            async let devices = OnboardingClient.devices()
            let (o, h, i, a, d) = try await (org, homes, invites, accounts, devices)
            ob.apply(o)
            ob.homes = h.homes
            ob.invites = i.invites
            ob.accounts = a.accounts
            ob.devices = d.devices
            ob.reconcileHomeSelections()
            if ob.page == .readyAudit {
                ob.audit = (try? await OnboardingClient.audit()).map(\.entries) ?? ob.audit
            }
        } catch let error as APIError {
            ob.error = offlineAware(error, fallback: "Couldn’t load the organisation.")
        } catch {
            ob.error = "Couldn’t load the organisation."
        }
    }

    @MainActor
    func loadAudit() async {
        if let entries = try? await OnboardingClient.audit().entries {
            onboarding.audit = entries
        }
    }

    @MainActor
    @discardableResult
    func saveOrganisationProfile() async -> Bool {
        let ob = onboarding
        let problems = ob.organisationProblems()
        if !problems.isEmpty { ob.report(problems); return false }
        let name = InputRules.tidy(ob.orgName)
        let cqc = ob.cqcProviderId.trimmingCharacters(in: .whitespacesAndNewlines)
        let line1 = InputRules.tidy(ob.addressLine1)
        let town = InputRules.tidy(ob.addressTown)
        let postcode = InputRules.normalisePostcode(ob.addressPostcode) ?? ""
        return await runOnboardingCall("Couldn’t save the organisation.") {
            let address = OrgAddress(
                line1: line1.isEmpty ? nil : line1,
                line2: nil,
                town: town.isEmpty ? nil : town,
                postcode: postcode.isEmpty ? nil : postcode,
                country: "United Kingdom"
            )
            let payload = try await OnboardingClient.updateOrganisation(OrganisationPatch(
                name: name,
                tradingName: InputRules.tidy(ob.tradingName),
                cqcProviderId: cqc,
                address: address,
                settings: ob.settings
            ))
            ob.apply(payload, reseedDrafts: true)
            ob.notice = "Organisation saved."
        }
    }

    @MainActor
    func claimDomain() async {
        let ob = onboarding
        if let problem = InputRules.domain(ob.newDomain) {
            ob.report([.init(field: "onboarding.domain.new", message: problem)])
            return
        }
        let domain = InputRules.normaliseDomain(ob.newDomain)
        await runOnboardingCall("Couldn’t start the domain claim.") {
            let response = try await OnboardingClient.claimDomain(domain, method: ob.domainMethod)
            if response.status == "verified" {
                ob.notice = "\(domain) is already verified."
                ob.newDomain = ""
                ob.pendingDomain = nil
                ob.pendingDomainRecord = nil
            } else if response.method == "dns", let record = response.record {
                ob.pendingDomain = response.domain
                ob.pendingDomainRecord = record
                ob.domainCode = ""
                ob.newDomain = ""
                ob.notice = "Add the TXT record below, then tap Check DNS. Changes can take up to an hour."
            } else {
                ob.pendingDomain = response.domain
                ob.pendingDomainRecord = nil
                ob.domainDevCode = response.devCode
                ob.domainCode = ""
                ob.notice = "Code sent to \((response.sentTo ?? []).joined(separator: " and "))."
            }
            await self.loadOrganisation()
        }
    }

    @MainActor
    func verifyDomain() async {
        let ob = onboarding
        guard let domain = ob.pendingDomain else { return }
        let isDNS = ob.pendingDomainRecord != nil
        let code = String(ob.domainCode.filter(\.isWholeNumber).prefix(6))
        if !isDNS, code.count != 6 {
            ob.report([.init(field: "onboarding.domain.code", message: "Enter the 6-digit code from the domain email.")])
            return
        }
        await runOnboardingCall(isDNS ? "The TXT record wasn’t found yet." : "That code didn’t match or has expired.") {
            _ = try await OnboardingClient.verifyDomain(domain, code: code)
            ob.pendingDomain = nil
            ob.pendingDomainRecord = nil
            ob.domainCode = ""
            ob.domainDevCode = nil
            ob.newDomain = ""
            ob.notice = "\(domain) verified. Staff with that email domain are pointed to staff sign-in."
            await self.loadOrganisation()
        }
    }

    @MainActor
    func removeDomain(_ domain: String) async {
        await runOnboardingCall("Couldn’t remove the domain.") {
            try await OnboardingClient.removeDomain(domain)
            if self.onboarding.pendingDomain == domain {
                self.onboarding.pendingDomain = nil
                self.onboarding.pendingDomainRecord = nil
            }
            await self.loadOrganisation()
        }
    }

    /// Resumes a pending DNS claim from the loaded list (the record is public, so it can be shown again).
    func resumeDomainClaim(_ pending: OrgPendingDomain) {
        onboarding.pendingDomain = pending.domain
        onboarding.pendingDomainRecord = pending.record
        onboarding.domainCode = ""
        onboarding.error = nil
    }

    // MARK: Export

    /// Fetches a home's export into a temporary file and offers it through the share sheet.
    @MainActor
    func exportHome(_ home: OrgHome, format: String, kind: String) async {
        let ob = onboarding
        ob.exportingHomeId = home.id
        defer { ob.exportingHomeId = nil }
        await runOnboardingCall("Couldn’t export \(home.name).") {
            let url = try await OnboardingClient.export(homeId: home.id, format: format, kind: kind)
            ob.exportFile = OrgExportFile(url: url, homeName: home.name)
            ob.notice = "\(url.lastPathComponent) is ready to share."
        }
    }

    func clearExport() {
        if let url = onboarding.exportFile?.url { try? FileManager.default.removeItem(at: url) }
        onboarding.exportFile = nil
    }

    // MARK: Homes

    func addWingToDraft() {
        let ob = onboarding
        if let problem = ob.newWingProblem() {
            ob.report([.init(field: "onboarding.home.newWing", message: problem)])
            return
        }
        ob.homeWings.append(InputRules.tidy(ob.newWing))
        ob.newWing = ""
        ob.fieldErrors["onboarding.home.newWing"] = nil
        ob.error = nil
    }

    @MainActor
    @discardableResult
    func createHome() async -> Bool {
        let ob = onboarding
        let problems = ob.homeProblems()
        if !problems.isEmpty { ob.report(problems); return false }
        let name = InputRules.tidy(ob.homeName)
        let wings = ob.homeWings.map { InputRules.tidy($0) }.filter { !$0.isEmpty }
        let cqc = ob.homeCqc.trimmingCharacters(in: .whitespacesAndNewlines)
        let homeAddress = OrgAddress(
            line1: InputRules.tidy(ob.homeAddressLine1),
            line2: nil,
            town: InputRules.tidy(ob.homeAddressTown),
            postcode: InputRules.normalisePostcode(ob.homeAddressPostcode),
            country: "United Kingdom"
        )
        var lead: NewHomeLead? = NewHomeLead(email: nil, displayName: nil, me: true)
        if !ob.homeLeadIsMe {
            let email = ob.homeLeadEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let leadName = InputRules.tidy(ob.homeLeadName)
            lead = NewHomeLead(email: email, displayName: leadName.isEmpty ? nil : leadName, me: false)
        }
        return await runOnboardingCall("Couldn’t add the home.") {
            let response = try await OnboardingClient.createHome(NewHomeBody(
                name: name,
                cqcLocationId: cqc.isEmpty ? nil : cqc,
                capacity: Int(ob.homeCapacity.trimmingCharacters(in: .whitespacesAndNewlines)),
                address: homeAddress,
                wings: wings,
                lead: lead
            ))
            if let invite = response.invite, let code = invite.code {
                ob.issuedCodes[invite.email] = code
            }
            ob.resetHomeDraft()
            ob.notice = response.invite == nil ? "\(response.home.name) added." : "\(response.home.name) added and the home lead invited."
            await self.refreshPrincipalAfterHomesChanged()
            await self.loadOrganisation()
        }
    }

    @MainActor
    func archiveHome(_ home: OrgHome) async {
        await runOnboardingCall("Couldn’t archive the home.") {
            _ = try await OnboardingClient.archiveHome(id: home.id)
            self.onboarding.notice = "\(home.name) archived."
            await self.refreshPrincipalAfterHomesChanged()
            await self.loadOrganisation()
        }
    }

    /// New claims (home assignments) → new access token → `/me` → sync watches the new homes too.
    @MainActor
    func refreshPrincipalAfterHomesChanged() async {
        guard let principal = await AuthSession.shared.refreshCurrentSession() else { return }
        let account = principal.supervisorAccount
        if let current = currentHomeId, !account.homeIds.contains(current) { currentHomeId = nil }
        sync.activate(homeIds: account.homeIds, accountId: account.id)
    }

    // MARK: Team

    @MainActor
    @discardableResult
    func sendInvite() async -> Bool {
        let ob = onboarding
        let problems = ob.inviteProblems()
        if !problems.isEmpty { ob.report(problems); return false }
        let email = ob.inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let homeIds = ob.inviteRole == .orgAdmin ? [] : Array(ob.inviteHomeIds)
        let name = InputRules.tidy(ob.inviteName)
        return await runOnboardingCall("Couldn’t send the invite.") {
            let response = try await OnboardingClient.sendInvite(NewInviteBody(
                email: email,
                displayName: name.isEmpty ? nil : name,
                role: ob.inviteRole,
                homeIds: homeIds,
                endsAt: ob.inviteHasEndDate ? OnboardingFormat.isoDay(ob.inviteEndsAt) : nil
            ))
            if let code = response.code { ob.issuedCodes[email] = code }
            ob.resetInviteDraft()
            ob.notice = ((response.warnings ?? []).first.map { "Invite sent to \(email). \($0)" }) ?? "Invite sent to \(email)."
            await self.loadOrganisation()
        }
    }

    /// One invite per line: `email[, name[, role[, home]]]`. Role words: supervisor, home lead, admin.
    @MainActor
    @discardableResult
    func sendBulkInvites() async -> Bool {
        let ob = onboarding
        let lines = ob.bulkText.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else {
            ob.report([.init(field: "onboarding.invite.bulk", message: "Paste one invite per line: email, name, role, home.")])
            return false
        }
        guard lines.count <= 50 else {
            ob.report([.init(field: "onboarding.invite.bulk", message: "Send at most 50 invites at a time.")])
            return false
        }
        let defaultHome = ob.inviteHomeIds.first ?? ob.liveHomes.first?.id
        var bodies: [NewInviteBody] = []
        var localErrors: [BulkInviteError] = []
        for line in lines {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            let email = (parts.first ?? "").lowercased()
            let name = parts.count > 1 ? InputRules.tidy(parts[1]) : ""
            let roleText = parts.count > 2 ? parts[2].lowercased() : ""
            let homeText = parts.count > 3 ? parts[3] : ""
            if let problem = InputRules.email(email) ?? InputRules.personName(name) {
                localErrors.append(BulkInviteError(email: email, message: problem))
                continue
            }
            if bodies.contains(where: { $0.email == email }) {
                localErrors.append(BulkInviteError(email: email, message: "Listed twice."))
                continue
            }
            let role: SupervisorRole
            switch roleText {
            case "", "supervisor", "carer", "staff": role = .supervisor
            case "home lead", "homelead", "lead", "manager": role = .homeLead
            case "admin", "organisation admin", "org admin", "orgadmin": role = .orgAdmin
            default:
                localErrors.append(BulkInviteError(email: email, message: "Role “\(parts[2])” not recognised (supervisor, home lead or admin)."))
                continue
            }
            var homeIds: [String] = []
            if role != .orgAdmin {
                if homeText.isEmpty {
                    if let defaultHome { homeIds = [defaultHome] }
                } else if let home = ob.liveHomes.first(where: { $0.name.caseInsensitiveCompare(homeText) == .orderedSame }) {
                    homeIds = [home.id]
                } else {
                    localErrors.append(BulkInviteError(email: email, message: "Home “\(homeText)” not found."))
                    continue
                }
            }
            bodies.append(NewInviteBody(email: email, displayName: name.isEmpty ? nil : name, role: role, homeIds: homeIds, endsAt: nil))
        }
        ob.bulkErrors = localErrors
        guard !bodies.isEmpty else { ob.error = localErrors.first?.message ?? "Nothing to send."; return false }
        let sent = await runOnboardingCall("Couldn’t send the invites.") {
            let response = try await OnboardingClient.sendInvites(bodies)
            for invite in response.sent {
                if let code = invite.code { ob.issuedCodes[invite.email] = code }
            }
            ob.bulkErrors = localErrors + response.errors
            if ob.bulkErrors.isEmpty {
                ob.bulkText = ""
            } else {
                // Keep only the lines that still need fixing, so a second tap never re-sends the ones that went.
                let failed = Set(ob.bulkErrors.map { $0.email.lowercased() })
                ob.bulkText = lines.filter { line in
                    let email = (line.split(separator: ",", omittingEmptySubsequences: false).first ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                    return failed.contains(email)
                }.joined(separator: "\n")
            }
            ob.notice = "\(response.sent.count) invite\(response.sent.count == 1 ? "" : "s") sent" + (ob.bulkErrors.isEmpty ? "." : ", \(ob.bulkErrors.count) skipped.") + ((response.warnings ?? []).first.map { " \($0)" } ?? "")
            await self.loadOrganisation()
        }
        // Rows the server skipped stay listed on screen, so the step still has work to look at.
        return sent && ob.bulkErrors.isEmpty
    }

    @MainActor
    func resendInvite(_ invite: OrgInvite) async {
        await runOnboardingCall("Couldn’t resend the invite.") {
            let response = try await OnboardingClient.resendInvite(id: invite.id)
            if let code = response.code { self.onboarding.issuedCodes[invite.email] = code }
            self.onboarding.notice = "New code sent to \(invite.email); the old one no longer works."
            await self.loadOrganisation()
        }
    }

    @MainActor
    func revokeInvite(_ invite: OrgInvite) async {
        await runOnboardingCall("Couldn’t revoke the invite.") {
            try await OnboardingClient.revokeInvite(id: invite.id)
            self.onboarding.issuedCodes.removeValue(forKey: invite.email)
            self.onboarding.notice = "Invite for \(invite.email) revoked."
            await self.loadOrganisation()
        }
    }

    @MainActor
    func changeAccount(_ account: OrgAccount, _ action: OnboardingClient.AccountAction) async {
        await runOnboardingCall("Couldn’t update that account.") {
            _ = try await OnboardingClient.accountAction(id: account.id, action)
            let verb: String
            switch action {
            case .suspend: verb = "suspended"
            case .restore: verb = "restored"
            case .remove: verb = "removed"
            }
            self.onboarding.notice = "\(account.displayName) \(verb)."
            await self.loadOrganisation()
        }
    }

    @MainActor
    func adminPinReset(_ account: OrgAccount) async {
        await runOnboardingCall("Couldn’t start the PIN reset.") {
            let response = try await OnboardingClient.adminPinReset(id: account.id)
            if let code = response.devCode {
                self.onboarding.notice = "Reset code for \(account.displayName): \(code) (valid 10 minutes). They enter it under Forgot PIN."
            } else {
                self.onboarding.notice = "Reset code sent to \(account.email). They enter it under Forgot PIN within 10 minutes."
            }
        }
    }

    // MARK: Residents (CSV import)

    /// Parses the picked file off the main thread and shows the preview for the chosen home.
    func importResidentsCSV(from url: URL) {
        let ob = onboarding
        guard let home = ob.home(id: ob.importHomeId)?.careHome else {
            ob.error = "Choose the home these residents belong to."
            return
        }
        let existing = carePatients
        let fileName = url.lastPathComponent
        Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let text: String
            do {
                let data = try Data(contentsOf: url)
                text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            } catch {
                await MainActor.run { ob.error = "Couldn’t read \(fileName)." }
                return
            }
            let preview = ResidentCSVImport.parse(text, fileName: fileName, home: home, existing: existing)
            await MainActor.run {
                ob.importPreview = preview
                ob.importResult = nil
                ob.error = preview.rows.isEmpty ? "No rows found in \(fileName). Use the template columns." : nil
                if !preview.rows.isEmpty { ob.page = .residentsReview }
            }
        }
    }

    /// The bundled template as a dry run of the import — three example residents, no file picker.
    func importResidentsSample() {
        let ob = onboarding
        guard let home = ob.home(id: ob.importHomeId)?.careHome else {
            ob.error = "Choose the home these residents belong to."
            return
        }
        ob.importPreview = ResidentCSVImport.parse(ResidentCSVImport.templateCSV, fileName: "sample.csv", home: home, existing: carePatients)
        ob.importResult = nil
        ob.error = nil
        ob.page = .residentsReview
    }

    @MainActor
    @discardableResult
    func applyResidentImport() -> Bool {
        let ob = onboarding
        guard let preview = ob.importPreview else { return false }
        let profiles = preview.validRows.map { ResidentCSVImport.profile(from: $0, home: preview.home) }
        guard !profiles.isEmpty else {
            ob.error = "No rows can be imported — fix the problems in the spreadsheet and try again."
            return false
        }
        // Appending to the roster is enough: the sync observer stamps `updatedAt`, pushes the
        // residents through /sync/push and the other iPads pull them like any other edit.
        carePatients.append(contentsOf: profiles)
        ob.importResult = "\(profiles.count) resident\(profiles.count == 1 ? "" : "s") added to \(preview.home.name)" + (preview.skippedCount > 0 ? " · \(preview.skippedCount) skipped" : "") + ". Each shows on the roster with “discovery not yet run”."
        ob.importPreview = nil
        ob.error = nil
        ob.notice = nil   // the result callout on the import page says it, and stays
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await loadOrganisation()
        }
        return true
    }

    func discardResidentImport() {
        onboarding.importPreview = nil
        onboarding.error = nil
    }

    // MARK: Devices

    @MainActor
    @discardableResult
    func registerThisIPad() async -> Bool {
        let ob = onboarding
        let problems = ob.deviceProblems()
        if !problems.isEmpty { ob.report(problems); return false }
        guard let home = ob.home(id: ob.deviceHomeId) else { return false }
        let label = InputRules.tidy(ob.deviceLabel)
        return await runOnboardingCall("Couldn’t register this iPad.") {
            _ = try await OnboardingClient.registerDevice(DeviceBody(
                deviceId: AuthSession.deviceId,
                homeId: home.id,
                label: label,
                model: UIDevice.current.model,
                os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            ))
            ob.deviceLabel = ""
            ob.notice = "This iPad now belongs to \(home.name)."
            await self.loadOrganisation()
        }
    }

    @MainActor
    func removeDevice(_ device: OrgDevice) async {
        await runOnboardingCall("Couldn’t remove the iPad.") {
            try await OnboardingClient.removeDevice(id: device.id)
            self.onboarding.notice = "\(device.label) removed."
            await self.loadOrganisation()
        }
    }

    /// This iPad's registration, if any.
    func thisDevice() -> OrgDevice? {
        onboarding.devices.first { $0.id == AuthSession.deviceId.lowercased() }
    }

    // MARK: - Private

    /// Runs one backend action with the shared busy / error / notice handling. `true` when it finished.
    @MainActor
    @discardableResult
    private func runOnboardingCall(_ fallback: String, _ work: @escaping @MainActor () async throws -> Void) async -> Bool {
        let ob = onboarding
        guard !ob.isBusy else { return false }
        // Submitting puts the keyboard away so the result (and the page it lands on) is not left
        // behind a stale cursor.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        ob.isBusy = true
        ob.error = nil
        ob.notice = nil
        defer { ob.isBusy = false }
        do {
            try await work()
            return true
        } catch let error as APIError {
            ob.error = offlineAware(error, fallback: fallback)
        } catch {
            ob.error = fallback
        }
        return false
    }

    private func offlineAware(_ error: APIError, fallback: String) -> String {
        switch error {
        case .unreachable: return "You need to be online for this. Check the connection and try again."
        case .notConfigured: return "This iPad isn’t connected to a NoteStalgia backend."
        case .server(_, _, let message): return message ?? fallback
        default: return error.userMessage
        }
    }
}

extension SessionPOCState {
    /// From set-up straight to a home's roster (admins add residents through discovery there).
    func openRosterForHome(_ homeId: UUID) {
        guard assignedHomes().contains(where: { $0.id == homeId }) else { return }
        currentHomeId = homeId
        careHomeAdminWelcomeIsManual = false
        openRosterFromAdminDashboard()
    }
}
