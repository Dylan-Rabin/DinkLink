import Foundation
import SwiftData
import Testing
@testable import DinkLink

// Stub URLProtocol that returns canned responses keyed by URL path substring.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [(matcher: (URL) -> Bool, status: Int, body: Data)] = []
    nonisolated(unsafe) static var capturedURLs: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.capturedURLs.append(url)
        if let stub = Self.responses.first(where: { $0.matcher(url) }) {
            let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct SignInFlowTests {

    private func makeStubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            PlayerProfile.self, StoredGameSession.self,
            SavedLocation.self, SyncQueueItem.self, GPNProfile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test
    func returningUserSignInRestoresCloudProfileAndIdMatchesAuthUUID() async throws {
        // Arrange — fresh device, no local profile, but cloud has a user_profiles row.
        let userID = UUID()
        let authBody: [String: Any] = [
            "access_token": "stub-access-token",
            "refresh_token": "stub-refresh-token",
            "expires_in": 3600,
            "user": ["id": userID.uuidString, "email": "test@example.com"]
        ]
        let profileBody: [[String: String]] = [[
            "display_name": "Cloud Dylan",
            "home_city": "Seattle",
            "paddle_name": "Cloud Paddle"
        ]]
        StubURLProtocol.responses = [
            (matcher: { $0.path.contains("/auth/v1/token") },
             status: 200,
             body: try JSONSerialization.data(withJSONObject: authBody)),
            (matcher: { $0.path.contains("/rest/v1/user_profiles") },
             status: 200,
             body: try JSONSerialization.data(withJSONObject: profileBody))
        ]
        StubURLProtocol.capturedURLs = []
        let isolatedDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let stubSession = makeStubbedSession()
        let auth = SupabaseAuthService(session: stubSession, storage: isolatedDefaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let persistence = SwiftDataPersistenceService(context: context)
        let vm = OnboardingViewModel(
            bluetoothService: MockBluetoothService(),
            persistenceService: persistence,
            authService: auth,
            existingProfile: nil,
            profileSyncService: UserProfileSyncService(urlSession: stubSession)
        )
        vm.authEmail = "test@example.com"
        vm.authPassword = "correct-password"

        // Act
        let profile = await vm.signInReturningUser()

        // Assert — sign-in succeeded, profile.id == auth UUID, fields restored from cloud.
        let urls = StubURLProtocol.capturedURLs.map { $0.absoluteString }.joined(separator: " | ")
        #expect(auth.isAuthenticated, "auth should succeed. URLs: \(urls). authError: \(auth.authErrorMessage ?? "nil")")
        #expect(auth.currentUserID == userID)
        #expect(profile != nil, "signInReturningUser must return a profile when cloud row exists. URLs hit: \(urls)")
        #expect(profile?.id == userID, "profile.id MUST equal auth UUID for ContentView lookup")
        #expect(profile?.name == "Cloud Dylan")
        #expect(profile?.locationName == "Seattle")
        #expect(profile?.syncedPaddleName == "Cloud Paddle")
        #expect(profile?.completedOnboarding == true)
    }

    @Test
    func returningUserSignInWithNoCloudRowAndNoLocalProfileBumpsToProfileStep() async throws {
        let userID = UUID()
        let authBody: [String: Any] = [
            "access_token": "stub",
            "refresh_token": "stub",
            "expires_in": 3600,
            "user": ["id": userID.uuidString, "email": "x@y.com"]
        ]
        StubURLProtocol.responses = [
            (matcher: { $0.path.contains("/auth/v1/token") },
             status: 200,
             body: try JSONSerialization.data(withJSONObject: authBody)),
            (matcher: { $0.path.contains("/rest/v1/user_profiles") },
             status: 200,
             body: Data("[]".utf8))
        ]
        let isolatedDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let stubSession = makeStubbedSession()
        let auth = SupabaseAuthService(session: stubSession, storage: isolatedDefaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = OnboardingViewModel(
            bluetoothService: MockBluetoothService(),
            persistenceService: SwiftDataPersistenceService(context: context),
            authService: auth,
            existingProfile: nil,
            profileSyncService: UserProfileSyncService(urlSession: stubSession)
        )
        vm.authEmail = "x@y.com"
        vm.authPassword = "pw"

        let profile = await vm.signInReturningUser()

        #expect(auth.isAuthenticated)
        #expect(profile == nil)
        #expect(vm.currentStep == .playerProfile)
        #expect(vm.onboardingErrorMessage != nil)
    }

    @Test
    func returningUserSignInWithBadCredentialsReturnsNilAndShowsError() async throws {
        let errorBody: [String: Any] = ["error_code": "invalid_credentials", "msg": "nope"]
        StubURLProtocol.responses = [
            (matcher: { $0.path.contains("/auth/v1/token") },
             status: 400,
             body: try JSONSerialization.data(withJSONObject: errorBody))
        ]
        let isolatedDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let auth = SupabaseAuthService(session: makeStubbedSession(), storage: isolatedDefaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let vm = OnboardingViewModel(
            bluetoothService: MockBluetoothService(),
            persistenceService: SwiftDataPersistenceService(context: context),
            authService: auth,
            existingProfile: nil
        )
        vm.authEmail = "x@y.com"
        vm.authPassword = "wrong"

        let profile = await vm.signInReturningUser()

        #expect(profile == nil)
        #expect(!auth.isAuthenticated)
        #expect(auth.authErrorMessage != nil)
    }
}
