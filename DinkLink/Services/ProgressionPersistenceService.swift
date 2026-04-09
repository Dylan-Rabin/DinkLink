import Foundation

protocol ProgressionPersistenceServiceProtocol {
    func fetchProgression(userID: UUID, accessToken: String) async throws -> UserProgression?
    func backfillProgressionIfNeeded(
        userID: UUID,
        accessToken: String,
        localProgression: UserProgression,
        remoteProgression: UserProgression?,
        sessionCount: Int
    ) async throws -> UserProgression
    func applySessionAward(
        userID: UUID,
        accessToken: String,
        awardResult: XPAwardResult,
        metadata: [String: String]
    ) async throws
}

struct SupabaseProgressionPersistenceService: ProgressionPersistenceServiceProtocol {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProgression(userID: UUID, accessToken: String) async throws -> UserProgression? {
        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "user_progression"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: "user_id,total_xp,updated_at"),
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else {
            throw ProgressionPersistenceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request, accessToken: accessToken)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let records = try decoder.decode([UserProgressionRecord].self, from: data)
        guard let record = records.first else { return nil }

        return ProgressionService.buildUserProgression(
            userID: record.userID.uuidString,
            totalXP: record.totalXP,
            updatedAt: record.updatedAt
        )
    }

    func backfillProgressionIfNeeded(
        userID: UUID,
        accessToken: String,
        localProgression: UserProgression,
        remoteProgression: UserProgression?,
        sessionCount: Int
    ) async throws -> UserProgression {
        let remoteXP = remoteProgression?.totalXP ?? 0
        guard localProgression.totalXP > remoteXP else {
            return remoteProgression ?? localProgression
        }

        try await upsertProgression(
            userID: userID,
            accessToken: accessToken,
            totalXP: localProgression.totalXP
        )

        let deltaXP = localProgression.totalXP - remoteXP
        try await insertXPEvents(
            userID: userID,
            accessToken: accessToken,
            breakdown: [XPBreakdownItem(source: "Local progression backfill", xp: deltaXP)],
            metadata: [
                "sync_type": "backfill",
                "session_count": String(sessionCount),
                "previous_remote_xp": String(remoteXP)
            ]
        )

        return localProgression
    }

    func applySessionAward(
        userID: UUID,
        accessToken: String,
        awardResult: XPAwardResult,
        metadata: [String: String]
    ) async throws {
        try await upsertProgression(
            userID: userID,
            accessToken: accessToken,
            totalXP: awardResult.updatedProgression.totalXP
        )
        try await insertXPEvents(
            userID: userID,
            accessToken: accessToken,
            breakdown: awardResult.breakdown,
            metadata: metadata
        )
    }

    private func upsertProgression(
        userID: UUID,
        accessToken: String,
        totalXP: Int
    ) async throws {
        var request = URLRequest(url: SupabaseConfiguration.restURL.appending(path: "user_progression"))
        request.httpMethod = "POST"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let payload = [
            UserProgressionWriteRecord(
                userID: userID,
                totalXP: totalXP,
                updatedAt: ISO8601DateFormatter().string(from: .now)
            )
        ]
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func insertXPEvents(
        userID: UUID,
        accessToken: String,
        breakdown: [XPBreakdownItem],
        metadata: [String: String]
    ) async throws {
        guard !breakdown.isEmpty else { return }

        var request = URLRequest(url: SupabaseConfiguration.restURL.appending(path: "xp_events"))
        request.httpMethod = "POST"
        applyHeaders(to: &request, accessToken: accessToken)

        let payload = breakdown.map {
            XPEventWriteRecord(
                userID: userID,
                source: $0.source,
                xp: $0.xp,
                metadata: metadata
            )
        }
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func applyHeaders(to request: inout URLRequest, accessToken: String) {
        request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProgressionPersistenceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)
            throw ProgressionPersistenceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

enum ProgressionPersistenceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Couldn't create the progression request."
        case .invalidResponse:
            return "The progression service returned an invalid response."
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "Progression request failed (\(statusCode)): \(message)"
            }
            return "Progression request failed with status \(statusCode)."
        }
    }
}

private struct UserProgressionRecord: Decodable {
    let userID: UUID
    let totalXP: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case totalXP = "total_xp"
        case updatedAt = "updated_at"
    }
}

private struct UserProgressionWriteRecord: Encodable {
    let userID: UUID
    let totalXP: Int
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case totalXP = "total_xp"
        case updatedAt = "updated_at"
    }
}

private struct XPEventWriteRecord: Encodable {
    let userID: UUID
    let source: String
    let xp: Int
    let metadata: [String: String]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case source
        case xp
        case metadata
    }
}
