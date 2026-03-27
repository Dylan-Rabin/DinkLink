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
            let session = try? decoder.decode(SupabaseAuthSession.self, from: data)
        else {
            return
        }

        currentSession = session
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)
            throw AuthServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
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

enum AuthServiceError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The auth service returned an invalid response."
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "Auth request failed (\(statusCode)): \(message)"
            }
            return "Auth request failed with status \(statusCode)."
        }
    }
}
