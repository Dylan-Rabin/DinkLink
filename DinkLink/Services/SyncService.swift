import Foundation
import SwiftData
import Observation

/// Orchestrates all Supabase sync:
///   1. Drains the offline `SyncQueueItem` queue (oldest-first).
///   2. Upserts the current `PlayerProfile` to `user_profiles`.
///   3. Uploads any dirty `StoredGameSession` rows to `game_sessions`.
///   4. Uploads any dirty `SavedLocation` rows to `saved_locations`.
///
/// Call `syncAll(...)` at app launch, on sign-in, and whenever
/// `NetworkMonitor.isConnected` flips to `true`.
@MainActor
@Observable
final class SyncService {
    private(set) var isSyncing = false
    private(set) var lastSyncError: String?
    private(set) var lastSyncDate: Date?

    @ObservationIgnored
    private let profileSync = UserProfileSyncService()
    @ObservationIgnored
    private let sessionSync = GameSessionSyncService()
    @ObservationIgnored
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// Full sync pass. Safe to call multiple times — re-entrant calls are dropped.
    func syncAll(
        context: ModelContext,
        authService: SupabaseAuthService
    ) async {
        guard !isSyncing else { return }
        guard let accessToken = authService.accessToken,
              let userID = authService.currentUserID else { return }

        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        do {
            // 1 ─ drain offline queue first (oldest operations get committed before new ones)
            try await drainQueue(context: context, accessToken: accessToken, userID: userID)

            // 2 ─ upsert user profile; 3 ─ sync sessions for that profile
            if let profile = fetchProfile(context: context, userID: userID) {
                try await profileSync.upsertProfile(profile, userID: userID, accessToken: accessToken)
                profile.supabaseProfileSynced = true

                // 3a ─ pull remote sessions the device doesn't have yet
                let remoteSessionIDs = try await pullRemoteSessions(
                    context: context,
                    profile: profile,
                    userID: userID,
                    accessToken: accessToken
                )

                // 3b ─ upload dirty local sessions (skip any that just came down)
                let dirtySessions = fetchDirtySessions(context: context, ownerProfileID: profile.id)
                    .filter { !remoteSessionIDs.contains($0.id) }
                for session in dirtySessions {
                    try await sessionSync.upsertSession(session, userID: userID, accessToken: accessToken)
                    session.isDirty = false
                }
            }

            // 4 ─ upload dirty saved locations
            let dirtyLocations = fetchDirtyLocations(context: context)
            for location in dirtyLocations {
                try await profileSync.upsertLocation(location, userID: userID, accessToken: accessToken)
                location.isDirty = false
                if location.supabaseID == nil {
                    location.supabaseID = location.id
                }
            }

            try context.save()
            lastSyncDate = .now
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    // MARK: - Offline queue

    /// Enqueues a write operation so it can be replayed when connectivity returns.
    func enqueue(
        operation: String,
        tableName: String,
        payload: some Encodable,
        context: ModelContext
    ) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let item = SyncQueueItem(
            operation: operation,
            tableName: tableName,
            payload: data
        )
        context.insert(item)
        try? context.save()
    }

    // MARK: - Private helpers

    @discardableResult
    private func drainQueue(
        context: ModelContext,
        accessToken: String,
        userID: UUID
    ) async throws -> Int {
        let descriptor = FetchDescriptor<SyncQueueItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let items = (try? context.fetch(descriptor)) ?? []
        guard !items.isEmpty else { return 0 }

        var drained = 0
        for item in items {
            do {
                try await replayQueueItem(item, accessToken: accessToken, userID: userID)
                context.delete(item)
                drained += 1
            } catch SyncError.requestFailed(let statusCode, _)
                where statusCode >= 400 && statusCode < 500 {
                // 4xx = bad payload — won't succeed on retry, discard it.
                context.delete(item)
            } catch {
                // 5xx or network error — stop draining, try again next sync.
                item.retryCount += 1
                break
            }
        }
        try? context.save()
        return drained
    }

    private func replayQueueItem(
        _ item: SyncQueueItem,
        accessToken: String,
        userID: UUID
    ) async throws {
        var request = URLRequest(
            url: SupabaseConfiguration.restURL.appending(path: item.tableName)
        )
        request.httpMethod = "POST"
        request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = item.payload

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw SyncError.requestFailed(
                statusCode: http.statusCode,
                message: String(data: data, encoding: .utf8)
            )
        }
    }

    // MARK: - SwiftData fetch helpers

    private func fetchProfile(context: ModelContext, userID: UUID) -> PlayerProfile? {
        let descriptor = FetchDescriptor<PlayerProfile>()
        let allProfiles = (try? context.fetch(descriptor)) ?? []
        // profile.id == auth UUID after the ownership simplification.
        return allProfiles.first { $0.id == userID }
            ?? allProfiles.first(where: \.completedOnboarding)
    }

    private func fetchDirtySessions(context: ModelContext, ownerProfileID: UUID) -> [StoredGameSession] {
        let profileID: UUID? = ownerProfileID
        var descriptor = FetchDescriptor<StoredGameSession>(
            predicate: #Predicate { $0.isDirty && $0.ownerProfileID == profileID }
        )
        descriptor.sortBy = [SortDescriptor(\.startDate, order: .forward)]
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchDirtyLocations(context: ModelContext) -> [SavedLocation] {
        var descriptor = FetchDescriptor<SavedLocation>(
            predicate: #Predicate { $0.isDirty }
        )
        descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Downloads remote sessions the device doesn't have yet and inserts them as
    /// non-dirty local records. Returns the set of remote IDs that were inserted
    /// so the upload step can skip re-uploading them.
    @discardableResult
    private func pullRemoteSessions(
        context: ModelContext,
        profile: PlayerProfile,
        userID: UUID,
        accessToken: String
    ) async throws -> Set<UUID> {
        let remotes = try await sessionSync.fetchSessions(userID: userID, accessToken: accessToken)
        guard !remotes.isEmpty else { return [] }

        // Build a set of IDs already stored locally (by local id or remoteID).
        let localDescriptor = FetchDescriptor<StoredGameSession>()
        let locals = (try? context.fetch(localDescriptor)) ?? []
        let localIDs = Set(locals.flatMap { [$0.id, $0.remoteID].compactMap { $0 } })

        var insertedIDs = Set<UUID>()
        for remote in remotes where !localIDs.contains(remote.id) {
            let session = remote.toStoredSession(ownerProfileID: profile.id)
            // Mark clean — it came from the server, no upload needed.
            session.isDirty = false
            session.remoteID = remote.id
            context.insert(session)
            insertedIDs.insert(remote.id)
        }
        return insertedIDs
    }
}
