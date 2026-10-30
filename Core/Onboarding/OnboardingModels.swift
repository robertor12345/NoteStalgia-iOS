import Foundation

// MARK: - Organisation & home onboarding — wire shapes (contracts/openapi.yaml, "onboarding" tag)
//
// Dates travel as ISO-8601 strings and are formatted at display time (`OnboardingFormat`), ids as
// the lowercase strings the Worker stores. Nothing here is persisted on device.

/// The texts people accept when activating an organisation or an invite; versions are recorded
/// server-side as consent rows and re-asked when they change.
enum OnboardingConsent {
    static let dpaVersion = "2026-10"
    static let termsVersion = "2026-10"
    static var versions: [String: String] { ["dpa": dpaVersion, "terms": termsVersion] }
    static let summary = "NoteStalgia stores residents’ names, ages, music preferences and session notes for your organisation only, in the UK, and deletes them at the end of your retention period. Staff accounts are personal and must not be shared."
}

enum OrgRequesterRole: String, CaseIterable, Hashable {
    case registeredManager
    case operations
    case it
    case other

    var label: String {
        switch self {
        case .registeredManager: return "Manager"
        case .operations: return "Operations"
        case .it: return "IT"
        case .other: return "Other"
        }
    }
}

enum OrgHomesBand: String, CaseIterable, Hashable {
    case one = "1"
    case twoToFive = "2-5"
    case sixPlus = "6+"

    var label: String {
        switch self {
        case .one: return "One home"
        case .twoToFive: return "2–5 homes"
        case .sixPlus: return "6 or more"
        }
    }
}

struct OrgRequestBody: Encodable {
    var orgName: String
    var requesterName: String
    var email: String
    var phone: String?
    var requesterRole: String
    var homesBand: String
    var cqcProviderId: String?
    var notes: String?
    var consentVersion: String
}

struct OrgRequestResponse: Decodable {
    var message: String
    var requestId: String?
    var devCode: String?
}

struct OrgVerifyResponse: Decodable {
    var status: String
    var requestId: String?
    var message: String
    var activationCode: String?
}

struct InvitePreview: Decodable, Equatable {
    var orgName: String
    var role: SupervisorRole
    var homeNames: [String]
    var displayName: String?
    var expiresAt: String?
    var endsAt: String?
}

// MARK: Organisation

struct OrgAddress: Codable, Equatable {
    var line1: String?
    var line2: String?
    var town: String?
    var postcode: String?
    var country: String?
}

struct OrgSettings: Codable, Equatable {
    var idlePinMinutes: Int
    var homeLeadsMayInvite: Bool
    var supervisorsMayAddResidents: Bool
    var retentionDays: Int
    var trainingAcknowledgement: Bool

    static let `default` = OrgSettings(idlePinMinutes: 10, homeLeadsMayInvite: true, supervisorsMayAddResidents: true, retentionDays: 730, trainingAcknowledgement: false)
}

struct Organisation: Decodable, Equatable {
    var id: String
    var name: String
    var tradingName: String?
    var cqcProviderId: String?
    var address: OrgAddress?
    var settings: OrgSettings
    var plan: String
    var trialEndsAt: String?
    var region: String
    var seatsPerHome: Int?
    var status: String
    var createdAt: String
}

struct OrgDomain: Decodable, Equatable, Identifiable {
    var domain: String
    var method: String?
    var verifiedAt: String?
    var id: String { domain }
}

struct DNSRecord: Decodable, Equatable {
    var name: String
    var type: String
    var value: String
}

struct OrgPendingDomain: Decodable, Equatable, Identifiable {
    var domain: String
    var method: String?
    var expiresAt: String?
    /// Present for DNS claims: the TXT record the admin publishes (public by design).
    var record: DNSRecord?
    var id: String { domain }
}

enum DomainClaimMethod: String, CaseIterable, Hashable {
    case email
    case dns

    var label: String { self == .email ? "Email code" : "DNS record" }
}

struct OrgChecklist: Decodable, Equatable {
    var organisation: Bool
    var homes: Int
    var invitesPending: Int
    var invitesAccepted: Int
    var staffActive: Int
    var residents: Int
    var devices: Int
    var domainsVerified: Int
    var complete: Bool
}

struct OrganisationPayload: Decodable, Equatable {
    var organisation: Organisation
    var domains: [OrgDomain]
    var pendingDomains: [OrgPendingDomain]
    var checklist: OrgChecklist
}

struct OrganisationPatch: Encodable {
    var name: String?
    var tradingName: String?
    var cqcProviderId: String?
    var address: OrgAddress?
    var settings: OrgSettings?
}

struct DomainClaimResponse: Decodable {
    var domain: String
    var status: String
    var method: String?
    var sentTo: [String]?
    var record: DNSRecord?
    var expiresAt: String?
    var devCode: String?
}

struct OrgExportFile: Equatable {
    var url: URL
    var homeName: String
}

struct DomainStatusResponse: Decodable {
    var domain: String
    var status: String
}

// MARK: Homes

struct OrgHome: Decodable, Equatable, Identifiable {
    var id: String
    var tenantId: String
    var name: String
    var wings: [Principal.Home.Wing]
    var status: String
    var cqcLocationId: String?
    var address: OrgAddress?
    var capacity: Int?
    var residentCount: Int
    var staffCount: Int
    var createdAt: String

    var careHome: CareHome? {
        guard let id = UUID(uuidString: id), let tenant = UUID(uuidString: tenantId) else { return nil }
        return CareHome(id: id, organisationId: tenant, name: name, wings: wings.map { CareHomeWing(id: $0.id, name: $0.name) })
    }
}

struct HomesResponse: Decodable { var homes: [OrgHome] }
struct HomeResponse: Decodable { var home: OrgHome }

struct NewHomeLead: Encodable {
    var email: String?
    var displayName: String?
    var me: Bool
}

struct NewHomeBody: Encodable {
    var name: String
    var cqcLocationId: String?
    var capacity: Int?
    var address: OrgAddress?
    var wings: [String]
    var lead: NewHomeLead?
}

struct CreateHomeResponse: Decodable {
    var home: OrgHome
    var invite: OrgInvite?
}

// MARK: Invites and staff

struct OrgInvite: Decodable, Equatable, Identifiable {
    var id: String
    var email: String
    var displayName: String?
    var role: SupervisorRole
    var homeIds: [String]
    var endsAt: String?
    var expiresAt: String
    var status: String
    var invitedBy: String
    var createdAt: String
    var acceptedAt: String?
    /// Only on non-production backends (or the demo deployment): the code to hand over by hand.
    var code: String?
}

struct InvitesResponse: Decodable { var invites: [OrgInvite] }

struct InviteResponse: Decodable {
    var invite: OrgInvite
    var code: String?
    /// Soft seat-limit warnings; the invite still went out.
    var warnings: [String]?
}

struct NewInviteBody: Encodable {
    var email: String
    var displayName: String?
    var role: SupervisorRole
    var homeIds: [String]
    var endsAt: String?
}

struct BulkInviteBody: Encodable { var invites: [NewInviteBody] }

struct BulkInviteError: Decodable, Equatable, Identifiable {
    var email: String
    var message: String
    var id: String { email + message }
}

struct BulkInviteResponse: Decodable {
    var sent: [OrgInvite]
    var errors: [BulkInviteError]
    var warnings: [String]?
}

struct OrgAccount: Decodable, Equatable, Identifiable {
    var id: String
    var email: String
    var displayName: String
    var role: SupervisorRole
    var homeIds: [String]
    var status: String
    var invitedBy: String?
    var activatedAt: String?
    var accessEndsAt: String?
    var isDemo: Bool
    var createdAt: String
}

struct AccountsResponse: Decodable { var accounts: [OrgAccount] }
struct AccountResponse: Decodable { var account: OrgAccount }

struct DevCodeResponse: Decodable {
    var message: String
    var devCode: String?
}

// MARK: Devices and audit

struct OrgDevice: Decodable, Equatable, Identifiable {
    var id: String
    var homeId: String?
    var label: String
    var model: String?
    var os: String?
    var registeredBy: String?
    var firstSeenAt: String
    var lastSeenAt: String
}

struct DevicesResponse: Decodable { var devices: [OrgDevice] }
struct DeviceResponse: Decodable { var device: OrgDevice }

struct DeviceBody: Encodable {
    var deviceId: String
    var homeId: String
    var label: String
    var model: String?
    var os: String?
}

struct OrgAuditEntry: Decodable, Equatable, Identifiable {
    var id: String
    var actorAccountId: String?
    var actorKind: String
    var action: String
    var subjectKind: String?
    var subjectId: String?
    var at: String

    /// "invite.sent" → "Invite sent".
    var label: String {
        let parts = action.split(separator: ".").map(String.init)
        guard parts.count == 2 else { return action }
        let subject: String
        switch parts[0] {
        case "org": subject = "Organisation"
        case "home": subject = "Home"
        case "invite": subject = "Invite"
        case "account": subject = "Staff account"
        case "domain": subject = "Domain"
        case "device": subject = "iPad"
        default: subject = parts[0].capitalized
        }
        let verb = parts[1].replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).lowercased()
        return "\(subject) \(verb)"
    }
}

struct AuditResponse: Decodable { var entries: [OrgAuditEntry] }

struct EncodableEmpty: Encodable {}

// MARK: - Display helpers

enum OnboardingFormat {
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        return ISO8601DateFormatter.withFractional.date(from: iso) ?? plain.date(from: iso)
    }

    static func day(_ iso: String?) -> String {
        guard let date = date(iso) else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    static func dayAndTime(_ iso: String?) -> String {
        guard let date = date(iso) else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// "14 Willow Lane, Stockport, SK1 1AA", or a dash when nothing was given.
    static func address(_ address: OrgAddress?) -> String {
        let parts = [address?.line1, address?.line2, address?.town, address?.postcode]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    static func isoDay(_ date: Date) -> String {
        ISO8601DateFormatter.withFractional.string(from: date)
    }
}

extension SupervisorRole {
    var onboardingLabel: String {
        switch self {
        case .supervisor: return "Supervisor"
        case .homeLead: return "Home lead"
        case .orgAdmin: return "Organisation admin"
        case .household: return "Household"
        }
    }
}
