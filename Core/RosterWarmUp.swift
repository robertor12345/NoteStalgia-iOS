import Combine
import Foundation

/// Readiness gate behind the post-sign-in welcome screens.
///
/// The welcome is a deliberate breath, so it always dwells for a minimum; but it only moves on once
/// the things the next screen paints are actually ready (roster seeded off-main, resident portraits
/// decoded, presentation caches warm). A maximum dwell guarantees it never hangs — on timeout the
/// roster shows its own loading state instead. Nothing here blocks the main thread; the gate only
/// suspends while detached work finishes.
@MainActor
enum RosterWarmUp {
    enum Outcome {
        case ready
        case timedOut
    }

    /// Hard cap — move on even if something upstream never finishes.
    static let maximumDwell: TimeInterval = 6
    static let rosterMinimumDwell: TimeInterval = 2.2
    static let adminMinimumDwell: TimeInterval = 2.8
    /// Past this, the welcome screen says what it is waiting for.
    static let longWaitHintDelay: TimeInterval = 2.6

    static func awaitRosterReady(state: SessionPOCState, start: Date) async -> Outcome {
        await gate(start: start, minimum: rosterMinimumDwell) {
            await awaitSeeded(state.careData)
            await ResidentPortraitCatalog.warmUp()
            guard !Task.isCancelled else { return }
            // Fill `rosterPresentationCache` so the roster's first body pass is a cache hit.
            _ = state.rosterPresentation()
        }
    }

    static func awaitAdminReady(state: SessionPOCState, start: Date) async -> Outcome {
        await gate(start: start, minimum: adminMinimumDwell) {
            await awaitSeeded(state.careData)
            guard !Task.isCancelled else { return }
            _ = state.careHomeDashboardPresentation()
            _ = state.careHomeSentimentOverview()
        }
    }

    // MARK: - Internals

    /// Races `conditions` against `maximumDwell`, then tops the dwell up to `minimum` (measured from
    /// `start`, so time already spent counts).
    private static func gate(
        start: Date,
        minimum: TimeInterval,
        conditions: @escaping @MainActor () async -> Void
    ) async -> Outcome {
        let outcome = await withTaskGroup(of: Outcome.self) { group -> Outcome in
            group.addTask { @MainActor in
                await conditions()
                return .ready
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(maximumDwell))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
        let remaining = minimum - Date().timeIntervalSince(start)
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        return outcome
    }

    /// Returns once `seedCareDataOffMain` has published the roster and history (both land on the
    /// main actor in one block, so waiting for the patients is enough in practice; records are
    /// checked too for safety).
    private static func awaitSeeded(_ careData: CareDataStore) async {
        if careData.carePatients.isEmpty {
            for await patients in careData.$carePatients.values where !patients.isEmpty {
                break
            }
        }
        if careData.careSessionRecords.isEmpty {
            for await records in careData.$careSessionRecords.values where !records.isEmpty {
                break
            }
        }
    }
}
