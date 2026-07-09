import UIKit

/// New-resident discovery pass — provisional profile id, age input, ordered snippet indices,
/// and the profile form drafted after the discovery pass completes.
final class NewResidentDiscoveryStore: ObservableObject {
    @Published var newResidentDiscoveryPatientId: UUID?
    @Published var newResidentAgeDraft: String = ""
    @Published var discoverySnippetOrder: [Int] = []
    @Published var newResidentProfileNameDraft: String = ""
    @Published var newResidentProfileAgeDraft: String = ""
    @Published var newResidentProfilePhoto: UIImage?
}

/// Discovery calibration pass — timed calm snippets with a traffic-light sentiment pick.
final class DiscoveryCalibrationStore: ObservableObject {
    @Published var discoverySnippetIndex: Int = 0
    @Published var discoveryResults: [DiscoverySnippetResult] = []
    @Published var discoveryPendingPick: DiscoveryTrafficSentiment?
}
