import CryptoKit
import Foundation

/// Signed-in identity against the backend: tokens in the Keychain, the principal cached on disk so
/// the app can show the same account offline, and an offline verifier so a staff member who has
/// signed in online before can still sign in when the network is down. Owned by the coordinator;
/// everything here is `@MainActor` because it publishes into the auth store on completion.
@MainActor
final class AuthSession {
    static let shared = AuthSession()

    private static let currentAccountKey = "api.currentAccountId"
    private static let deviceIdKey = "api.deviceId"

    private(set) var currentPrincipal: Principal?

    /// Stable per-install id sent with sign-in and sync pushes (tie-breaks, outbox attribution).
    static let deviceId: String = {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) { return existing }
        let fresh = UUID().uuidString.lowercased()
        UserDefaults.standard.set(fresh, forKey: deviceIdKey)
        return fresh
    }()

    private init() {}

    // MARK: - Restore

    /// Reinstalls the token provider for the last signed-in account (used by sync on launch).
    func restore() {
        guard let id = UserDefaults.standard.string(forKey: Self.currentAccountKey),
              let accountId = UUID(uuidString: id),
              let principal = PrincipalCache.principal(accountId: accountId)
        else { return }
        currentPrincipal = principal
        Task { await installTokenProvider(for: accountId) }
    }

    // MARK: - Sign-in

    struct SignInRequest: Encodable {
        var email: String
        var pin: String
        var deviceId: String
    }

    func signIn(email: String, pin: String) async throws -> Principal {
        let pair: TokenPair = try await APIClient.shared.post(
            "auth/sign-in",
            body: SignInRequest(email: email, pin: pin, deviceId: Self.deviceId),
            authorized: false
        )
        await adopt(pair, pin: pin)
        return pair.principal
    }

    struct HouseholdSignUpRequest: Encodable {
        var name: String
        var email: String
        var relationship: HouseholdRelationship
        var pin: String
        var deviceId: String
    }

    func householdSignUp(name: String, email: String, relationship: HouseholdRelationship, pin: String) async throws -> Principal {
        let pair: TokenPair = try await APIClient.shared.post(
            "auth/household-signup",
            body: HouseholdSignUpRequest(name: name, email: email, relationship: relationship, pin: pin, deviceId: Self.deviceId),
            authorized: false
        )
        await adopt(pair, pin: pin)
        return pair.principal
    }

    /// Offline fallback: only an account that signed in online on this device, with the same PIN.
    func offlineSignIn(email: String, pin: String) -> Principal? {
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let principal = PrincipalCache.all().first(where: { $0.email.lowercased() == needle }),
              let stored = KeychainStore.get("verifier.\(principal.accountId.uuidString)"),
              stored == Self.verifier(pin: pin)
        else { return nil }
        currentPrincipal = principal
        UserDefaults.standard.set(principal.accountId.uuidString, forKey: Self.currentAccountKey)
        Task { await installTokenProvider(for: principal.accountId) }
        return principal
    }

    // MARK: - PIN reset

    struct ResetRequestResponse: Decodable {
        var message: String
        var devCode: String?
    }

    func requestPinReset(email: String) async throws -> ResetRequestResponse {
        try await APIClient.shared.post("auth/pin-reset/request", body: ["email": email], authorized: false)
    }

    func completePinReset(email: String, code: String, newPin: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.post(
            "auth/pin-reset/complete",
            body: ["email": email, "code": code, "newPin": newPin],
            authorized: false
        )
        // Any cached verifier for this email is now stale.
        let needle = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let principal = PrincipalCache.all().first(where: { $0.email.lowercased() == needle }) {
            KeychainStore.remove("verifier.\(principal.accountId.uuidString)")
        }
    }

    // MARK: - Sign-out / refresh

    func signOut() async {
        if let principal = currentPrincipal {
            let _: EmptyResponse? = try? await APIClient.shared.post("auth/sign-out", body: EmptyBody(), authorized: true)
            KeychainStore.remove("access.\(principal.accountId.uuidString)")
            KeychainStore.remove("refresh.\(principal.accountId.uuidString)")
        }
        currentPrincipal = nil
        UserDefaults.standard.removeObject(forKey: Self.currentAccountKey)
        await APIClient.shared.install(tokenProvider: nil)
    }

    /// Exchanges the refresh token; returns the new access token or `nil` when the session is gone.
    func refresh(accountId: UUID) async -> String? {
        guard let refreshToken = KeychainStore.get("refresh.\(accountId.uuidString)") else { return nil }
        do {
            let pair: TokenPair = try await APIClient.shared.post("auth/refresh", body: ["refreshToken": refreshToken], authorized: false)
            KeychainStore.set(pair.accessToken, for: "access.\(accountId.uuidString)")
            KeychainStore.set(pair.refreshToken, for: "refresh.\(accountId.uuidString)")
            PrincipalCache.store(pair.principal)
            currentPrincipal = pair.principal
            return pair.accessToken
        } catch {
            return nil
        }
    }

    /// Refreshes the cached principal (e.g. after a household registers its resident).
    @discardableResult
    func reloadPrincipal() async -> Principal? {
        guard let principal: Principal = try? await APIClient.shared.get("me") else { return nil }
        PrincipalCache.store(principal)
        currentPrincipal = principal
        return principal
    }

    // MARK: - Private

    private func adopt(_ pair: TokenPair, pin: String) async {
        let id = pair.principal.accountId
        KeychainStore.set(pair.accessToken, for: "access.\(id.uuidString)")
        KeychainStore.set(pair.refreshToken, for: "refresh.\(id.uuidString)")
        KeychainStore.set(Self.verifier(pin: pin), for: "verifier.\(id.uuidString)")
        PrincipalCache.store(pair.principal)
        currentPrincipal = pair.principal
        UserDefaults.standard.set(id.uuidString, forKey: Self.currentAccountKey)
        await installTokenProvider(for: id)
    }

    private func installTokenProvider(for accountId: UUID) async {
        let provider = APIClient.TokenProvider(
            accessToken: { KeychainStore.get("access.\(accountId.uuidString)") },
            refresh: { await AuthSession.shared.refresh(accountId: accountId) }
        )
        await APIClient.shared.install(tokenProvider: provider)
    }

    private static func verifier(pin: String) -> String {
        let salt: String
        if let existing = KeychainStore.get("verifier.salt") {
            salt = existing
        } else {
            salt = UUID().uuidString
            KeychainStore.set(salt, for: "verifier.salt")
        }
        let digest = SHA256.hash(data: Data("\(salt):\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct EmptyBody: Encodable {}

/// Principals learned from the backend, cached on disk so `CareAccountDirectory` can resolve the
/// signed-in account and its homes without a network round-trip (and offline).
enum PrincipalCache {
    private static var loaded: [UUID: Principal]?

    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("NoteStalgia/sync/accounts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func all() -> [Principal] {
        Array(load().values)
    }

    static func principal(accountId: UUID) -> Principal? {
        load()[accountId]
    }

    static func home(id: UUID) -> CareHome? {
        for principal in load().values {
            if let home = principal.careHomes.first(where: { $0.id == id }) { return home }
        }
        return nil
    }

    static func store(_ principal: Principal) {
        var cache = load()
        cache[principal.accountId] = principal
        loaded = cache
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = directory.appendingPathComponent("\(principal.accountId.uuidString).json")
        if let data = try? encoder.encode(principal) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func load() -> [UUID: Principal] {
        if let loaded { return loaded }
        var cache: [UUID: Principal] = [:]
        if let directory, let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file), let principal = try? decoder.decode(Principal.self, from: data) {
                    cache[principal.accountId] = principal
                }
            }
        }
        loaded = cache
        return cache
    }
}
