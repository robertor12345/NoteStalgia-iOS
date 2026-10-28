import Combine
import Foundation
import UIKit

/// Keeps the shared care stores in step with the backend for the signed-in account's homes.
///
/// Pull: on activation the per-home cache is loaded into the stores at once (`isSeeded` flips so
/// the welcome gate can move on), then every home is pulled from its cursor and the cache rewritten.
/// Later pulls run on foreground and after pushes, never more often than `minimumPullInterval`.
/// Push: the engine observes the stores (debounced, the same pattern as the household persistence
/// sink), diffs them against the last-synced snapshot and sends changed entities as idempotent
/// upserts; the outbox lives on disk so nothing is lost across launches. Offline, everything keeps
/// working on the cached data and the outbox drains on the next successful pull.
@MainActor
final class SyncEngine: ObservableObject {
    enum Status: Equatable {
        case idle
        case syncing
        case offline
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var lastPullAt: Date?
    @Published private(set) var pendingPushCount = 0

    static let minimumPullInterval: TimeInterval = 60

    private let careData: CareDataStore
    private let groupSession: GroupSessionStore
    private var homeIds: [UUID] = []
    private var snapshots: [UUID: LocalCache.HomeSnapshot] = [:]
    private var pullTask: Task<Void, Never>?
    private var pushTask: Task<Void, Never>?
    private var observers: [AnyCancellable] = []
    private var outbox = Outbox()
    /// Entities the engine itself just wrote into the stores, so its own writes produce no diff.
    private var syncedResidents: [UUID: CarePatientProfile] = [:]
    private var syncedSessionIds: Set<UUID> = []
    private var syncedGroupIds: Set<UUID> = []
    private var authorAccountId: UUID?
    /// Called with the resident id after the backend accepted a signals batch for them.
    var onSignalsDelivered: ((UUID) -> Void)?

    init(careData: CareDataStore, groupSession: GroupSessionStore) {
        self.careData = careData
        self.groupSession = groupSession
    }

    // MARK: - Lifecycle

    /// Called from `signInAsAccount` when a backend is configured.
    func activate(homeIds: [UUID], accountId: UUID) {
        deactivate(keepCache: true)
        self.homeIds = homeIds
        self.authorAccountId = accountId
        outbox = Outbox.load(accountId: accountId)
        pendingPushCount = outbox.count

        var residents: [CarePatientProfile] = []
        var sessions: [CareSessionRecord] = []
        var groups: [GroupSessionRecord] = []
        var portraits: [UUID: UIImage] = [:]
        var hadCache = false
        for homeId in homeIds {
            let snapshot = LocalCache.load(homeId: homeId) ?? LocalCache.HomeSnapshot()
            snapshots[homeId] = snapshot
            if snapshot.cursor > 0 { hadCache = true }
            residents += snapshot.residents
            sessions += snapshot.sessions
            groups += snapshot.groupSessions
            for resident in snapshot.residents where snapshot.portraitEtags[resident.id.uuidString] != nil {
                if let image = LocalCache.loadPortrait(homeId: homeId, residentId: resident.id) {
                    portraits[resident.id] = image
                }
            }
        }
        replaceHomes(residents: residents, sessions: sessions, groups: groups)
        if !portraits.isEmpty {
            careData.carePatientPortraitImages.merge(portraits) { _, cached in cached }
        }
        if hadCache {
            careData.isSeeded = true
        }
        startObserving()
        pullTask = Task { [weak self] in
            await self?.pullAll()
            self?.careData.isSeeded = true
        }
    }

    func deactivate(keepCache: Bool = true) {
        pullTask?.cancel()
        pushTask?.cancel()
        observers.removeAll()
        homeIds = []
        snapshots = [:]
        syncedResidents = [:]
        syncedSessionIds = []
        syncedGroupIds = []
        authorAccountId = nil
        status = .idle
        if !keepCache { LocalCache.wipe() }
    }

    /// Queues a listening-telemetry batch for a resident; sent after the resident exists server-side.
    func enqueueSignals(residentId: UUID, batch: SignalBatch) {
        guard let accountId = authorAccountId else { return }
        Outbox.saveSignals(Outbox.SignalsPayload(residentId: residentId, batch: batch), accountId: accountId)
        outbox.add(.signals(batch.batchId))
        scheduleFlush()
    }

    /// Foreground / periodic: pull again if enough time has passed, then drain the outbox.
    func pullIfDue() {
        guard !homeIds.isEmpty else { return }
        if let last = lastPullAt, Date().timeIntervalSince(last) < Self.minimumPullInterval { return }
        pullTask?.cancel()
        pullTask = Task { [weak self] in await self?.pullAll() }
    }

    // MARK: - Pull

    private func pullAll() async {
        guard !homeIds.isEmpty else { return }
        status = .syncing
        var failed: String?
        for homeId in homeIds {
            do {
                try await pull(homeId: homeId)
            } catch let error as APIError {
                if case .unreachable = error {
                    status = .offline
                    return
                }
                failed = error.userMessage
            } catch {
                failed = error.localizedDescription
            }
            if Task.isCancelled { return }
        }
        lastPullAt = Date()
        status = failed.map { .failed($0) } ?? .idle
        await flushOutbox()
    }

    private func pull(homeId: UUID) async throws {
        var snapshot = snapshots[homeId] ?? LocalCache.HomeSnapshot()
        var pages = 0
        while pages < 50 {
            let page: SyncPage = try await APIClient.shared.get(
                "homes/\(homeId.uuidString.lowercased())/sync",
                query: ["since": String(snapshot.cursor), "limit": "200"]
            )
            apply(page, homeId: homeId, snapshot: &snapshot)
            pages += 1
            if !page.hasMore { break }
        }
        snapshot.lastPulledAt = Date()
        snapshots[homeId] = snapshot
        LocalCache.save(snapshot, homeId: homeId)
        await refreshPortraits(homeId: homeId, snapshot: snapshot)
    }

    private func apply(_ page: SyncPage, homeId: UUID, snapshot: inout LocalCache.HomeSnapshot) {
        let tombstoned = Set(page.tombstones.map(\.id))
        var residentsById = Dictionary(snapshot.residents.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for id in tombstoned { residentsById.removeValue(forKey: id) }
        for resident in page.residents {
            // A locally dirty resident that is newer than the server's copy keeps its edit (LWW).
            if let local = careData.carePatients.first(where: { $0.id == resident.id }),
               outbox.contains(.resident(local.id)),
               let localStamp = local.updatedAt, let remoteStamp = resident.updatedAt, localStamp > remoteStamp {
                residentsById[resident.id] = local
                continue
            }
            residentsById[resident.id] = resident
        }
        snapshot.residents = Array(residentsById.values).sorted { $0.displayName < $1.displayName }
        let knownSessions = Set(snapshot.sessions.map(\.id))
        snapshot.sessions += page.sessions.filter { !knownSessions.contains($0.id) }
        let knownGroups = Set(snapshot.groupSessions.map(\.id))
        snapshot.groupSessions += page.groupSessions.filter { !knownGroups.contains($0.id) }
        if let etags = page.portraitEtags {
            snapshot.portraitEtags.merge(etags) { _, new in new }
        }
        snapshot.cursor = max(snapshot.cursor, page.cursor)
        for id in tombstoned { outbox.remove(.resident(id)) }

        // Rebuild the stores for every active home from the snapshots (one assignment each).
        snapshots[homeId] = snapshot
        var residents: [CarePatientProfile] = []
        var sessions: [CareSessionRecord] = []
        var groups: [GroupSessionRecord] = []
        for id in homeIds {
            let s = snapshots[id] ?? LocalCache.HomeSnapshot()
            residents += s.residents
            sessions += s.sessions
            groups += s.groupSessions
        }
        replaceHomes(residents: residents, sessions: sessions, groups: groups)
    }

    /// Replaces the entities of the active homes in the shared stores, leaving anything from
    /// other homes (and provisional residents mid-discovery) untouched.
    private func replaceHomes(residents: [CarePatientProfile], sessions: [CareSessionRecord], groups: [GroupSessionRecord]) {
        let homes = Set(homeIds)
        let residentIds = Set(residents.map(\.id))
        syncedResidents = Dictionary(uniqueKeysWithValues: residents.map { ($0.id, $0) })
        syncedSessionIds = Set(sessions.map(\.id))
        syncedGroupIds = Set(groups.map(\.id))

        let keptResidents = careData.carePatients.filter { !homes.contains($0.homeId) || $0.isProvisional || ($0.updatedAt != nil && outbox.contains(.resident($0.id)) && !residentIds.contains($0.id)) }
        let nextResidents = keptResidents + residents
        if nextResidents != careData.carePatients { careData.carePatients = nextResidents }

        let keptSessions = careData.careSessionRecords.filter { record in
            guard let homeId = record.homeId else { return !residentIds.contains(record.patientId) }
            return !homes.contains(homeId) || outbox.contains(.session(record.id)) && !syncedSessionIds.contains(record.id)
        }
        let nextSessions = (keptSessions + sessions).sorted { $0.date > $1.date }
        if nextSessions != careData.careSessionRecords { careData.careSessionRecords = nextSessions }

        let keptGroups = groupSession.groupSessionRecords.filter { record in
            guard let homeId = record.homeId else { return false }
            return !homes.contains(homeId) || outbox.contains(.groupSession(record.id)) && !syncedGroupIds.contains(record.id)
        }
        let nextGroups = (keptGroups + groups).sorted { $0.date > $1.date }
        if nextGroups != groupSession.groupSessionRecords { groupSession.groupSessionRecords = nextGroups }
    }

    private func refreshPortraits(homeId: UUID, snapshot: LocalCache.HomeSnapshot) async {
        for (key, etag) in snapshot.portraitEtags {
            guard let residentId = UUID(uuidString: key) else { continue }
            let stampKey = "portrait.etag.\(residentId.uuidString)"
            if UserDefaults.standard.string(forKey: stampKey) == etag, careData.carePatientPortraitImages[residentId] != nil { continue }
            guard let result = try? await APIClient.shared.download("residents/\(residentId.uuidString.lowercased())/portrait"),
                  let image = UIImage(data: result.data)
            else { continue }
            LocalCache.savePortrait(result.data, homeId: homeId, residentId: residentId)
            UserDefaults.standard.set(result.etag ?? etag, forKey: stampKey)
            careData.carePatientPortraitImages[residentId] = image
        }
    }

    // MARK: - Push (observe the stores, diff, enqueue, flush)

    private func startObserving() {
        observers.removeAll()
        careData.$carePatients
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] patients in self?.noteResidents(patients) }
            .store(in: &observers)
        careData.$careSessionRecords
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] records in self?.noteSessions(records) }
            .store(in: &observers)
        groupSession.$groupSessionRecords
            .debounce(for: .seconds(0.8), scheduler: DispatchQueue.main)
            .sink { [weak self] records in self?.noteGroups(records) }
            .store(in: &observers)
        careData.$carePatientPortraitImages
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] images in self?.notePortraits(images) }
            .store(in: &observers)
    }

    private func noteResidents(_ patients: [CarePatientProfile]) {
        let homes = Set(homeIds)
        var changed = false
        for patient in patients where homes.contains(patient.homeId) && !patient.isProvisional {
            if let synced = syncedResidents[patient.id], synced == patient { continue }
            var stamped = patient
            if stamped.updatedAt == nil || syncedResidents[patient.id] != nil { stamped.updatedAt = Date() }
            stamped.schemaVersion = WireSchema.version
            outbox.add(.resident(patient.id))
            syncedResidents[patient.id] = stamped
            if stamped != patient, let index = careData.carePatients.firstIndex(where: { $0.id == patient.id }) {
                careData.carePatients[index] = stamped   // writes updatedAt back; next publish is a no-op diff
            }
            changed = true
        }
        if changed { scheduleFlush() }
    }

    private func noteSessions(_ records: [CareSessionRecord]) {
        let homes = Set(homeIds)
        var changed = false
        for record in records where !syncedSessionIds.contains(record.id) {
            guard let homeId = record.homeId, homes.contains(homeId) else { continue }
            outbox.add(.session(record.id))
            syncedSessionIds.insert(record.id)
            changed = true
        }
        if changed { scheduleFlush() }
    }

    private func noteGroups(_ records: [GroupSessionRecord]) {
        let homes = Set(homeIds)
        var changed = false
        for record in records where !syncedGroupIds.contains(record.id) {
            guard let homeId = record.homeId, homes.contains(homeId) else { continue }
            outbox.add(.groupSession(record.id))
            syncedGroupIds.insert(record.id)
            changed = true
        }
        if changed { scheduleFlush() }
    }

    private func notePortraits(_ images: [UUID: UIImage]) {
        var changed = false
        for (residentId, image) in images {
            guard let resident = careData.carePatients.first(where: { $0.id == residentId }),
                  homeIds.contains(resident.homeId), !resident.isProvisional
            else { continue }
            let stampKey = "portrait.local.\(residentId.uuidString)"
            let signature = "\(Int(image.size.width))x\(Int(image.size.height))"
            if UserDefaults.standard.string(forKey: stampKey) == signature { continue }
            UserDefaults.standard.set(signature, forKey: stampKey)
            outbox.add(.portrait(residentId))
            changed = true
        }
        if changed { scheduleFlush() }
    }

    private func scheduleFlush() {
        if let accountId = authorAccountId { outbox.save(accountId: accountId) }
        pendingPushCount = outbox.count
        pushTask?.cancel()
        pushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await self?.flushOutbox()
        }
    }

    private var isFlushing = false
    private var flushRequested = false

    /// Serialises flushes: a flush requested while one is in flight runs once it finishes, so an
    /// entry is never sent twice (the server dedupes, but it wastes the request budget).
    private func flushOutbox() async {
        if isFlushing { flushRequested = true; return }
        isFlushing = true
        defer { isFlushing = false }
        repeat {
            flushRequested = false
            await flushOutboxOnce()
        } while flushRequested
    }

    private func flushOutboxOnce() async {
        guard !outbox.isEmpty, !homeIds.isEmpty, APIConfig.isConfigured else { return }
        let homes = Set(homeIds)
        let residents = outbox.residentIds.compactMap { id in careData.carePatients.first { $0.id == id && homes.contains($0.homeId) && !$0.isProvisional } }
        let sessions = outbox.sessionIds.compactMap { id in careData.careSessionRecords.first { $0.id == id } }
        let groups = outbox.groupIds.compactMap { id in groupSession.groupSessionRecords.first { $0.id == id } }
        if !residents.isEmpty || !sessions.isEmpty || !groups.isEmpty {
            let batch = PushBatch(
                deviceId: AuthSession.deviceId,
                clientTime: Date(),
                residents: Array(residents.prefix(20)),
                sessions: Array(sessions.prefix(100)),
                groupSessions: Array(groups.prefix(100))
            )
            do {
                let result: PushResult = try await APIClient.shared.post("sync/push", body: batch)
                var residentApplied = false
                for item in result.results {
                    if item.kind == "resident", item.status == "applied" { residentApplied = true }
                    switch item.kind {
                    case "resident": outbox.remove(.resident(item.id))
                    case "session": outbox.remove(.session(item.id))
                    case "groupSession": outbox.remove(.groupSession(item.id))
                    default: break
                    }
                }
                status = .idle
                if residentApplied, let principal = AuthSession.shared.currentPrincipal, principal.isHousehold, principal.residentId == nil {
                    await AuthSession.shared.reloadPrincipal()
                }
            } catch let error as APIError {
                status = { if case .unreachable = error { return .offline } else { return .failed(error.userMessage) } }()
                if let accountId = authorAccountId { outbox.save(accountId: accountId) }
                pendingPushCount = outbox.count
                return
            } catch {
                return
            }
        }
        if let accountId = authorAccountId {
            var delivered: [UUID] = []
            for batchId in outbox.signalBatchIds {
                guard let payload = Outbox.loadSignals(accountId: accountId, batchId: batchId) else {
                    outbox.remove(.signals(batchId)); continue
                }
                // The resident must exist server-side first (a new resident's push may still be pending).
                if careData.carePatients.first(where: { $0.id == payload.residentId })?.isProvisional == true { continue }
                do {
                    try await MusicCatalogClient.sendSignals(residentId: payload.residentId, batch: payload.batch)
                    outbox.remove(.signals(batchId))
                    Outbox.removeSignals(accountId: accountId, batchId: batchId)
                    delivered.append(payload.residentId)
                } catch let error as APIError {
                    if case .notFound = error { continue }      // not pushed yet; try next flush
                    if case .unreachable = error { break }
                    outbox.remove(.signals(batchId))             // rejected for good: drop it
                    Outbox.removeSignals(accountId: accountId, batchId: batchId)
                } catch {
                    break
                }
            }
            for residentId in Set(delivered) { onSignalsDelivered?(residentId) }
        }
        for residentId in outbox.portraitIds {
            guard let image = careData.carePatientPortraitImages[residentId],
                  let data = image.syncJPEGData(maxDimension: 600, quality: 0.82)
            else { outbox.remove(.portrait(residentId)); continue }
            if let _: PortraitUploadResponse = try? await APIClient.shared.upload("residents/\(residentId.uuidString.lowercased())/portrait", data: data, contentType: "image/jpeg") {
                outbox.remove(.portrait(residentId))
            }
        }
        if let accountId = authorAccountId { outbox.save(accountId: accountId) }
        pendingPushCount = outbox.count
        if outbox.isEmpty, status == .syncing { status = .idle }
    }
}

struct PortraitUploadResponse: Decodable {
    var etag: String
}

/// Pending uploads, persisted per account so an edit made offline survives a relaunch.
struct Outbox: Codable {
    enum Entry: Codable, Hashable {
        case resident(UUID)
        case session(UUID)
        case groupSession(UUID)
        case portrait(UUID)
        /// A listening-telemetry batch; the payload lives next to the outbox as `signals/<batchId>.json`.
        case signals(UUID)
    }

    private(set) var entries: [Entry] = []

    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }
    var residentIds: [UUID] { entries.compactMap { if case let .resident(id) = $0 { return id } else { return nil } } }
    var sessionIds: [UUID] { entries.compactMap { if case let .session(id) = $0 { return id } else { return nil } } }
    var groupIds: [UUID] { entries.compactMap { if case let .groupSession(id) = $0 { return id } else { return nil } } }
    var portraitIds: [UUID] { entries.compactMap { if case let .portrait(id) = $0 { return id } else { return nil } } }
    var signalBatchIds: [UUID] { entries.compactMap { if case let .signals(id) = $0 { return id } else { return nil } } }

    func contains(_ entry: Entry) -> Bool { entries.contains(entry) }

    mutating func add(_ entry: Entry) {
        if !entries.contains(entry) { entries.append(entry) }
    }

    mutating func remove(_ entry: Entry) {
        entries.removeAll { $0 == entry }
    }

    private static func url(accountId: UUID) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("NoteStalgia/sync/accounts/\(accountId.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("outbox.json")
    }

    struct SignalsPayload: Codable {
        var residentId: UUID
        var batch: SignalBatch
    }

    static func signalsURL(accountId: UUID, batchId: UUID) -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("NoteStalgia/sync/accounts/\(accountId.uuidString)/signals", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(batchId.uuidString).json")
    }

    static func saveSignals(_ payload: SignalsPayload, accountId: UUID) {
        guard let url = signalsURL(accountId: accountId, batchId: payload.batch.batchId),
              let data = try? APIClient.shared.encoder.encode(payload)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func loadSignals(accountId: UUID, batchId: UUID) -> SignalsPayload? {
        guard let url = signalsURL(accountId: accountId, batchId: batchId), let data = try? Data(contentsOf: url) else { return nil }
        return try? APIClient.shared.decoder.decode(SignalsPayload.self, from: data)
    }

    static func removeSignals(accountId: UUID, batchId: UUID) {
        guard let url = signalsURL(accountId: accountId, batchId: batchId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func load(accountId: UUID) -> Outbox {
        guard let url = url(accountId: accountId), let data = try? Data(contentsOf: url) else { return Outbox() }
        return (try? JSONDecoder().decode(Outbox.self, from: data)) ?? Outbox()
    }

    func save(accountId: UUID) {
        guard let url = Self.url(accountId: accountId), let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
