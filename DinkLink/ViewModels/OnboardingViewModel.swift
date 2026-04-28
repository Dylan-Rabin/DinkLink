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

    @ObservationIgnored
    private let bluetoothService: BluetoothServiceProtocol
    @ObservationIgnored
    private let persistenceService: PersistenceServiceProtocol
    @ObservationIgnored
    private let authService: SupabaseAuthService
    @ObservationIgnored
    private let existingProfile: PlayerProfile?
    @ObservationIgnored
    private let profileSyncService: UserProfileSyncService

    init(
        bluetoothService: BluetoothServiceProtocol,
        persistenceService: PersistenceServiceProtocol,
        authService: SupabaseAuthService,
        existingProfile: PlayerProfile?,
        profileSyncService: UserProfileSyncService = UserProfileSyncService()
    ) {
        self.bluetoothService = bluetoothService
        self.persistenceService = persistenceService
        self.authService = authService
        self.existingProfile = existingProfile
        self.profileSyncService = profileSyncService
        playerName = existingProfile?.name ?? ""
        playerLocation = existingProfile?.locationName ?? ""
        dominantArm = existingProfile?.dominantArm ?? .right
        skillLevel = existingProfile?.skillLevel ?? .beginner
        authEmail = authService.currentUserEmail ?? ""
    }

    var canContinueFromProfile: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !playerLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUseReturningUser: Bool {
        !authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !authPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !authService.isAuthenticating
    }

    var isAuthenticating: Bool {
        authService.isAuthenticating
    }

    var authErrorMessage: String? {
        authService.authErrorMessage
    }

    var authStatusMessage: String? {
        authService.authStatusMessage
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

    func goBack() {
        guard let previous = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func signInWithEmail() async {
        await authService.signIn(email: authEmail, password: authPassword)
        authEmail = authService.currentUserEmail ?? authEmail
    }

    func continueFromProfile() async {
        onboardingErrorMessage = nil

        // If the user is already signed in (e.g. returning here after sign-in
        // bumped them to fill out missing local fields), no account work needed.
        if authService.isAuthenticated {
            advance()
            return
        }

        // Otherwise, register a Supabase account with the email/password the
        // user typed in this step. If the email already exists, fall back to
        // signing in so people can recover from a half-finished signup.
        let email = authEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = authPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty, !password.isEmpty else {
            onboardingErrorMessage = "Enter an email and password to create your account."
            return
        }

        await authService.signUp(email: email, password: password)

        // Supabase returns "user_already_exists" when the email is taken — try sign-in.
        if !authService.isAuthenticated,
           authService.authErrorMessage?.contains("already exists") == true {
            await authService.signIn(email: email, password: password)
        }

        guard authService.isAuthenticated else {
            // signUp / signIn already populated authErrorMessage — surface it.
            return
        }

        advance()
    }

    func signInReturningUser() async -> PlayerProfile? {
        await signInWithEmail()

        guard authService.isAuthenticated,
              let userID = authService.currentUserID,
              let accessToken = authService.accessToken
        else {
            return nil
        }

        // 1. Try to pull the user's profile from Supabase (returning users on a new device).
        var remoteProfile: RemoteUserProfile?
        do {
            remoteProfile = try await profileSyncService.fetchProfile(
                userID: userID,
                accessToken: accessToken
            )
        } catch {
            // Network failure is fine — fall back to local profile if there is one.
        }

        // 2. Decide which fields to save locally. Order of preference:
        //    remote profile > existing local profile > what's already typed in the form.
        if let remote = remoteProfile, !remote.displayName.isEmpty {
            playerName     = remote.displayName
            playerLocation = remote.homeCity
            return saveProfile(
                paddleName: remote.paddleName.isEmpty
                    ? (existingProfile?.syncedPaddleName ?? "Mock Paddle")
                    : remote.paddleName,
                supabaseUserID: userID
            )
        }

        if let existingProfile {
            playerName     = existingProfile.name
            playerLocation = existingProfile.locationName
            dominantArm    = existingProfile.dominantArm
            skillLevel     = existingProfile.skillLevel
            return saveProfile(
                paddleName: existingProfile.syncedPaddleName,
                supabaseUserID: userID
            )
        }

        // 3. No remote profile, no local profile → finish onboarding by hand.
        onboardingErrorMessage = "Signed in. Build your profile to finish setup on this device."
        currentStep = .playerProfile
        return nil
    }

    func completeOnboarding() -> PlayerProfile? {
        saveProfile(
            paddleName: bluetoothService.connectedDevice?.name ?? selectedDevice?.name ?? "Mock Paddle",
            supabaseUserID: authService.currentUserID
        )
    }

    private func saveProfile(paddleName: String, supabaseUserID: UUID? = nil) -> PlayerProfile? {
        do {
            let profile = try persistenceService.saveProfile(
                name: playerName,
                locationName: playerLocation,
                dominantArm: dominantArm,
                skillLevel: skillLevel,
                paddleName: paddleName,
                supabaseUserID: supabaseUserID
            )
            onboardingErrorMessage = nil
            return profile
        } catch {
            onboardingErrorMessage = "Could not finish onboarding. Reset saved app data and try again."
            return nil
        }
    }

}
