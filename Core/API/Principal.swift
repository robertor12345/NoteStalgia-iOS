import Foundation

/// What the backend tells the app about the signed-in account (`GET /v1/me`, sign-in responses).
/// Never carries the PIN. Maps onto the POC's `SupervisorAccount` / `CareHome` so every screen keeps
/// working unchanged whether the account came from the server or from the offline mock directory.
struct Principal: Codable, Equatable {
    struct Home: Codable, Equatable {
        struct Wing: Codable, Equatable {
            var id: String
            var name: String
        }

        var id: UUID
        var tenantId: UUID
        var name: String
        var wings: [Wing]
    }

    var accountId: UUID
    var email: String
    var displayName: String
    var role: SupervisorRole
    var tenantId: UUID
    var tenantKind: String
    var relationship: HouseholdRelationship?
    var residentId: UUID?
    var homes: [Home]

    var isHousehold: Bool { tenantKind == "household" || role == .household }

    var supervisorAccount: SupervisorAccount {
        SupervisorAccount(
            id: accountId,
            organisationId: tenantId,
            email: email,
            displayName: displayName,
            role: role,
            homeIds: homes.map(\.id),
            pin: ""
        )
    }

    var careHomes: [CareHome] {
        homes.map { home in
            CareHome(
                id: home.id,
                organisationId: home.tenantId,
                name: home.name,
                wings: home.wings.map { CareHomeWing(id: $0.id, name: $0.name) }
            )
        }
    }
}

struct TokenPair: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresIn: Int
    var principal: Principal
}
