import Foundation

// MARK: - Wire shapes shared with the backend (contracts/openapi.yaml in NoteStalgia-Backend)

/// `GroupActivityTheme` has an associated value, so it is encoded as `{"kind": "genre", "genre": "jazz"}`,
/// `{"kind": "mixed"}` or `{"kind": "wholeHome"}` — the same shape Android decodes.
extension GroupActivityTheme {
    private enum CodingKeys: String, CodingKey {
        case kind
        case genre
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "genre":
            self = .genre(try container.decode(ResidentMusicGenre.self, forKey: .genre))
        case "mixed":
            self = .mixed
        case "wholeHome":
            self = .wholeHome
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown theme kind \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .genre(genre):
            try container.encode("genre", forKey: .kind)
            try container.encode(genre, forKey: .genre)
        case .mixed:
            try container.encode("mixed", forKey: .kind)
        case .wholeHome:
            try container.encode("wholeHome", forKey: .kind)
        }
    }
}

/// Current on-the-wire / on-disk schema version for resident and record JSON.
enum WireSchema {
    static let version = 1
}
