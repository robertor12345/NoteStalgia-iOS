import UIKit

/// Shared care data — the resident roster and their session history. Nearly every domain in
/// the flow (roster, discovery, group sessions, sentiment feedback, admin analytics) reads or
/// appends to these two collections, so they live together rather than split further.
final class CareDataStore: ObservableObject {
    /// Seeded asynchronously at launch by `SessionPOCState.resetAllForFreshAppLaunch()` so the
    /// deterministic roster + demo history is built off the main thread (the launch overlay covers
    /// the brief empty window). Starts empty to avoid a synchronous main-thread build at store init.
    @Published var carePatients: [CarePatientProfile] = [] {
        didSet { dataRevision &+= 1 }
    }
    @Published var careSessionRecords: [CareSessionRecord] = [] {
        didSet {
            dataRevision &+= 1
            recordsByPatientCache = nil
        }
    }
    /// Custom portraits keyed by patient id (captured during profile setup).
    @Published var carePatientPortraitImages: [UUID: UIImage] = [:]

    /// Bumped on any roster/history change. Used as a cheap O(1) cache key for the roster and
    /// dashboard presentations instead of comparing the full patient/record arrays element-wise on
    /// every SwiftUI body pass.
    private(set) var dataRevision: Int = 0

    private var recordsByPatientCache: [UUID: [CareSessionRecord]]?

    /// Session history for one resident, sorted newest-first. Backed by an index built once per
    /// change to `careSessionRecords` — avoids filtering + sorting the whole array on every
    /// per-row roster lookup (previously O(residents × records) per render).
    func records(for patientId: UUID) -> [CareSessionRecord] {
        recordsByPatient()[patientId] ?? []
    }

    private func recordsByPatient() -> [UUID: [CareSessionRecord]] {
        if let cache = recordsByPatientCache { return cache }
        var grouped: [UUID: [CareSessionRecord]] = [:]
        for record in careSessionRecords {
            grouped[record.patientId, default: []].append(record)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.date > $1.date }
        }
        recordsByPatientCache = grouped
        return grouped
    }
}
