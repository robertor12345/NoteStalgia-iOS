import Foundation

/// Dev tool: `-NoteStalgiaExportSeed YES` writes the deterministic demo data (organisation, homes,
/// supervisors with their demo PINs, the Maple Lodge / Riverside roster, 14 days of history, the
/// group-activity history and the demo household) to `Documents/seed.json`. The backend's
/// `scripts/seed.ts` loads that file so the server demo equals the in-app demo. Record dates are
/// absolute; the seed script shifts them by (now − exportedAt) so history always ends today.
enum SeedExport {
    static let launchArgumentKey = "NoteStalgiaExportSeed"
    static var isRequested: Bool { UserDefaults.standard.bool(forKey: launchArgumentKey) }

    struct File: Encodable {
        struct Household: Encodable {
            var tenantId: UUID
            var account: HouseholdCareAccount
            var home: CareHome
            var residents: [CarePatientProfile]
            var records: [CareSessionRecord]
        }

        var schemaVersion = WireSchema.version
        var exportedAt: Date
        var organisation: CareOrganisation
        var homes: [CareHome]
        var supervisors: [SupervisorAccount]
        var residents: [CarePatientProfile]
        var sessions: [CareSessionRecord]
        var groupSessions: [GroupSessionRecord]
        var household: Household
    }

    /// Writes the file and returns its URL. Only the mock organisation and the demo household are
    /// exported — accounts created on this device are never part of the seed.
    @discardableResult
    static func run(patients: [CarePatientProfile], records: [CareSessionRecord], groupRecords: [GroupSessionRecord]) -> URL? {
        let mockHomeIds = Set(CareTenancyMockData.homes.map(\.id))
        let orgResidents = patients.filter { mockHomeIds.contains($0.homeId) && !$0.isProvisional }
        let orgResidentIds = Set(orgResidents.map(\.id))
        let demoAccount = HouseholdCareStore.demoAccount
        let demoResident = HouseholdCareStore.demoResident
        let householdRecords = records.filter { $0.patientId == demoResident.id }

        var file = File(
            exportedAt: Date(),
            organisation: CareTenancyMockData.organisation,
            homes: CareTenancyMockData.homes,
            supervisors: CareTenancyMockData.supervisors,
            residents: orgResidents,
            sessions: records.filter { orgResidentIds.contains($0.patientId) },
            groupSessions: groupRecords,
            household: File.Household(
                tenantId: HouseholdCare.organisationId,
                account: demoAccount,
                home: HouseholdCare.home(for: demoAccount),
                residents: [demoResident],
                records: householdRecords
            )
        )
        // Records carry the home they happened in on the wire.
        let homeByResident = Dictionary(uniqueKeysWithValues: orgResidents.map { ($0.id, $0.homeId) })
        file.sessions = file.sessions.map { var r = $0; r.homeId = homeByResident[r.patientId]; return r }
        file.household.records = file.household.records.map { var r = $0; r.homeId = demoAccount.homeId; return r }
        file.groupSessions = file.groupSessions.map { var g = $0; g.homeId = g.homeId ?? CareTenancyMockData.mapleLodgeId; return g }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(file),
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let url = documents.appendingPathComponent("seed.json")
        do {
            try data.write(to: url, options: .atomic)
            print("[SeedExport] wrote \(data.count) bytes to \(url.path)")
            return url
        } catch {
            print("[SeedExport] failed: \(error)")
            return nil
        }
    }
}
