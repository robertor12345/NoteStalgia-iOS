import SwiftUI

/// Remote portrait imagery for residents.
///
/// The bundled `StockPortrait*` assets are reused across ~40 mock residents, so every profile looked
/// like one of three people. This catalog assigns each resident a **name-appropriate photograph of a
/// genuinely elderly person**, pulled from Wikimedia Commons (licensing is not a concern for this POC).
///
/// Selection is deterministic: the resident's display name picks the gendered pool and a stable
/// (launch-independent) hash picks the specific portrait, so the same resident always shows the same
/// face. A captured photo, when present, always wins; the bundled asset is the offline fallback.
enum ResidentPortraitCatalog {
    enum InferredGender {
        case feminine
        case masculine
    }

    /// Verified elderly-woman photographs (Wikimedia Commons).
    private static let femininePortraits: [URL] = urls([
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Elderly_Gambian_woman_face_portrait.jpg/960px-Elderly_Gambian_woman_face_portrait.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/2/27/Elderly_woman_writing_in_Oaxaca.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Tabu%2C_Myanmar%2C_Senior_woman.jpg/960px-Tabu%2C_Myanmar%2C_Senior_woman.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3d/Humano_De_Los_Andes_%28136091391%29.jpeg/960px-Humano_De_Los_Andes_%28136091391%29.jpeg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Older_Woman%2C_Dassanech%2C_Ethiopia_%2822892648376%29.jpg/960px-Older_Woman%2C_Dassanech%2C_Ethiopia_%2822892648376%29.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/a/a1/Portrait_of_a_Peasant_Woman_%2860ies%29._%287744724856%29.jpg",
    ])

    /// Verified elderly-man photographs (Wikimedia Commons).
    private static let masculinePortraits: [URL] = urls([
        "https://upload.wikimedia.org/wikipedia/commons/thumb/1/17/A_portrait_of_an_old_man_of_Bukhara.jpg/960px-A_portrait_of_an_old_man_of_Bukhara.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Old_man_reading_newspaper_early_in_the_morning_at_Basantapur-IMG_6800.jpg/960px-Old_man_reading_newspaper_early_in_the_morning_at_Basantapur-IMG_6800.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Bearded_man_smoking_pipe-3013924.jpg/960px-Bearded_man_smoking_pipe-3013924.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Masarwa_man_-_http-natavillage.org_-_Flickr_-_jonrawlinson.jpg/960px-Masarwa_man_-_http-natavillage.org_-_Flickr_-_jonrawlinson.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ef/Andean_Man.jpg/960px-Andean_Man.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/AlfredGessow8b.jpg/960px-AlfredGessow8b.jpg",
    ])

    /// First-name → gender map covering the mock roster (British/Irish given names of this generation).
    private static let genderByFirstName: [String: InferredGender] = [
        // Feminine
        "elena": .feminine, "margaret": .feminine, "dorothy": .feminine, "betty": .feminine,
        "jean": .feminine, "patricia": .feminine, "irene": .feminine, "gladys": .feminine,
        "rose": .feminine, "audrey": .feminine, "muriel": .feminine, "joan": .feminine,
        "ethel": .feminine, "phyllis": .feminine, "winifred": .feminine, "helen": .feminine,
        "grace": .feminine, "mary": .feminine, "vera": .feminine, "edith": .feminine,
        "doris": .feminine, "peggy": .feminine, "iris": .feminine, "hilda": .feminine,
        // Masculine
        "james": .masculine, "sam": .masculine, "arthur": .masculine, "harold": .masculine,
        "george": .masculine, "ronald": .masculine, "frank": .masculine, "albert": .masculine,
        "stanley": .masculine, "norman": .masculine, "cyril": .masculine, "keith": .masculine,
        "raymond": .masculine, "leslie": .masculine, "bernard": .masculine, "gordon": .masculine,
        "peter": .masculine, "david": .masculine, "john": .masculine, "walter": .masculine,
        "reg": .masculine, "reginald": .masculine, "eric": .masculine, "sidney": .masculine,
    ]

    static func gender(forDisplayName displayName: String) -> InferredGender {
        let first = firstName(from: displayName)
        if let known = genderByFirstName[first] {
            return known
        }
        // Fallback heuristic for unseen names, then a stable hash so it's at least deterministic.
        if let last = first.last, "ae".contains(last) {
            return .feminine
        }
        return StableHash.of(first).isMultiple(of: 2) ? .feminine : .masculine
    }

    /// Deterministic portrait for a resident. `nil` only if the pools are somehow empty.
    static func portraitURL(displayName: String) -> URL? {
        let pool = gender(forDisplayName: displayName) == .feminine ? femininePortraits : masculinePortraits
        guard pool.isEmpty == false else { return nil }
        return pool[StableHash.of(displayName) % pool.count]
    }

    private static func firstName(from displayName: String) -> String {
        let raw = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return raw.trimmingCharacters(in: CharacterSet.letters.inverted).lowercased()
    }

    private static func urls(_ strings: [String]) -> [URL] {
        strings.compactMap(URL.init(string:))
    }
}

/// Circular resident portrait fill: captured photo wins, then the remote elderly portrait, with the
/// bundled asset shown while loading / if the network image fails. Callers apply their own frame,
/// clip shape, and stroke.
struct ResidentPortraitFill: View {
    var remoteURL: URL?
    var assetName: String
    var customImage: UIImage?

    var body: some View {
        if let customImage {
            Image(uiImage: customImage)
                .resizable()
                .scaledToFill()
        } else if let remoteURL {
            AsyncImage(url: remoteURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            }
        } else {
            Image(assetName)
                .resizable()
                .scaledToFill()
        }
    }
}
