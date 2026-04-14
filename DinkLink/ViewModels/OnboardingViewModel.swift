import Foundation
import Observation

@MainActor
// This view model owns all onboarding screen state and actions, keeping the view
// focused on binding and presentation.
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case intro
        case playerProfile
        case paddleSync
        case ready
    }

    var currentStep: Step = .intro
    var playerName: String
    var playerLocation: String
    var dominantArm: DominantArm
    var skillLevel: SkillLevel
    var authEmail: String
    var authPassword = ""
    var availableDevices: [PaddleDevice] = []
    var selectedDeviceID: UUID?
    var isScanning = false
    var isConnecting = false
    var onboardingErrorMessage: String?

    /// Set after a successful login when the remote profile was fetched and a
    /// local SwiftData profile was created. The view should call onComplete with this.
    var restoredProfileAfterLogin: PlayerProfile?

    /// Called immediately after a successful sign-in or sign-up so the caller
    /// can trigger a sync pass while the auth session is fresh.
    var onSignedIn: (() -> Void)?

    @ObservationIgnored
    private let bluetoothService: BluetoothServiceProtocol
    @ObservationIgnored
    private let persistenceService: PersistenceServiceProtocol
    @ObservationIgnored
    private let authService: SupabaseAuthService
    @ObservationIgnored
    private let storedExistingProfile: PlayerProfile?

    init(
        bluetoothService: BluetoothServiceProtocol,
        persistenceService: PersistenceServiceProtocol,
        authService: SupabaseAuthService,
        existingProfile: PlayerProfile?
    ) {
        self.bluetoothService = bluetoothService
        self.persistenceService = persistenceService
        self.authService = authService
        self.storedExistingProfile = existingProfile
        playerName = existingProfile?.name ?? ""
        playerLocation = existingProfile?.locationName ?? ""
        dominantArm = existingProfile?.dominantArm ?? .right
        skillLevel = existingProfile?.skillLevel ?? .beginner
        authEmail = authService.currentUserEmail ?? ""
    }

    /// Returns a completed profile if this device already has one, so returning
    /// users who log in can be taken straight into the app without re-entering details.
    var completedExistingProfile: PlayerProfile? {
        storedExistingProfile?.completedOnboarding == true ? storedExistingProfile : nil
    }

    var canContinueFromProfile: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !playerLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUseReturningUser: Bool {
        true
    }

    var isAuthenticated: Bool {
        authService.isAuthenticated
    }

    var isAuthenticating: Bool {
        authService.isAuthenticating
    }

    var authStatusMessage: String? {
        authService.authStatusMessage
    }

    var authErrorMessage: String? {
        authService.authErrorMessage
    }

    var authenticatedEmail: String? {
        authService.currentUserEmail
    }

    var selectedDevice: PaddleDevice? {
        availableDevices.first(where: { $0.id == selectedDeviceID })
    }

    func scanForPaddles() async {
        isScanning = true
        availableDevices = await bluetoothService.scanForDevices()
        selectedDeviceID = selectedDeviceID ?? availableDevices.first?.id
        isScanning = false
    }

    func connectSelectedPaddle() async {
        guard let device = selectedDevice else { return }
        isConnecting = true
        await bluetoothService.connect(to: device)
        isConnecting = false
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func signUpWithEmail() async {
        await authService.signUp(email: authEmail, password: authPassword)
        authEmail = authService.currentUserEmail ?? authEmail
        guard authService.isAuthenticated,
              let userID = authService.currentUserID,
              let accessToken = authService.accessToken
        else { return }

        onSignedIn?()

        // Immediately push the name + city the user just entered so the Supabase
        // user_profiles row exists and round-trips correctly on future logins.
        if !playerName.isEmpty {
            let profileSync = UserProfileSyncService()
            let stub = PlayerProfile(
                id: userID,
                name: playerName,
                locationName: playerLocation,
                dominantArm: dominantArm,
                skillLevel: skillLevel,
                syncedPaddleName: "Mock Paddle",
                completedOnboarding: false
            )
            try? await profileSync.upsertProfile(stub, userID: userID, accessToken: accessToken)
        }
    }

    func signInWithEmail() async {
        await authService.signIn(email: authEmail, password: authPassword)
        authEmail = authService.currentUserEmail ?? authEmail
        guard authService.isAuthenticated,
              let userID = authService.currentUserID,
              let accessToken = authService.accessToken
        else { return }

        onSignedIn?()

        // Pull down the remote profile so we can pre-fill name/city for the
        // paddle-sync step. Whether or not a remote row exists, we always route
        // through paddle sync so the user can confirm/update their paddle.
        let profileSync = UserProfileSyncService()
        if let remote = try? await profileSync.fetchProfile(userID: userID, accessToken: accessToken),
           !remote.displayName.isEmpty {
            playerName = remote.displayName
            playerLocation = remote.homeCity
        } else if playerName.isEmpty {
            // No remote profile yet — pre-fill name from email prefix.
            playerName = authEmail.components(separatedBy: "@").first ?? ""
        }

        // Create / update the local SwiftData profile so it exists when paddle
        // sync completes and calls completeOnboarding().
        restoredProfileAfterLogin = try? persistenceService.saveProfile(
            name: playerName.isEmpty ? (authEmail.components(separatedBy: "@").first ?? "Player") : playerName,
            locationName: playerLocation,
            dominantArm: dominantArm,
            skillLevel: skillLevel,
            paddleName: "Mock Paddle",
            supabaseUserID: userID
        )
    }

    func signInReturningUser() -> PlayerProfile? {
        playerName = "Dylan"
        playerLocation = "San Francisco"
        dominantArm = .left
        skillLevel = .intermediate
        selectedDeviceID = availableDevices.first(where: { $0.name == "CourtSense One" })?.id

        let profile = saveProfile(paddleName: "CourtSense One")
        if let profile {
            persistenceService.seedDylanSessions(profileID: profile.id)
        }
        return profile
    }

    func completeOnboarding() -> PlayerProfile? {
        saveProfile(
            paddleName: bluetoothService.connectedDevice?.name ?? selectedDevice?.name ?? "Mock Paddle"
        )
    }

    private func saveProfile(paddleName: String) -> PlayerProfile? {
        do {
            let profile = try persistenceService.saveProfile(
                name: playerName,
                locationName: playerLocation,
                dominantArm: dominantArm,
                skillLevel: skillLevel,
                paddleName: paddleName,
                supabaseUserID: authService.currentUserID
            )
            onboardingErrorMessage = nil
            return profile
        } catch {
            onboardingErrorMessage = "Could not finish onboarding. Reset saved app data and try again."
            return nil
        }
    }
}
