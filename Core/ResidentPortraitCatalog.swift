import os
import SwiftUI

/// Bundled portrait imagery for residents.
///
/// Twelve photographs of genuinely elderly people (originally sourced from Wikimedia Commons;
/// licensing is not a concern for this POC) ship in the asset catalog as `PortraitWoman01…06` and
/// `PortraitMan01…06`. Every resident is assigned one **deterministically**: the first name picks the
/// gendered pool and a stable (launch-independent) hash picks the photo, so the same resident always
/// shows the same face — on every screen, every launch, with no network and nothing to wait for.
/// A captured photo, when present, always wins.
///
/// Twelve faces across ~37 mock residents means repeats are expected in the POC.
///
/// **Pool order is part of the resident → face contract.** Reordering either array changes every
/// resident's face. `StableHash` must stay FNV-1a for the same reason.
enum ResidentPortraitCatalog {
    enum InferredGender {
        case feminine
        case masculine
    }

    private static let femininePortraits: [String] = [
        "PortraitWoman01", "PortraitWoman02", "PortraitWoman03",
        "PortraitWoman04", "PortraitWoman05", "PortraitWoman06",
    ]

    private static let masculinePortraits: [String] = [
        "PortraitMan01", "PortraitMan02", "PortraitMan03",
        "PortraitMan04", "PortraitMan05", "PortraitMan06",
    ]

    static var allAssetNames: [String] { femininePortraits + masculinePortraits }

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

    /// Deterministic bundled portrait for a resident.
    static func assetName(displayName: String) -> String {
        let pool = gender(forDisplayName: displayName) == .feminine ? femininePortraits : masculinePortraits
        return pool[StableHash.of(displayName) % pool.count]
    }

    private static func firstName(from displayName: String) -> String {
        let raw = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return raw.trimmingCharacters(in: CharacterSet.letters.inverted).lowercased()
    }

    // MARK: - Decoded-bitmap warm-up

    /// Display-ready bitmaps for all 12 portraits, decoded once off the main thread. With these warm,
    /// the first roster paint draws portraits with zero decode work — nothing appears late.
    private static let bitmaps = OSAllocatedUnfairLock<[String: UIImage]>(initialState: [:])
    @MainActor private static var warmTask: Task<Void, Never>?

    /// Idempotent; safe to call from launch warm-up and again from the welcome gate.
    @MainActor
    static func warmUp() async {
        if warmTask == nil {
            warmTask = Task.detached(priority: .userInitiated) {
                for name in allAssetNames {
                    guard let image = UIImage(named: name) else { continue }
                    let prepared = await image.byPreparingForDisplay() ?? image
                    bitmaps.withLock { $0[name] = prepared }
                }
            }
        }
        await warmTask?.value
    }

    @MainActor
    static func startWarmUp() {
        Task { await warmUp() }
    }

    static func decodedImage(named name: String) -> UIImage? {
        bitmaps.withLock { $0[name] }
    }
}

/// Circular resident portrait fill: captured photo wins, then the bundled portrait (pre-decoded when
/// warm; the same pixels either way, so nothing ever swaps). A neutral silhouette shows only for a
/// provisional resident who has no portrait yet. Callers apply their own frame, clip shape, and stroke.
struct ResidentPortraitFill: View {
    var assetName: String?
    var customImage: UIImage?

    var body: some View {
        if let customImage {
            Image(uiImage: customImage)
                .resizable()
                .scaledToFill()
        } else if let assetName, let bitmap = ResidentPortraitCatalog.decodedImage(named: assetName) {
            Image(uiImage: bitmap)
                .resizable()
                .scaledToFill()
        } else if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            ResidentPortraitPlaceholder()
        }
    }
}

private struct ResidentPortraitPlaceholder: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                BrandTheme.creamMid
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(BrandTheme.textTertiary.opacity(0.7))
                    .frame(width: geo.size.width * 0.62, height: geo.size.height * 0.62)
            }
        }
        .accessibilityHidden(true)
    }
}
