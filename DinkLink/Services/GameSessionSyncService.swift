import Foundation

/// Uploads and downloads `StoredGameSession` rows to/from `game_sessions` in Supabase.
/// After a successful upload it clears `isDirty` and stamps `remoteID`.
struct GameSessionSyncService {
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Upserts a single session. Returns the remote UUID assigned by Supabase.
    func upsertSession(_ session: StoredGameSession, userID: UUID, accessToken: String) async throws {
        let payload = GameSessionPayload(
            id: session.remoteID ?? session.id,
            userID: userID,
            mode: session.modeRawValue,
            startDate: ISO8601DateFormatter().string(from: session.startDate),
            endDate: ISO8601DateFormatter().string(from: session.endDate),
            playerOneName: session.playerOneName,
            playerTwoName: session.playerTwoName,
            playerOneScore: session.playerOneScore,
            playerTwoScore: session.playerTwoScore,
            averageSwingSpeed: session.averageSwingSpeed,
            maxSwingSpeed: session.maxSwingSpeed,
            sweetSpotPercentage: session.sweetSpotPercentage,
            totalHits: session.totalHits,
            winnerName: session.winnerName,
            longestStreak: session.longestStreak,
            totalValidVolleys: session.totalValidVolleys,
            bestRallyLength: session.bestRallyLength,
            isChallenge: session.isChallenge,
            isPickleCupWin: session.isPickleCupWin
        )

        var request = URLRequest(
            url: SupabaseConfiguration.restURL.appending(path: "game_sessions")
        )
        request.httpMethod = "POST"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode([payload])

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)

        // Stamp back the remote ID used so future upserts hit the same row.
        if session.remoteID == nil {
            session.remoteID = payload.id
        }
    }

    /// Fetches all game_sessions rows for `userID` from Supabase.
    func fetchSessions(userID: UUID, accessToken: String) async throws -> [RemoteGameSession] {
        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "game_sessions"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())"),
            URLQueryItem(name: "order", value: "end_date.desc")
        ]
        guard let url = components.url else { throw SyncError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode([RemoteGameSession].self, from: data)
    }

    // MARK: – Helpers

    private func applyHeaders(to request: inout URLRequest, accessToken: String) {
        request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func validate(response: URLResponse, data: Data) throws {
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
}

// MARK: - Payload

private struct GameSessionPayload: Encodable {
    let id: UUID
    let userID: UUID
    let mode: String
    let startDate: String
    let endDate: String
    let playerOneName: String
    let playerTwoName: String
    let playerOneScore: Int
    let playerTwoScore: Int
    let averageSwingSpeed: Double
    let maxSwingSpeed: Double
    let sweetSpotPercentage: Double
    let totalHits: Int
    let winnerName: String
    let longestStreak: Int
    let totalValidVolleys: Int
    let bestRallyLength: Int
    let isChallenge: Bool
    let isPickleCupWin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case mode
        case startDate = "start_date"
        case endDate = "end_date"
        case playerOneName = "player_one_name"
        case playerTwoName = "player_two_name"
        case playerOneScore = "player_one_score"
        case playerTwoScore = "player_two_score"
        case averageSwingSpeed = "average_swing_speed"
        case maxSwingSpeed = "max_swing_speed"
        case sweetSpotPercentage = "sweet_spot_percentage"
        case totalHits = "total_hits"
        case winnerName = "winner_name"
        case longestStreak = "longest_streak"
        case totalValidVolleys = "total_valid_volleys"
        case bestRallyLength = "best_rally_length"
        case isChallenge = "is_challenge"
        case isPickleCupWin = "is_pickle_cup_win"
    }
}

// MARK: - Remote (download) model

struct RemoteGameSession: Decodable {
    let id: UUID
    let mode: String
    let startDate: String
    let endDate: String
    let playerOneName: String
    let playerTwoName: String
    let playerOneScore: Int
    let playerTwoScore: Int
    let averageSwingSpeed: Double
    let maxSwingSpeed: Double
    let sweetSpotPercentage: Double
    let totalHits: Int
    let winnerName: String
    let longestStreak: Int
    let totalValidVolleys: Int
    let bestRallyLength: Int
    let isChallenge: Bool
    let isPickleCupWin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case mode
        case startDate = "start_date"
        case endDate = "end_date"
        case playerOneName = "player_one_name"
        case playerTwoName = "player_two_name"
        case playerOneScore = "player_one_score"
        case playerTwoScore = "player_two_score"
        case averageSwingSpeed = "average_swing_speed"
        case maxSwingSpeed = "max_swing_speed"
        case sweetSpotPercentage = "sweet_spot_percentage"
        case totalHits = "total_hits"
        case winnerName = "winner_name"
        case longestStreak = "longest_streak"
        case totalValidVolleys = "total_valid_volleys"
        case bestRallyLength = "best_rally_length"
        case isChallenge = "is_challenge"
        case isPickleCupWin = "is_pickle_cup_win"
    }

    func toStoredSession(ownerProfileID: UUID) -> StoredGameSession {
        let iso = ISO8601DateFormatter()
        return StoredGameSession(
            id: id,
            mode: GameMode(rawValue: mode) ?? .dinkSinks,
            startDate: iso.date(from: startDate) ?? .now,
            endDate: iso.date(from: endDate) ?? .now,
            playerOneName: playerOneName,
            playerTwoName: playerTwoName,
            playerOneScore: playerOneScore,
            playerTwoScore: playerTwoScore,
            averageSwingSpeed: averageSwingSpeed,
            maxSwingSpeed: maxSwingSpeed,
            sweetSpotPercentage: sweetSpotPercentage,
            totalHits: totalHits,
            winnerName: winnerName,
            longestStreak: longestStreak,
            totalValidVolleys: totalValidVolleys,
            bestRallyLength: bestRallyLength,
            ownerProfileID: ownerProfileID
        )
    }
}
