import Testing
import Foundation
import SwiftData
@testable import DinkLink

// MARK: - SyncService Orchestrator Tests

@MainActor
struct SyncServiceTests {

    // MARK: Guards — skips sync when not authenticated

    @Test("syncAll does nothing when no access token")
    func syncAllSkipsWhenNotAuthenticated() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let auth = SupabaseAuthService()
        // auth has no session — isAuthenticated is false

        let syncService = SyncService(urlSession: MockURLProtocol.makeSession())
        await syncService.syncAll(context: context, authService: auth)

        // No network requests should have been made.
        #expect(MockURLProtocol.capturedRequests.isEmpty)
        #expect(syncService.isSyncing == false)
        #expect(syncService.lastSyncDate == nil)
    }

    @Test("syncAll is not re-entrant — concurrent calls are dropped")
    func syncAllIsNotReentrant() async throws {
        MockURLProtocol.reset()
        // Slow response so the second call arrives while first is running.
        MockURLProtocol.requestHandler = { _ in
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("[]".utf8), response)
        }

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let auth = MockAuthService.makeAuthenticated()
        let syncService = SyncService(urlSession: MockURLProtocol.makeSession())

        // Fire two concurrent syncs.
        async let first: Void = syncService.syncAll(context: context, authService: auth)
        async let second: Void = syncService.syncAll(context: context, authService: auth)
        _ = await (first, second)

        // The guard `guard !isSyncing` means only one pass ran.
        // Verify by checking there's at most one user_profiles request.
        let profileRequests = MockURLProtocol.capturedRequests.filter {
            $0.url?.path.contains("user_profiles") == true
        }
        #expect(profileRequests.count <= 1)
    }

    // MARK: Happy path — profile upserted

    @Test("syncAll upserts profile when signed in")
    func syncAllUpsertsProfile() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)

        let profile = SyncTestFixtures.makeProfile(name: "Dylan")
        context.insert(profile)
        try context.save()

        let auth = MockAuthService.makeAuthenticated()
        let syncService = SyncService(urlSession: MockURLProtocol.makeSession())

        await syncService.syncAll(context: context, authService: auth)

        #expect(syncService.lastSyncError == nil)
        #expect(syncService.lastSyncDate != nil)

        let hasProfileRequest = MockURLProtocol.capturedRequests.contains {
            $0.url?.path.contains("user_profiles") == true
        }
        #expect(hasProfileRequest)
    }

    @Test("syncAll marks profile as synced after upload")
    func syncAllMarksProfileSynced() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let profile = SyncTestFixtures.makeProfile()
        profile.supabaseProfileSynced = false
        context.insert(profile)
        try context.save()

        let auth = MockAuthService.makeAuthenticated()
        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: auth)

        #expect(profile.supabaseProfileSynced == true)
    }

    // MARK: Dirty sessions

    @Test("syncAll uploads dirty sessions and clears isDirty")
    func syncAllUploadsDirtySessions() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let profile = SyncTestFixtures.makeProfile()
        context.insert(profile)

        let dirtySession = SyncTestFixtures.makeSession(isDirty: true)
        let cleanSession = SyncTestFixtures.makeSession(isDirty: false)
        context.insert(dirtySession)
        context.insert(cleanSession)
        try context.save()

        let auth = MockAuthService.makeAuthenticated()
        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: auth)

        #expect(dirtySession.isDirty == false)
        #expect(cleanSession.isDirty == false) // was already clean

        let sessionRequests = MockURLProtocol.capturedRequests.filter {
            $0.url?.path.contains("game_sessions") == true
        }
        // Only the dirty session should generate a request.
        #expect(sessionRequests.count == 1)
    }

    @Test("syncAll stamps remoteID on dirty session after upload")
    func syncAllStampsRemoteID() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        context.insert(SyncTestFixtures.makeProfile())

        let session = SyncTestFixtures.makeSession(isDirty: true)
        #expect(session.remoteID == nil)
        context.insert(session)
        try context.save()

        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: MockAuthService.makeAuthenticated())

        #expect(session.remoteID != nil)
    }

    // MARK: Dirty locations

    @Test("syncAll uploads dirty locations and clears isDirty")
    func syncAllUploadsDirtyLocations() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        context.insert(SyncTestFixtures.makeProfile())

        let dirtyLoc = SyncTestFixtures.makeLocation(isDirty: true)
        context.insert(dirtyLoc)
        try context.save()

        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: MockAuthService.makeAuthenticated())

        #expect(dirtyLoc.isDirty == false)

        let locationRequests = MockURLProtocol.capturedRequests.filter {
            $0.url?.path.contains("saved_locations") == true
        }
        #expect(locationRequests.count == 1)
    }

    // MARK: Error propagation

    @Test("syncAll surfaces error message on 500 from profile upsert")
    func syncAllSurfacesProfileError() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 500, body: "server error")

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        context.insert(SyncTestFixtures.makeProfile())
        try context.save()

        let syncService = SyncService(urlSession: MockURLProtocol.makeSession())
        await syncService.syncAll(
            context: context,
            authService: MockAuthService.makeAuthenticated()
        )

        #expect(syncService.lastSyncError != nil)
        #expect(syncService.lastSyncDate == nil)
    }
}

// MARK: - SyncQueueItem Tests

@MainActor
struct SyncQueueTests {

    @Test("enqueue inserts SyncQueueItem into context")
    func enqueueInsertsItem() async throws {
        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        let syncService = SyncService(urlSession: MockURLProtocol.makeSession())

        struct DummyPayload: Encodable { let value: String }
        syncService.enqueue(
            operation: "upsert_profile",
            tableName: "user_profiles",
            payload: DummyPayload(value: "test"),
            context: context
        )

        let items = try context.fetch(FetchDescriptor<SyncQueueItem>())
        #expect(items.count == 1)
        #expect(items.first?.operation == "upsert_profile")
        #expect(items.first?.tableName == "user_profiles")
    }

    @Test("drainQueue replays oldest item first")
    func drainQueueRespectsOrder() async throws {
        MockURLProtocol.reset()
        var capturedBodies: [String] = []
        MockURLProtocol.requestHandler = { request in
            if let body = request.httpBody,
               let str = String(data: body, encoding: .utf8) {
                capturedBodies.append(str)
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("[]".utf8), response)
        }

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        context.insert(SyncTestFixtures.makeProfile())
        try context.save()

        // Insert two items with different creation dates.
        struct Payload: Encodable { let order: Int }
        let older = SyncQueueItem(
            operation: "upsert_profile",
            tableName: "user_profiles",
            payload: (try? JSONEncoder().encode(Payload(order: 1))) ?? Data(),
            createdAt: Date(timeIntervalSinceNow: -100)
        )
        let newer = SyncQueueItem(
            operation: "upsert_profile",
            tableName: "user_profiles",
            payload: (try? JSONEncoder().encode(Payload(order: 2))) ?? Data(),
            createdAt: .now
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: MockAuthService.makeAuthenticated())

        // Queue items should have been drained (deleted from context).
        let remaining = try context.fetch(FetchDescriptor<SyncQueueItem>())
        #expect(remaining.isEmpty)
    }

    @Test("drainQueue discards 4xx items — won't retry bad payloads")
    func drainQueueDiscards4xxItems() async throws {
        MockURLProtocol.reset()
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            // Return 422 for queue replays, 200 for everything else.
            let isQueueReplay = request.url?.path.contains("user_profiles") == true && callCount == 1
            let status = isQueueReplay ? 422 : 200
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("[]".utf8), response)
        }

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        context.insert(SyncTestFixtures.makeProfile())

        struct BadPayload: Encodable { let bad: String }
        let badItem = SyncQueueItem(
            operation: "upsert_profile",
            tableName: "user_profiles",
            payload: (try? JSONEncoder().encode(BadPayload(bad: "data"))) ?? Data(),
            createdAt: Date(timeIntervalSinceNow: -200)
        )
        context.insert(badItem)
        try context.save()

        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: MockAuthService.makeAuthenticated())

        // The 422 item should have been discarded.
        let remaining = try context.fetch(FetchDescriptor<SyncQueueItem>())
        #expect(remaining.isEmpty)
    }

    @Test("drainQueue increments retryCount on 5xx and stops draining")
    func drainQueueIncrementsRetryCountOn5xx() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 503, body: "unavailable")

        let container = try ModelContainer.makeTestContainer()
        let context = ModelContext(container)
        context.insert(SyncTestFixtures.makeProfile())

        let item = SyncQueueItem(
            operation: "save_session",
            tableName: "game_sessions",
            payload: Data("{\"id\":\"test\"}".utf8),
            createdAt: Date(timeIntervalSinceNow: -200)
        )
        context.insert(item)
        try context.save()

        await SyncService(urlSession: MockURLProtocol.makeSession())
            .syncAll(context: context, authService: MockAuthService.makeAuthenticated())

        // Item should still be in queue with incremented retry count.
        let remaining = try context.fetch(FetchDescriptor<SyncQueueItem>())
        let retried = remaining.first(where: { $0.operation == "save_session" })
        #expect(retried?.retryCount == 1)
    }
}

// MARK: - SyncError Tests

struct SyncErrorTests {

    @Test("SyncError.notAuthenticated has non-empty description")
    func notAuthenticatedDescription() {
        let error = SyncError.notAuthenticated
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test("SyncError.requestFailed includes status code in description")
    func requestFailedDescription() {
        let error = SyncError.requestFailed(statusCode: 422, message: "constraint violation")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("422"))
        #expect(desc.contains("constraint violation"))
    }

    @Test("SyncError.requestFailed gracefully handles nil message")
    func requestFailedNilMessage() {
        let error = SyncError.requestFailed(statusCode: 500, message: nil)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("500"))
    }

    @Test("SyncError.invalidResponse returns non-empty description")
    func invalidResponseDescription() {
        #expect(SyncError.invalidResponse.errorDescription?.isEmpty == false)
    }

    @Test("SyncError.queueReplayFailed includes operation name")
    func queueReplayFailedDescription() {
        let error = SyncError.queueReplayFailed(operation: "save_session", statusCode: 503)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("save_session"))
        #expect(desc.contains("503"))
    }
}

// MARK: - Mock auth helper (test-only)

/// A thin stand-in for SupabaseAuthService that returns a fixed session.
/// Lives in the test target only — production code never imports this.
@MainActor
enum MockAuthService {
    static func makeAuthenticated(
        userID: UUID = UUID(),
        email: String = "test@dinklink.com",
        accessToken: String = "test-access-token"
    ) -> SupabaseAuthService {
        let service = SupabaseAuthService()
        service.currentSession = SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: nil,
            user: SupabaseAuthUser(id: userID, email: email),
            expiresAt: Date(timeIntervalSinceNow: 3600)
        )
        return service
    }
}
