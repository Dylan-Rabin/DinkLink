import Testing
import Foundation
@testable import DinkLink

// MARK: - ProgressionPersistenceService Tests

@MainActor
struct ProgressionPersistenceServiceTests {

    // MARK: applySessionAward — writes to both tables

    @Test("applySessionAward writes to user_profiles AND user_progression AND xp_events")
    func applySessionAwardWritesAllThreeTables() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let userID = UUID()
        let award = SyncTestFixtures.makeXPAwardResult(totalXP: 150)

        try await service.applySessionAward(
            userID: userID,
            accessToken: "tok",
            awardResult: award,
            metadata: ["source": "test"]
        )

        let paths = MockURLProtocol.capturedRequests.compactMap { $0.url?.lastPathComponent }

        #expect(paths.contains("user_progression"))
        #expect(paths.contains("user_profiles"))
        #expect(paths.contains("xp_events"))
    }

    @Test("applySessionAward encodes total_xp as Int in user_profiles payload")
    func applySessionAwardEncodesXPAsInt() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let award = SyncTestFixtures.makeXPAwardResult(totalXP: 250)
        try await service.applySessionAward(
            userID: UUID(),
            accessToken: "tok",
            awardResult: award,
            metadata: [:]
        )

        let profileReq = MockURLProtocol.capturedRequests.first(where: {
            $0.url?.lastPathComponent == "user_profiles"
        })
        let body = try #require(profileReq?.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        let row = try #require(json?.first)

        // total_xp must be a JSON number (Int), not a String.
        #expect(row["total_xp"] is Int)
        #expect(row["total_xp"] as? Int == 250)
    }

    @Test("applySessionAward sends one xp_events row per breakdown item")
    func applySessionAwardCreatesOneXPEventPerItem() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let userID = UUID()
        let progression = ProgressionService.buildUserProgression(
            userID: userID.uuidString,
            totalXP: 120,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )
        let award = XPAwardResult(
            xpGained: 120,
            leveledUp: false,
            oldLevel: 1,
            newLevel: 1,
            rankedUp: false,
            oldRank: .bronze,
            newRank: .bronze,
            updatedProgression: progression,
            breakdown: [
                XPBreakdownItem(source: "Complete session", xp: 50),
                XPBreakdownItem(source: "10+ clean hits", xp: 20),
                XPBreakdownItem(source: "Personal best", xp: 40),
                XPBreakdownItem(source: "Played with a friend", xp: 30)
            ]
        )

        try await service.applySessionAward(
            userID: userID,
            accessToken: "tok",
            awardResult: award,
            metadata: [:]
        )

        let xpReq = try #require(MockURLProtocol.capturedRequests.first(where: {
            $0.url?.lastPathComponent == "xp_events"
        }))
        let body = try #require(xpReq.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [[String: Any]]
        #expect(json?.count == 4)
    }

    // MARK: fetchProgression

    @Test("fetchProgression returns nil when server returns empty array")
    func fetchProgressionReturnsNilOnEmpty() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed(json: "[]")

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let result = try await service.fetchProgression(
            userID: UUID(),
            accessToken: "tok"
        )
        #expect(result == nil)
    }

    @Test("fetchProgression decodes total_xp into UserProgression")
    func fetchProgressionDecodesRow() async throws {
        MockURLProtocol.reset()
        let userID = UUID()
        let json = """
        [{"user_id":"\(userID.uuidString.lowercased())","total_xp":500,"updated_at":"2026-04-13T00:00:00Z"}]
        """
        MockURLProtocol.succeed(json: json)

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let progression = try await service.fetchProgression(
            userID: userID,
            accessToken: "tok"
        )

        #expect(progression?.totalXP == 500)
    }

    @Test("fetchProgression throws on 401")
    func fetchProgressionThrowsOn401() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.fail(statusCode: 401, body: "unauthorized")

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        await #expect(throws: (any Error).self) {
            _ = try await service.fetchProgression(userID: UUID(), accessToken: "bad")
        }
    }

    // MARK: backfillProgressionIfNeeded

    @Test("backfill returns remote progression when remote XP >= local XP")
    func backfillReturnsRemoteWhenAhead() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let userID = UUID()
        let local = ProgressionService.buildUserProgression(
            userID: userID.uuidString, totalXP: 100,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )
        let remote = ProgressionService.buildUserProgression(
            userID: userID.uuidString, totalXP: 400,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )

        let result = try await service.backfillProgressionIfNeeded(
            userID: userID,
            accessToken: "tok",
            localProgression: local,
            remoteProgression: remote,
            sessionCount: 5
        )

        // Remote is ahead — no upload should occur and remote is returned.
        let uploadedToProgression = MockURLProtocol.capturedRequests.contains {
            $0.url?.lastPathComponent == "user_progression"
        }
        #expect(!uploadedToProgression)
        #expect(result.totalXP == 400)
    }

    @Test("backfill uploads local XP when local > remote and returns local")
    func backfillUploadsWhenLocalAhead() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.succeed()

        let service = SupabaseProgressionPersistenceService(
            session: MockURLProtocol.makeSession()
        )
        let userID = UUID()
        let local = ProgressionService.buildUserProgression(
            userID: userID.uuidString, totalXP: 600,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )
        let remote = ProgressionService.buildUserProgression(
            userID: userID.uuidString, totalXP: 200,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )

        let result = try await service.backfillProgressionIfNeeded(
            userID: userID,
            accessToken: "tok",
            localProgression: local,
            remoteProgression: remote,
            sessionCount: 10
        )

        let uploadedToProgression = MockURLProtocol.capturedRequests.contains {
            $0.url?.lastPathComponent == "user_progression"
        }
        #expect(uploadedToProgression)
        #expect(result.totalXP == 600)
    }
}
