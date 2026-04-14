import Foundation

/// Uploads a `PlayerProfile` to `user_profiles` and syncs dirty `SavedLocation` rows
/// to `saved_locations`. Both operations use upsert (merge-duplicates).
struct UserProfileSyncService {
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - user_profiles

    func upsertProfile(_ profile: PlayerProfile, userID: UUID, accessToken: String) async throws {
        let payload = UserProfilePayload(
            userID: userID,
            displayName: profile.name,
            homeCity: profile.locationName,
            paddleName: profile.syncedPaddleName,
            currentStreak: profile.currentStreak,
            longestStreak: profile.longestDailyStreak,
            lastActiveDate: profile.lastActiveDate.map { ISO8601DateFormatter().string(from: $0) },
            gpnUsername: profile.gpnUsername.isEmpty ? nil : profile.gpnUsername,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )

        var request = URLRequest(
            url: SupabaseConfiguration.restURL.appending(path: "user_profiles")
        )
        request.httpMethod = "POST"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode([payload])

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
    }

    // MARK: - Fetch

    /// Fetches the remote user_profiles row for `userID`. Returns nil if no row exists yet.
    func fetchProfile(userID: UUID, accessToken: String) async throws -> RemoteUserProfile? {
        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "user_profiles"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())"),
                                 URLQueryItem(name: "limit", value: "1")]
        guard let url = components.url else { throw SyncError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        let rows = try decoder.decode([RemoteUserProfile].self, from: data)
        return rows.first
    }

    // MARK: - saved_locations

    func upsertLocation(_ location: SavedLocation, userID: UUID, accessToken: String) async throws {
        let payload = SavedLocationPayload(
            id: location.supabaseID ?? location.id,
            userID: userID,
            label: location.label,
            placeName: location.placeName,
            address: location.address.isEmpty ? nil : location.address,
            latitude: location.latitude == 0 ? nil : location.latitude,
            longitude: location.longitude == 0 ? nil : location.longitude,
            isHome: location.isHome
        )

        var request = URLRequest(
            url: SupabaseConfiguration.restURL.appending(path: "saved_locations")
        )
        request.httpMethod = "POST"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode([payload])

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
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

// MARK: - Wire payloads

private struct UserProfilePayload: Encodable {
    let userID: UUID
    let displayName: String
    let homeCity: String
    let paddleName: String
    let currentStreak: Int
    let longestStreak: Int
    let lastActiveDate: String?
    let gpnUsername: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
        case homeCity = "home_city"
        case paddleName = "paddle_name"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActiveDate = "last_active_date"
        case gpnUsername = "gpn_username"
        case updatedAt = "updated_at"
    }
}

struct RemoteUserProfile: Decodable {
    let displayName: String
    let homeCity: String
    let paddleName: String

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case homeCity = "home_city"
        case paddleName = "paddle_name"
    }
}

private struct SavedLocationPayload: Encodable {
    let id: UUID
    let userID: UUID
    let label: String
    let placeName: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let isHome: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case label
        case placeName = "place_name"
        case address
        case latitude
        case longitude
        case isHome = "is_home"
    }
}
