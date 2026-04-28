import Testing
import Foundation
@testable import DinkLink

// MARK: - UserProfileSyncService Tests

@MainActor
struct UserProfileSyncServiceTests {

    // MARK: upsertProfile — success

    @Test("upsertProfile sends POST to user_profiles with correct JSON fields")
    func upsertProfileSendsCorrectRequest() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let profile = SyncTestFixtures.makeProfile(
            name: "Dylan",
            currentStreak: 5,
            longestStreak: 10
        )
        let userID = UUID()

        try await service.upsertProfile(profile, userID: userID, accessToken: "test-token")

        // Exactly one request should be made.
        let captured = MockURLProtocol.capturedRequests
        #expect(captured.count == 1)

        let req = try #require(captured.first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.contains("user_profiles") == true)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(req.value(forHTTPHeaderField: "Prefer") == "resolution=merge-duplicates")

        // Body should contain the right keys.
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["user_id"] as? String == userID.uuidString.lowercased())
        #expect(row["display_name"] as? String == "Dylan")
        #expect(row["current_streak"] as? Int == 5)
        #expect(row["longest_streak"] as? Int == 10)
    }

    @Test("upsertProfile omits gpn_username when empty")
    func upsertProfileOmitsEmptyGPN() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let profile = SyncTestFixtures.makeProfile(gpnUsername: "")

        try await service.upsertProfile(profile, userID: UUID(), accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["gpn_username"] == nil)
    }

    @Test("upsertProfile sends gpn_username when set")
    func upsertProfileIncludesGPN() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let profile = SyncTestFixtures.makeProfile(gpnUsername: "dylan_gpn")

        try await service.upsertProfile(profile, userID: UUID(), accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["gpn_username"] as? String == "dylan_gpn")
    }

    // MARK: upsertProfile — error handling

    @Test("upsertProfile throws SyncError on 401")
    func upsertProfileThrowsOn401() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 401, body: "unauthorized")

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let profile = SyncTestFixtures.makeProfile()

        await #expect(throws: SyncError.self) {
            try await service.upsertProfile(profile, userID: UUID(), accessToken: "bad")
        }
    }

    @Test("upsertProfile throws SyncError on 500 with message")
    func upsertProfileThrowsOn500() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 500, body: "internal error")

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())

        do {
            try await service.upsertProfile(
                SyncTestFixtures.makeProfile(),
                userID: UUID(),
                accessToken: "tok"
            )
            Issue.record("Expected throw but succeeded")
        } catch SyncError.requestFailed(let code, let message) {
            #expect(code == 500)
            #expect(message?.contains("internal error") == true)
        }
    }

    // MARK: upsertLocation — success

    @Test("upsertLocation sends POST to saved_locations with is_home flag")
    func upsertLocationSendsCorrectRequest() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let location = SyncTestFixtures.makeLocation(label: "Home Court", isHome: true)
        let userID = UUID()

        try await service.upsertLocation(location, userID: userID, accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        #expect(req.url?.path.contains("saved_locations") == true)

        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["user_id"] as? String == userID.uuidString.lowercased())
        #expect(row["label"] as? String == "Home Court")
        #expect(row["is_home"] as? Bool == true)
    }

    @Test("upsertLocation omits address when empty")
    func upsertLocationOmitsEmptyAddress() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let location = SavedLocation(label: "Court", placeName: "Park", address: "")

        try await service.upsertLocation(location, userID: UUID(), accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["address"] == nil)
    }

    @Test("upsertLocation omits lat/lon when both zero")
    func upsertLocationOmitsZeroCoordinates() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = UserProfileSyncService(urlSession: MockURLProtocol.makeSession())
        let location = SavedLocation(
            label: "Unknown",
            placeName: "Unknown",
            latitude: 0,
            longitude: 0
        )
        try await service.upsertLocation(location, userID: UUID(), accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["latitude"] == nil)
        #expect(row["longitude"] == nil)
    }
}
