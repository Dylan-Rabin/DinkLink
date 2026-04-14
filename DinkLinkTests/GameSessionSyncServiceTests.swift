import Testing
import Foundation
@testable import DinkLink

// MARK: - GameSessionSyncService Tests

@MainActor
struct GameSessionSyncServiceTests {

    // MARK: upsertSession — request shape

    @Test("upsertSession POSTs to game_sessions with all required fields")
    func upsertSessionSendsAllFields() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())
        let session = SyncTestFixtures.makeSession(
            mode: .theRealDeal,
            isDirty: true,
            isChallenge: true,
            isPickleCupWin: false,
            totalHits: 72
        )
        let userID = UUID()

        try await service.upsertSession(session, userID: userID, accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.path.contains("game_sessions") == true)
        #expect(req.value(forHTTPHeaderField: "Prefer") == "resolution=merge-duplicates")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer tok")

        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)

        #expect(row["user_id"] as? String == userID.uuidString.lowercased())
        #expect(row["mode"] as? String == "The Real Deal")
        #expect(row["player_one_name"] as? String == "Alice")
        #expect(row["player_two_name"] as? String == "Bob")
        #expect(row["player_one_score"] as? Int == 5)
        #expect(row["player_two_score"] as? Int == 3)
        #expect(row["total_hits"] as? Int == 72)
        #expect(row["winner_name"] as? String == "Alice")
        #expect(row["is_challenge"] as? Bool == true)
        #expect(row["is_pickle_cup_win"] as? Bool == false)
    }

    @Test("upsertSession stamps remoteID on session after first upload")
    func upsertSessionStampsRemoteID() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())
        let session = SyncTestFixtures.makeSession()
        #expect(session.remoteID == nil)

        try await service.upsertSession(session, userID: UUID(), accessToken: "tok")

        #expect(session.remoteID != nil)
    }

    @Test("upsertSession reuses existing remoteID on re-upload")
    func upsertSessionReusesRemoteID() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())
        let session = SyncTestFixtures.makeSession()
        let existingRemoteID = UUID()
        session.remoteID = existingRemoteID

        try await service.upsertSession(session, userID: UUID(), accessToken: "tok")

        // The payload id should match the pre-existing remoteID.
        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect((row["id"] as? String)?.uppercased() == existingRemoteID.uuidString.uppercased())
        #expect(session.remoteID == existingRemoteID)
    }

    @Test("upsertSession sends ISO8601 formatted dates")
    func upsertSessionDateFormat() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())
        let session = SyncTestFixtures.makeSession()

        try await service.upsertSession(session, userID: UUID(), accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)

        let startDate = try #require(row["start_date"] as? String)
        let endDate = try #require(row["end_date"] as? String)

        // ISO8601 dates contain a 'T' separator.
        #expect(startDate.contains("T"))
        #expect(endDate.contains("T"))
    }

    // MARK: is_pickle_cup_win flag

    @Test("upsertSession encodes is_pickle_cup_win = true correctly")
    func upsertSessionPickleCupFlag() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())
        let session = SyncTestFixtures.makeSession(isPickleCupWin: true)

        try await service.upsertSession(session, userID: UUID(), accessToken: "tok")

        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["is_pickle_cup_win"] as? Bool == true)
    }

    // MARK: Error handling

    @Test("upsertSession throws SyncError.requestFailed on 403")
    func upsertSessionThrowsOn403() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 403, body: "forbidden")

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())

        do {
            try await service.upsertSession(
                SyncTestFixtures.makeSession(),
                userID: UUID(),
                accessToken: "tok"
            )
            Issue.record("Expected throw but call succeeded")
        } catch SyncError.requestFailed(let code, _) {
            #expect(code == 403)
        }
    }

    @Test("upsertSession throws SyncError.requestFailed on 500")
    func upsertSessionThrowsOn500() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 500)

        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())

        await #expect(throws: SyncError.self) {
            try await service.upsertSession(
                SyncTestFixtures.makeSession(),
                userID: UUID(),
                accessToken: "tok"
            )
        }
    }

    // MARK: All game modes serialize correctly

    @Test("upsertSession encodes Dink Sinks mode string")
    func upsertSessionDinkSinksMode() async throws {
        try await assertModeString(.dinkSinks, expected: "Dink Sinks")
    }

    @Test("upsertSession encodes Volley Wallies mode string")
    func upsertSessionVolleyWalliesMode() async throws {
        try await assertModeString(.volleyWallies, expected: "Volley Wallies")
    }

    @Test("upsertSession encodes Pickle Cup mode string")
    func upsertSessionPickleCupMode() async throws {
        try await assertModeString(.pickleCup, expected: "Pickle Cup")
    }

    private func assertModeString(_ mode: GameMode, expected: String) async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()
        let service = GameSessionSyncService(urlSession: MockURLProtocol.makeSession())
        let session = SyncTestFixtures.makeSession(mode: mode)
        try await service.upsertSession(session, userID: UUID(), accessToken: "tok")
        let req = try #require(MockURLProtocol.capturedRequests.first)
        let body = try #require(req.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)
        #expect(row["mode"] as? String == expected)
    }
}
