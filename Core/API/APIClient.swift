import Foundation

/// Typed failures from the backend. `unauthorized` triggers one token refresh and retry in the client;
/// `unreachable` is what the sync engine treats as "offline".
enum APIError: Error, Equatable {
    case notConfigured
    case unreachable(String)
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case throttled(retryAfterSeconds: Int?)
    case server(status: Int, code: String?, message: String?)
    case decoding(String)

    /// Human line for sign-in / sync status surfaces (never technical).
    var userMessage: String {
        switch self {
        case .notConfigured: return "No backend configured."
        case .unreachable: return "Can’t reach NoteStalgia right now — working offline."
        case .unauthorized: return "Please sign in again."
        case .forbidden: return "You don’t have access to that."
        case .notFound: return "That wasn’t found."
        case let .conflict(message): return message
        case .throttled: return "Too many requests — try again in a moment."
        case let .server(_, _, message): return message ?? "Something went wrong."
        case .decoding: return "Unexpected reply from the server."
        }
    }
}

/// Minimal JSON client over URLSession: ISO-8601 dates, camelCase keys, bearer auth with one
/// automatic refresh on 401, retry with backoff only for network-level failures (never for writes
/// that already reached the server — the sync layer re-sends idempotent upserts itself).
actor APIClient {
    struct ErrorBody: Decodable {
        var error: String?
        var message: String?
    }

    /// Provides the current access token and, on 401, a refreshed one. Installed by `AuthSession`.
    struct TokenProvider {
        var accessToken: @Sendable () async -> String?
        var refresh: @Sendable () async throws -> String?
    }

    static let shared = APIClient()

    private let session: URLSession
    private var tokenProvider: TokenProvider?

    nonisolated let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Fractional seconds, like the server's own timestamps, so `updatedAt` strings compare correctly.
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.withFractional.string(from: date))
        }
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    nonisolated let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.withFractional.date(from: value)
                ?? ISO8601DateFormatter.plain.date(from: value) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(value)"))
        }
        return d
    }()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 60
            config.waitsForConnectivity = false
            config.httpAdditionalHeaders = ["Accept": "application/json"]
            self.session = URLSession(configuration: config)
        }
    }

    func install(tokenProvider: TokenProvider?) {
        self.tokenProvider = tokenProvider
    }

    // MARK: - Requests

    func get<Response: Decodable>(_ path: String, query: [String: String] = [:], authorized: Bool = true) async throws -> Response {
        try await send(method: "GET", path: path, query: query, body: Optional<Data>.none, authorized: authorized)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body, authorized: Bool = true) async throws -> Response {
        try await send(method: "POST", path: path, query: [:], body: try encoder.encode(body), authorized: authorized)
    }

    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body, authorized: Bool = true) async throws -> Response {
        try await send(method: "PUT", path: path, query: [:], body: try encoder.encode(body), authorized: authorized)
    }

    /// No body in, nothing of interest out (204).
    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await send(method: "DELETE", path: path, query: [:], body: Optional<Data>.none, authorized: true)
    }

    /// Raw upload (portraits).
    func upload<Response: Decodable>(_ path: String, data: Data, contentType: String) async throws -> Response {
        try await send(method: "PUT", path: path, query: [:], body: data, contentType: contentType, authorized: true)
    }

    /// Raw authorised GET with a query (exports): the bytes and the suggested file name, if any.
    func downloadRaw(_ path: String, query: [String: String]) async throws -> (data: Data, fileName: String?) {
        var request = try makeRequest(method: "GET", path: path, query: query)
        if let token = await tokenProvider?.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await perform(request)
        guard (200 ... 299).contains(response.statusCode) else {
            throw mapError(status: response.statusCode, data: data, response: response)
        }
        let disposition = response.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let fileName = disposition.range(of: #"filename="([^"]+)""#, options: .regularExpression).map { range in
            String(disposition[range]).replacingOccurrences(of: "filename=\"", with: "").replacingOccurrences(of: "\"", with: "")
        }
        return (data, fileName)
    }

    /// Raw download (portraits); `nil` on 404.
    func download(_ path: String, ifNoneMatch: String? = nil) async throws -> (data: Data, etag: String?)? {
        var request = try makeRequest(method: "GET", path: path, query: [:])
        if let ifNoneMatch { request.setValue(ifNoneMatch, forHTTPHeaderField: "If-None-Match") }
        if let token = await tokenProvider?.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200: return (data, response.value(forHTTPHeaderField: "ETag"))
        case 304, 404: return nil
        default: throw mapError(status: response.statusCode, data: data, response: response)
        }
    }

    // MARK: - Core

    private func send<Response: Decodable>(
        method: String,
        path: String,
        query: [String: String],
        body: Data?,
        contentType: String = "application/json",
        authorized: Bool
    ) async throws -> Response {
        var request = try makeRequest(method: method, path: path, query: query)
        if let body {
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        var refreshed = false
        while true {
            if authorized, let token = await tokenProvider?.accessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await perform(request)
            if response.statusCode == 401, authorized, !refreshed, let provider = tokenProvider {
                refreshed = true
                if let newToken = try await provider.refresh(), !newToken.isEmpty {
                    continue
                }
                throw APIError.unauthorized
            }
            guard (200 ... 299).contains(response.statusCode) else {
                // Unauthenticated calls (sign-in, codes) carry the message the app should show on 401 / 403
                // (wrong PIN, suspended account, ended trial).
                if response.statusCode == 401 || response.statusCode == 403, !authorized {
                    let body = try? decoder.decode(ErrorBody.self, from: data)
                    throw APIError.server(status: 401, code: body?.error, message: body?.message)
                }
                throw mapError(status: response.statusCode, data: data, response: response)
            }
            if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
                return empty
            }
            do {
                return try decoder.decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        }
    }

    private func makeRequest(method: String, path: String, query: [String: String]) throws -> URLRequest {
        guard let base = APIConfig.baseURL else { throw APIError.notConfigured }
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.unreachable("bad url") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.unreachable("no http response") }
                return (data, http)
            } catch let error as APIError {
                throw error
            } catch {
                // Network-level failure only (DNS, refused, timeout): retry GETs a couple of times.
                attempt += 1
                let retriable = request.httpMethod == "GET" && attempt < 3
                guard retriable else { throw APIError.unreachable(error.localizedDescription) }
                try? await Task.sleep(nanoseconds: UInt64(400_000_000 * attempt))
            }
        }
    }

    private func mapError(status: Int, data: Data, response: HTTPURLResponse) -> APIError {
        let body = try? decoder.decode(ErrorBody.self, from: data)
        switch status {
        case 401: return .unauthorized
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict(body?.message ?? "That already exists.")
        case 429, 503:
            let retry = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            return .throttled(retryAfterSeconds: retry)
        default: return .server(status: status, code: body?.error, message: body?.message)
        }
    }
}

/// For routes that return no body of interest.
struct EmptyResponse: Decodable {
    init() {}
    init(from decoder: Decoder) throws {}
}

extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
