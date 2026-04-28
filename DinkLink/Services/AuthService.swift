import Foundation
import Observation

@MainActor
@Observable
final class SupabaseAuthService {
    var currentSession: SupabaseAuthSession?
    var isAuthenticating = false
    var authErrorMessage: String?
    var authStatusMessage: String?

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let storage: UserDefaults

    init(
        session: URLSession = .shared,
        storage: UserDefaults = .standard
    ) {
        self.session = session
        self.storage = storage
        loadStoredSession()
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    /// True only when the session exists AND the access token has not expired
    /// (with a 60-second buffer to account for clock skew and network latency).
    var hasValidAccessToken: Bool {
        guard let session = currentSession else { return false }
        guard let expiresAt = session.expiresAt else { return true } // no expiry = treat as valid
        return expiresAt.timeIntervalSinceNow > 60
    }

    var accessToken: String? {
        currentSession?.accessToken
    }

    var currentUserID: UUID? {
        currentSession?.user.id
    }

    var currentUserEmail: String? {
        currentSession?.user.email
    }

    func signUp(email: String, password: String) async {
        await authenticate(
            endpoint: SupabaseConfiguration.authURL.appending(path: "signup"),
            body: SupabaseAuthRequest(email: email, password: password),
            emptySessionMessage: "Account created. Confirm your email, then sign in."
        )
    }

    func signIn(email: String, password: String) async {
        guard var components = URLComponents(
            url: SupabaseConfiguration.authURL.appending(path: "token"),
            resolvingAgainstBaseURL: false
        ) else {
            authErrorMessage = "Couldn't create the sign-in request."
            return
        }

        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]

        guard let url = components.url else {
            authErrorMessage = "Couldn't create the sign-in request."
            return
        }

        await authenticate(
            endpoint: url,
            body: SupabaseAuthRequest(email: email, password: password),
            emptySessionMessage: "Sign-in completed, but no active session was returned."
        )
    }

    func signOut() {
        currentSession = nil
        authErrorMessage = nil
        authStatusMessage = "Signed out."
        storage.removeObject(forKey: SupabaseConfiguration.authSessionStorageKey)
    }

    /// Exchanges the stored refresh token for a new access token.
    /// Called automatically on launch when the stored session has expired.
    /// Returns `true` if the session was successfully refreshed.
    @discardableResult
    func refreshSessionIfNeeded() async -> Bool {
        guard let token = currentSession?.refreshToken, !token.isEmpty else {
            return false
        }

        guard var components = URLComponents(
            url: SupabaseConfiguration.authURL.appending(path: "token"),
            resolvingAgainstBaseURL: false
        ) else { return false }

        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components.url else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        struct RefreshBody: Encodable { let refresh_token: String }
        guard let body = try? encoder.encode(RefreshBody(refresh_token: token)) else { return false }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)
            if let newSession = authResponse.session {
                currentSession = newSession
                persist(session: newSession)
                return true
            }
        } catch {
            // Refresh token is invalid or expired — sign the user out cleanly.
            signOut()
        }
        return false
    }

    private func authenticate(
        endpoint: URL,
        body: SupabaseAuthRequest,
        emptySessionMessage: String
    ) async {
        let trimmedEmail = body.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = body.password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            authErrorMessage = "Enter your email and password."
            return
        }

        isAuthenticating = true
        authErrorMessage = nil
        authStatusMessage = nil
        defer { isAuthenticating = false }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try encoder.encode(
                SupabaseAuthRequest(email: trimmedEmail, password: trimmedPassword)
            )

            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            let authResponse = try decoder.decode(SupabaseAuthResponse.self, from: data)

            if let session = authResponse.session {
                currentSession = session
                authStatusMessage = "Signed in as \(session.user.email ?? trimmedEmail)."
                persist(session: session)
            } else {
                currentSession = nil
                storage.removeObject(forKey: SupabaseConfiguration.authSessionStorageKey)
                authStatusMessage = emptySessionMessage
            }
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func persist(session: SupabaseAuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        storage.set(data, forKey: SupabaseConfiguration.authSessionStorageKey)
    }

    private func loadStoredSession() {
        guard
            let data = storage.data(forKey: SupabaseConfiguration.authSessionStorageKey),
            let storedSession = try? decoder.decode(SupabaseAuthSession.self, from: data)
        else {
            return
        }

        // If the access token is still valid (with a 60-second buffer), use it directly.
        // If it's expired but we have a refresh token, set the session so
        // refreshSessionIfNeeded() can exchange it — called from AppViewModel on launch.
        currentSession = storedSession
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = decodeErrorMessage(from: data)
            throw AuthServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        if let response = try? decoder.decode(SupabaseErrorResponse.self, from: data) {
            return response.message
        }

        return String(data: data, encoding: .utf8)
    }
}

private struct SupabaseAuthRequest: Encodable {
    let email: String
    let password: String
}

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Double?
    let user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    var session: SupabaseAuthSession? {
        guard let accessToken, let user else { return nil }

        let expiresAt = expiresIn.map { Date().addingTimeInterval($0) }
        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: user,
            expiresAt: expiresAt
        )
    }
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let msg: String?
    let responseMessage: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case msg
        case responseMessage = "message"
    }

    var message: String? {
        errorDescription ?? msg ?? responseMessage ?? error
    }
}

enum AuthServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The auth service returned an invalid response."
        case let .requestFailed(statusCode, message):
            if let friendlyMessage = Self.friendlyMessage(statusCode: statusCode, message: message) {
                return friendlyMessage
            }
            return "We couldn't complete that auth request. Please try again."
        }
    }

    private static func friendlyMessage(statusCode: Int, message: String?) -> String? {
        let normalizedMessage = message?.lowercased() ?? ""

        if normalizedMessage.contains("password") && normalizedMessage.contains("6") {
            return "Password must be at least 6 characters."
        }

        if normalizedMessage.contains("invalid login credentials") {
            return "Email or password is incorrect."
        }

        if normalizedMessage.contains("already registered") || normalizedMessage.contains("already exists") {
            return "An account already exists for this email. Use the returning player sign-in instead."
        }

        if normalizedMessage.contains("email") && normalizedMessage.contains("invalid") {
            return "Enter a valid email address."
        }

        if statusCode == 429 {
            return "Too many attempts. Please wait a moment and try again."
        }

        return nil
    }
}
