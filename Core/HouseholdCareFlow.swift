import Combine
import UIKit

/// Draft fields for the Care at home screens (sign-up, resident setup). Observed directly by those
/// screens and deliberately **not** forwarded by the coordinator, so typing never re-renders the
/// whole flow — the same arrangement as `SupervisorAuthStore`.
final class HouseholdFlowStore: ObservableObject {
    @Published var signUpName = ""
    @Published var signUpEmail = ""
    @Published var signUpRelationship: HouseholdRelationship = .familyMember
    @Published var signUpPIN = ""
    @Published var signUpConfirmPIN = ""
    @Published var signUpError: String?

    @Published var residentName = ""
    @Published var residentAge = ""
    @Published var residentNationality: ResidentNationality = .default
    @Published var residentPhoto: UIImage?
    @Published var residentSetupError: String?

    /// Set once the on-device household data has been merged into `careData`; until then a
    /// persistence pass would write an empty file over last session's data.
    var persistenceArmed = false
    var persistedPortraitIds: Set<UUID> = []

    func resetDrafts() {
        signUpName = ""
        signUpEmail = ""
        signUpRelationship = .familyMember
        signUpPIN = ""
        signUpConfirmPIN = ""
        signUpError = nil
        residentName = ""
        residentAge = ""
        residentNationality = .default
        residentPhoto = nil
        residentSetupError = nil
    }
}

// MARK: - Coordinator: Care at home

extension SessionPOCState {
    var isHouseholdAccount: Bool {
        currentSupervisorAccount()?.role == .household
    }

    /// Where "back to the start" lands for a signed-in carer: the roster for care-home staff, the
    /// single resident's home screen for a household account.
    func staffHubPhase() -> FlowPhase {
        isHouseholdAccount ? .householdHome : .carePatientList
    }

    func currentHouseholdAccount() -> HouseholdCareAccount? {
        guard let signedInSupervisorId else { return nil }
        return HouseholdCareStore.account(id: signedInSupervisorId)
    }

    /// The one resident registered to the signed-in household account.
    func householdResident() -> CarePatientProfile? {
        guard let account = currentHouseholdAccount() else { return nil }
        if let residentId = account.residentId, let resident = carePatient(id: residentId) {
            return resident
        }
        return CareRosterEngine.activeResidents(in: account.homeId, from: carePatients).first
    }

    // MARK: Sign-up

    func beginHouseholdSignUp() {
        householdUI.resetDrafts()
        // Carry over an email typed on the sign-in form unless it is a care-home work address.
        let typed = supervisorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty, !Self.isOrganisationEmail(typed) {
            householdUI.signUpEmail = typed
        }
        supervisorSignInError = nil
        transitionToPhase(.householdSignUp)
    }

    func cancelHouseholdSignUp() {
        householdUI.resetDrafts()
        transitionToPhase(.home)
    }

    /// Validates the sign-up form, stores the account on this device and signs it in. Returns the
    /// message to show when something is missing (also published on `householdUI.signUpError`).
    @discardableResult
    func completeHouseholdSignUp() -> String? {
        let ui = householdUI
        let name = ui.signUpName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = ui.signUpEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        func fail(_ message: String) -> String {
            ui.signUpError = message
            return message
        }

        if let problem = InputRules.personName(name, required: true, label: "Your name") { return fail(problem) }
        guard Self.looksLikeEmail(email) else { return fail("Enter a valid email address.") }
        if Self.isOrganisationEmail(email) {
            return fail("That is a \(CareTenancyMockData.organisation.name) work email — care-home staff sign in on the previous screen.")
        }
        if CareAccountDirectory.account(email: email) != nil {
            return fail("An account already exists for that email. Go back and sign in instead.")
        }
        guard ui.signUpPIN.count == SupervisorAuth.pinDigitCount else {
            return fail("Choose a \(SupervisorAuth.pinDigitCount)-digit PIN.")
        }
        guard ui.signUpPIN == ui.signUpConfirmPIN else {
            return fail("PINs don’t match. Enter the same PIN twice.")
        }

        let account = HouseholdCareAccount(
            id: UUID(),
            email: email,
            displayName: name,
            relationship: ui.signUpRelationship,
            pin: ui.signUpPIN,
            homeId: UUID(),
            residentId: nil,
            createdAt: Date()
        )
        HouseholdCareStore.add(account)
        ui.signUpError = nil
        ui.signUpPIN = ""
        ui.signUpConfirmPIN = ""
        signInAsAccount(HouseholdCare.supervisorAccount(for: account))
        return nil
    }

    // MARK: Resident registration

    /// Creates the household's resident from the setup form. With `startDiscovery` the listening
    /// discovery runs straight away (clips → calm surface → observation), otherwise the home
    /// screen opens with a starter playlist for the nationality's first genre.
    @discardableResult
    func completeHouseholdResidentSetup(startDiscovery: Bool) -> String? {
        let ui = householdUI
        func fail(_ message: String) -> String {
            ui.residentSetupError = message
            return message
        }
        guard var account = currentHouseholdAccount() else { return fail("Sign in again to continue.") }
        let name = InputRules.tidy(ui.residentName)
        if let problem = InputRules.personName(name, required: true, label: "Their name") { return fail(problem) }
        let ageText = ui.residentAge.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let age = Int(ageText), (55 ... 105).contains(age) else {
            return fail("Enter an age between 55 and 105.")
        }

        let resident = HouseholdCare.makeResident(
            name: name,
            age: age,
            nationality: ui.residentNationality,
            relationship: account.relationship,
            homeId: account.homeId
        )
        carePatients.append(resident)
        if let photo = ui.residentPhoto {
            carePatientPortraitImages[resident.id] = photo
        }
        account.residentId = resident.id
        HouseholdCareStore.update(account)

        ui.residentSetupError = nil
        ui.resetDrafts()
        selectedCarePatientId = resident.id
        if startDiscovery {
            startDiscoveryCalibration(for: resident.id)
        } else {
            transitionToPhase(.householdHome)
        }
        return nil
    }

    // MARK: Navigation

    func openHouseholdInsights() {
        transitionToPhase(.householdInsights)
    }

    func returnToHouseholdHome() {
        if let resident = householdResident() {
            selectedCarePatientId = resident.id
        }
        transitionToPhase(.householdHome)
    }

    /// Back from a resident profile: the roster for staff, the home screen for a household.
    func returnFromResidentDetail() {
        if isHouseholdAccount {
            transitionToPhase(.householdHome)
        } else {
            selectedCarePatientId = nil
            phase = .carePatientList
        }
    }

    func householdInsightsPresentation() -> ResidentInsightsPresentation? {
        guard let resident = householdResident() else { return nil }
        return CareHomeAnalytics.buildResidentInsights(
            resident: resident,
            records: recordsForPatient(resident.id),
            home: currentHome()
        )
    }

    // MARK: Persistence

    /// Writes household residents, their history and portraits back to the device whenever the
    /// shared care data changes. Debounced; a no-op until the seed has merged the stored data.
    func makeHouseholdPersistence() -> [AnyCancellable] {
        let data = Publishers.CombineLatest(careData.$carePatients, careData.$careSessionRecords)
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] patients, records in
                self?.persistHouseholdData(patients: patients, records: records)
            }
        let portraits = careData.$carePatientPortraitImages
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] images in
                self?.persistHouseholdPortraits(images)
            }
        return [data, portraits]
    }

    private func persistHouseholdData(patients: [CarePatientProfile], records: [CareSessionRecord]) {
        guard householdUI.persistenceArmed else { return }
        let homeIds = Set(HouseholdCareStore.allAccounts()
            .filter { $0.id != HouseholdCare.demoAccountId }
            .map(\.homeId))
        guard !homeIds.isEmpty else { return }
        let residents = patients.filter { homeIds.contains($0.homeId) && !$0.isProvisional }
        let residentIds = Set(residents.map(\.id))
        let history = records.filter { residentIds.contains($0.patientId) }
        let snapshot = HouseholdCareStore.Data(residents: residents, records: history)
        Task.detached(priority: .utility) {
            HouseholdCareStore.persist(snapshot)
        }
    }

    private func persistHouseholdPortraits(_ images: [UUID: UIImage]) {
        guard householdUI.persistenceArmed else { return }
        let residentIds = Set(carePatients
            .filter { $0.homeId != HouseholdCare.demoHomeId && HouseholdCareStore.isHouseholdHome($0.homeId) }
            .map(\.id))
        for (id, image) in images where residentIds.contains(id) && !householdUI.persistedPortraitIds.contains(id) {
            householdUI.persistedPortraitIds.insert(id)
            Task.detached(priority: .utility) {
                HouseholdCareStore.savePortrait(image, for: id)
            }
        }
    }

    // MARK: Helpers

    private static func looksLikeEmail(_ email: String) -> Bool { InputRules.isValidEmail(email) }

    private static func isOrganisationEmail(_ email: String) -> Bool {
        guard let domain = email.lowercased().split(separator: "@").last.map(String.init) else { return false }
        return CareTenancyMockData.organisation.emailDomains.contains { $0.lowercased() == domain }
    }
}
