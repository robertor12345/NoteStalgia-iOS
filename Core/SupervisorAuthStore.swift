import Foundation

enum SupervisorPinResetStep: Equatable {
    case email
    case verificationCode
    case newPIN
    case confirmPIN
    case complete
}

/// Supervisor sign-in + PIN reset storage — split out of `SessionPOCState` so this domain's
/// fields live together and can be reasoned about (or observed) independently of the rest of
/// the flow. `SessionPOCState` still owns all orchestration (phase transitions, cross-domain
/// resets); this store only holds the published fields.
final class SupervisorAuthStore: ObservableObject {
    @Published var supervisorEmail = ""
    @Published var supervisorPIN = ""
    @Published var isSignedIn = false
    @Published var pendingCareRosterAfterSignIn = false
    @Published var supervisorSignInError: String?
    @Published var signedInSupervisorId: UUID?

    @Published var pinResetActive = false
    @Published var pinResetStep: SupervisorPinResetStep = .email
    @Published var pinResetEmail = ""
    @Published var pinResetCode = ""
    @Published var pinResetNewPIN = ""
    @Published var pinResetConfirmPIN = ""
    @Published var pinResetError: String?
    @Published var pinResetSuccessMessage: String?
    var pinResetAccountId: UUID?
}
