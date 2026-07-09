import Foundation

/// POC gate for care-home supervisor access — work email + PIN, scoped to organisation & homes.
enum SupervisorAuth {
    static let pinDigitCount = PinInputSpec.digitCount

    static func validate(email: String, pin: String) -> (account: SupervisorAccount?, error: String?) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let code = pin.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedEmail.isEmpty else { return (nil, "Enter your work email.") }
        guard normalizedEmail.contains("@") else { return (nil, "Enter a valid work email address.") }
        guard code.count == pinDigitCount else {
            return (nil, "Enter your \(pinDigitCount)-digit PIN.")
        }

        guard let domain = normalizedEmail.split(separator: "@").last.map(String.init)?.lowercased() else {
            return (nil, "Enter a valid work email address.")
        }
        guard CareTenancyMockData.organisation.emailDomains.contains(where: { $0.lowercased() == domain }) else {
            let allowed = CareTenancyMockData.organisation.emailDomains.map { "@\($0)" }.joined(separator: ", ")
            return (nil, "Use your organisation email (\(allowed)).")
        }

        guard let account = CareTenancyMockData.supervisors.first(where: {
            $0.email.lowercased() == normalizedEmail
        }) else {
            return (nil, "Email or PIN didn’t match. Check your work email or reset your PIN below.")
        }

        let effectivePIN = SupervisorCredentialStore.effectivePIN(for: account)
        guard effectivePIN == code else {
            return (nil, "Email or PIN didn’t match. Check your work email or reset your PIN below.")
        }

        return (SupervisorCredentialStore.accountWithEffectivePIN(account), nil)
    }

    /// Step 1 — confirm the email belongs to a supervisor on this tenant.
    static func beginPinReset(email: String) -> (accountId: UUID?, error: String?) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedEmail.isEmpty else { return (nil, "Enter your work email.") }
        guard normalizedEmail.contains("@") else { return (nil, "Enter a valid work email address.") }

        guard let domain = normalizedEmail.split(separator: "@").last.map(String.init)?.lowercased() else {
            return (nil, "Enter a valid work email address.")
        }
        guard CareTenancyMockData.organisation.emailDomains.contains(where: { $0.lowercased() == domain }) else {
            let allowed = CareTenancyMockData.organisation.emailDomains.map { "@\($0)" }.joined(separator: ", ")
            return (nil, "Use your organisation email (\(allowed)).")
        }

        guard let account = CareTenancyMockData.supervisors.first(where: {
            $0.email.lowercased() == normalizedEmail
        }) else {
            return (nil, "No supervisor account found for that email. Try max@sunrise-care.co.uk or alex@sunrise-care.co.uk.")
        }

        return (account.id, nil)
    }

    /// Step 2 — POC email verification (production would send a one-time link or code).
    static func verifyPinResetCode(_ code: String) -> String? {
        let sanitized = String(code.filter(\.isWholeNumber).prefix(pinDigitCount))
        guard sanitized.count == pinDigitCount else {
            return "Enter the \(pinDigitCount)-digit verification code."
        }
        guard sanitized == SupervisorCredentialStore.demoResetCode else {
            return "That code didn’t match. In this demo, use \(SupervisorCredentialStore.demoResetCode)."
        }
        return nil
    }

    /// Step 3 — set a new PIN after verification.
    static func completePinReset(accountId: UUID, newPIN: String, confirmPIN: String) -> String? {
        let newCode = String(newPIN.filter(\.isWholeNumber).prefix(pinDigitCount))
        let confirmCode = String(confirmPIN.filter(\.isWholeNumber).prefix(pinDigitCount))

        guard newCode.count == pinDigitCount else {
            return "Choose a new \(pinDigitCount)-digit PIN."
        }
        guard confirmCode.count == pinDigitCount else {
            return "Confirm your new \(pinDigitCount)-digit PIN."
        }
        guard newCode == confirmCode else {
            return "PINs don’t match. Enter the same PIN twice."
        }
        guard CareTenancyMockData.supervisor(id: accountId) != nil else {
            return "Reset session expired. Start again."
        }

        SupervisorCredentialStore.setPIN(newCode, for: accountId)
        return nil
    }
}
