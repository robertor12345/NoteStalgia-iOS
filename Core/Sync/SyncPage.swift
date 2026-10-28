import Foundation

/// One page of `GET /v1/homes/{homeId}/sync`. Entity arrays decode straight into the app's models
/// (the server stores the app's own JSON verbatim).
struct SyncPage: Decodable {
    struct Tombstone: Decodable {
        var kind: String
        var id: UUID
        var deletedAt: Date
    }

    var residents: [CarePatientProfile]
    var sessions: [CareSessionRecord]
    var groupSessions: [GroupSessionRecord]
    var tombstones: [Tombstone]
    var portraitEtags: [String: String]?
    var cursor: Int
    var hasMore: Bool
    var serverTime: Date
}

/// `POST /v1/sync/push`.
struct PushBatch: Encodable {
    var deviceId: String
    var clientTime: Date
    var residents: [CarePatientProfile]
    var sessions: [CareSessionRecord]
    var groupSessions: [GroupSessionRecord]
}

struct PushResult: Decodable {
    struct Item: Decodable {
        var kind: String
        var id: UUID
        var status: String
        var message: String?
    }

    var serverTime: Date
    var results: [Item]
}
