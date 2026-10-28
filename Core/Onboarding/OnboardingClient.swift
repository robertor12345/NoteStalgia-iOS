import Foundation

/// The onboarding and organisation-administration routes (`/auth/org-*`, `/auth/invite/*`,
/// `/orgs/me`, `/homes`, `/invites`, `/accounts`, `/devices`). Public calls carry no token; the
/// rest ride on the signed-in account's bearer token through `APIClient`.
enum OnboardingClient {
    // MARK: Public (sign-in screen)

    static func requestWorkspace(_ body: OrgRequestBody) async throws -> OrgRequestResponse {
        try await APIClient.shared.post("auth/org-request", body: body, authorized: false)
    }

    static func verifyRequest(email: String, code: String) async throws -> OrgVerifyResponse {
        try await APIClient.shared.post("auth/org-request/verify", body: ["email": email, "code": code], authorized: false)
    }

    static func previewInvite(email: String, code: String) async throws -> InvitePreview {
        try await APIClient.shared.get("auth/invite/preview", query: ["email": email, "code": code], authorized: false)
    }

    // MARK: Organisation

    static func organisation() async throws -> OrganisationPayload {
        try await APIClient.shared.get("orgs/me")
    }

    static func updateOrganisation(_ patch: OrganisationPatch) async throws -> OrganisationPayload {
        try await APIClient.shared.put("orgs/me", body: patch)
    }

    static func claimDomain(_ domain: String, method: DomainClaimMethod) async throws -> DomainClaimResponse {
        try await APIClient.shared.post("orgs/me/domains", body: ["domain": domain, "method": method.rawValue])
    }

    /// A home's residents (CSV), sessions (CSV) or everything (JSON) as a file in the temporary directory.
    static func export(homeId: String, format: String, kind: String) async throws -> URL {
        let (data, fileName) = try await APIClient.shared.downloadRaw("orgs/me/export", query: ["homeId": homeId, "format": format, "kind": kind])
        let name = fileName ?? "export-\(kind).\(format)"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NoteStalgiaExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func verifyDomain(_ domain: String, code: String) async throws -> DomainStatusResponse {
        try await APIClient.shared.post("orgs/me/domains/\(domain)/verify", body: ["code": code])
    }

    static func removeDomain(_ domain: String) async throws {
        try await APIClient.shared.delete("orgs/me/domains/\(domain)")
    }

    // MARK: Homes

    static func homes() async throws -> HomesResponse {
        try await APIClient.shared.get("homes")
    }

    static func createHome(_ body: NewHomeBody) async throws -> CreateHomeResponse {
        try await APIClient.shared.post("homes", body: body)
    }

    static func archiveHome(id: String) async throws -> HomeResponse {
        try await APIClient.shared.post("homes/\(id)/archive", body: EncodableEmpty())
    }

    // MARK: Invites

    static func invites() async throws -> InvitesResponse {
        try await APIClient.shared.get("invites")
    }

    static func sendInvite(_ body: NewInviteBody) async throws -> InviteResponse {
        try await APIClient.shared.post("invites", body: body)
    }

    static func sendInvites(_ bodies: [NewInviteBody]) async throws -> BulkInviteResponse {
        try await APIClient.shared.post("invites/bulk", body: BulkInviteBody(invites: bodies))
    }

    static func resendInvite(id: String) async throws -> InviteResponse {
        try await APIClient.shared.post("invites/\(id)/resend", body: EncodableEmpty())
    }

    static func revokeInvite(id: String) async throws {
        try await APIClient.shared.delete("invites/\(id)")
    }

    // MARK: Staff

    static func accounts() async throws -> AccountsResponse {
        try await APIClient.shared.get("orgs/me/accounts")
    }

    enum AccountAction: String { case suspend, restore, remove }

    static func accountAction(id: String, _ action: AccountAction) async throws -> AccountResponse {
        try await APIClient.shared.post("accounts/\(id)/\(action.rawValue)", body: EncodableEmpty())
    }

    static func adminPinReset(id: String) async throws -> DevCodeResponse {
        try await APIClient.shared.post("accounts/\(id)/pin-reset", body: EncodableEmpty())
    }

    // MARK: Devices and audit

    static func devices() async throws -> DevicesResponse {
        try await APIClient.shared.get("devices")
    }

    static func registerDevice(_ body: DeviceBody) async throws -> DeviceResponse {
        try await APIClient.shared.post("devices", body: body)
    }

    static func removeDevice(id: String) async throws {
        try await APIClient.shared.delete("devices/\(id)")
    }

    static func audit(limit: Int = 60) async throws -> AuditResponse {
        try await APIClient.shared.get("orgs/me/audit", query: ["limit": String(limit)])
    }
}
