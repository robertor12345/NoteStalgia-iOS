import Foundation

// MARK: - Coordinator: sign-in, household sign-up and PIN reset through the backend
//
// With `-NoteStalgiaAPIBaseURL` set these go to the Worker (`AuthSession`); without it every call
// falls through to the in-memory POC validators so the offline demo behaves exactly as before.

extension SessionPOCState {
    var usesBackend: Bool { APIConfig.isConfigured }

    /// Sign in with the email + PIN on the form. Returns the message to show, or nil on success.
    @MainActor
    func signIn() async -> String? {
        guard usesBackend else { return completeSupervisorSignIn() }
        guard !auth.isAuthenticating else { return nil }
        let email = supervisorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pin = supervisorPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty { return fail("Enter your email.") }
        if !email.contains("@") { return fail("Enter a valid email address.") }
        if pin.count != SupervisorAuth.pinDigitCount { return fail("Enter your \(SupervisorAuth.pinDigitCount)-digit PIN.") }

        auth.isAuthenticating = true
        defer { auth.isAuthenticating = false }
        do {
            let principal = try await AuthSession.shared.signIn(email: email, pin: pin)
            adopt(principal)
            return nil
        } catch let error as APIError {
            if case .unreachable = error {
                if let principal = AuthSession.shared.offlineSignIn(email: email, pin: pin) {
                    adopt(principal)
                    return nil
                }
                return fail("Can’t reach NoteStalgia right now, and this account hasn’t signed in on this iPad before.")
            }
            return fail(error.userMessage)
        } catch {
            return fail("Sign-in failed. Try again.")
        }
    }

    /// Create a Care at home account from the sign-up form.
    @MainActor
    func signUpHousehold() async -> String? {
        guard usesBackend else { return completeHouseholdSignUp() }
        guard !auth.isAuthenticating else { return nil }
        let ui = householdUI
        let name = ui.signUpName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = ui.signUpEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func failSignUp(_ message: String) -> String {
            ui.signUpError = message
            return message
        }
        if name.isEmpty { return failSignUp("Enter your name.") }
        if !email.contains("@") || !email.contains(".") { return failSignUp("Enter a valid email address.") }
        if ui.signUpPIN.count != SupervisorAuth.pinDigitCount { return failSignUp("Choose a \(SupervisorAuth.pinDigitCount)-digit PIN.") }
        if ui.signUpPIN != ui.signUpConfirmPIN { return failSignUp("PINs don’t match. Enter the same PIN twice.") }

        auth.isAuthenticating = true
        defer { auth.isAuthenticating = false }
        do {
            let principal = try await AuthSession.shared.householdSignUp(
                name: name, email: email, relationship: ui.signUpRelationship, pin: ui.signUpPIN
            )
            ui.signUpError = nil
            ui.signUpPIN = ""
            ui.signUpConfirmPIN = ""
            adopt(principal)
            return nil
        } catch let error as APIError {
            if case .unreachable = error {
                return failSignUp("Can’t reach NoteStalgia right now. Try again when you’re back online.")
            }
            return failSignUp(error.userMessage)
        } catch {
            return failSignUp("Couldn’t create the account. Try again.")
        }
    }

    // MARK: PIN reset (three steps; the code is verified by the server at the end)

    @MainActor
    func pinResetSubmitEmail() async {
        guard usesBackend else { return submitSupervisorPinResetEmail() }
        let email = supervisorPinResetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if email.isEmpty { supervisorPinResetError = "Enter your email."; return }
        if !email.contains("@") { supervisorPinResetError = "Enter a valid email address."; return }
        auth.isAuthenticating = true
        defer { auth.isAuthenticating = false }
        do {
            let response = try await AuthSession.shared.requestPinReset(email: email)
            auth.pinResetDevCode = response.devCode
            supervisorPinResetError = nil
            supervisorPinResetStep = .verificationCode
            supervisorPinResetCode = ""
        } catch let error as APIError {
            supervisorPinResetError = error.userMessage
        } catch {
            supervisorPinResetError = "Couldn’t request a reset. Try again."
        }
    }

    @MainActor
    func pinResetSubmitCode() {
        guard usesBackend else { return submitSupervisorPinResetCode() }
        let sanitized = String(supervisorPinResetCode.filter(\.isWholeNumber).prefix(SupervisorAuth.pinDigitCount))
        guard sanitized.count == SupervisorAuth.pinDigitCount else {
            supervisorPinResetError = "Enter the \(SupervisorAuth.pinDigitCount)-digit verification code."
            return
        }
        supervisorPinResetError = nil
        supervisorPinResetStep = .newPIN
        supervisorPinResetNewPIN = ""
        supervisorPinResetConfirmPIN = ""
    }

    @MainActor
    func pinResetConfirm() async {
        guard usesBackend else { return submitSupervisorPinResetConfirm() }
        let newCode = String(supervisorPinResetNewPIN.filter(\.isWholeNumber).prefix(SupervisorAuth.pinDigitCount))
        let confirmCode = String(supervisorPinResetConfirmPIN.filter(\.isWholeNumber).prefix(SupervisorAuth.pinDigitCount))
        guard newCode.count == SupervisorAuth.pinDigitCount else {
            supervisorPinResetError = "Choose a new \(SupervisorAuth.pinDigitCount)-digit PIN."; return
        }
        guard newCode == confirmCode else {
            supervisorPinResetError = "PINs don’t match. Enter the same PIN twice."; return
        }
        let email = supervisorPinResetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        auth.isAuthenticating = true
        defer { auth.isAuthenticating = false }
        do {
            try await AuthSession.shared.completePinReset(email: email, code: supervisorPinResetCode, newPin: newCode)
            supervisorPinResetError = nil
            supervisorEmail = email
            supervisorPIN = ""
            supervisorPinResetSuccessMessage = "PIN updated. Sign in with your new PIN."
            supervisorPinResetStep = .complete
            auth.pinResetDevCode = nil
        } catch let error as APIError {
            supervisorPinResetError = error.userMessage
        } catch {
            supervisorPinResetError = "Couldn’t update the PIN. Try again."
        }
    }

    // MARK: - Private

    private func fail(_ message: String) -> String {
        supervisorSignInError = message
        return message
    }

    /// Routes a backend principal through the same sign-in path as the mock directory.
    @MainActor
    private func adopt(_ principal: Principal) {
        mirrorHouseholdAccount(from: principal)
        signInAsAccount(principal.supervisorAccount)
    }

    /// The household screens read `HouseholdCareAccount` (relationship, display name, resident id),
    /// so a backend household keeps a local mirror — never the PIN, and never for the demo account.
    private func mirrorHouseholdAccount(from principal: Principal) {
        guard principal.isHousehold,
              principal.accountId != HouseholdCare.demoAccountId,
              let homeId = principal.homes.first?.id
        else { return }
        let existing = HouseholdCareStore.account(id: principal.accountId)
        let mirror = HouseholdCareAccount(
            id: principal.accountId,
            email: principal.email,
            displayName: principal.displayName,
            relationship: principal.relationship ?? existing?.relationship ?? .familyMember,
            pin: "",
            homeId: homeId,
            residentId: principal.residentId ?? existing?.residentId,
            createdAt: existing?.createdAt ?? Date()
        )
        HouseholdCareStore.add(mirror)
    }
}
