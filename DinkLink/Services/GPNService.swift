import Foundation

/// Handles all communication with the GPN (Global Pickleball Network) integration layer.
///
/// Authentication flow (server-side only):
///   1. App collects GPN username + password from the user.
///   2. `syncProfile` sends credentials to the `sync-gpn-profile` Supabase Edge Function.
///   3. The Edge Function calls GPN OAuth, fetches levels/stats, writes to `gpn_profiles`,
///      and stores tokens in Supabase Vault. Credentials never leave the Edge Function.
///   4. The Edge Function returns parsed profile data which the app persists locally.
///
/// Offline behaviour:
///   - `fetchCachedProfile` reads from `gpn_profiles` in Supabase (latest synced values).
///   - The local `GPNProfile` SwiftData object is the display source of truth.
///   - If the device is offline the existing SwiftData record is shown with "Last synced X ago".
struct GPNService {
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    // MARK: - Sync (calls Edge Function)

    /// Triggers a full GPN sync via the `sync-gpn-profile` Edge Function.
    /// Pass `gpnUsername` and `gpnPassword` only on the first link. For
    /// subsequent refreshes pass `nil` for both — the Edge Function will
    /// reuse the cached server-side session.
    func syncProfile(
        gpnUsername: String? = nil,
        gpnPassword: String? = nil,
        accessToken: String
    ) async throws -> GPNEdgeFunctionResponse {
        let url = SupabaseConfiguration.projectURL
            .appending(path: "functions/v1/sync-gpn-profile")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyHeaders(to: &request, accessToken: accessToken)

        let body = GPNSyncRequest(gpnUsername: gpnUsername, gpnPassword: gpnPassword)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(GPNEdgeFunctionResponse.self, from: data)
    }

    // MARK: - Fetch cached row from Supabase

    /// Reads the latest cached GPN data from the `gpn_profiles` table.
    /// Returns `nil` if no row exists yet (user has not linked their account).
    func fetchCachedProfile(userID: UUID, accessToken: String) async throws -> RemoteGPNProfile? {
        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "gpn_profiles"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else { throw SyncError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request, accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        let rows = try decoder.decode([RemoteGPNProfile].self, from: data)
        return rows.first
    }

    // MARK: - Helpers

    private func applyHeaders(to request: inout URLRequest, accessToken: String) {
        request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
