import Foundation

/// POC persistence for supervisor PIN overrides (simulates a credential store until production auth ships).
enum SupervisorCredentialStore {
    private static let overridesKey = "poc.supervisor.pin.overrides"

    /// Demo verification code shown on the reset screen — any registered work email + this code can set a new PIN.
    static let demoResetCode = "000000"

    static func effectivePIN(for account: SupervisorAccount) -> String {
        pinOverrides[account.id.uuidString] ?? account.pin
    }

    static func accountWithEffectivePIN(_ account: SupervisorAccount) -> SupervisorAccount {
        var copy = account
        copy.pin = effectivePIN(for: account)
        return copy
    }

    static func setPIN(_ pin: String, for accountId: UUID) {
        var overrides = pinOverrides
        overrides[accountId.uuidString] = pin
        pinOverrides = overrides
    }

    static func clearOverride(for accountId: UUID) {
        var overrides = pinOverrides
        overrides.removeValue(forKey: accountId.uuidString)
        pinOverrides = overrides
    }

    private static var pinOverrides: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: overridesKey)
        }
    }
}
