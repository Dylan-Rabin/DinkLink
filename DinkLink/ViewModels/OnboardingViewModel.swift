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
    var availableDevices: [PaddleDevice] = []
    var selectedDeviceID: UUID?
    var isScanning = false
    var isConnecting = false
    var onboardingErrorMessage: String?

    @ObservationIgnored
    private let bluetoothService: BluetoothServiceProtocol
    @ObservationIgnored
    private let persistenceService: PersistenceServiceProtocol

    init(
        bluetoothService: BluetoothServiceProtocol,
        persistenceService: PersistenceServiceProtocol,
        existingProfile: PlayerProfile?
    ) {
        self.bluetoothService = bluetoothService
        self.persistenceService = persistenceService
        playerName = existingProfile?.name ?? ""
        playerLocation = existingProfile?.locationName ?? ""
        dominantArm = existingProfile?.dominantArm ?? .right
        skillLevel = existingProfile?.skillLevel ?? .beginner
    }

    var canContinueFromProfile: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !playerLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    func completeOnboarding() -> PlayerProfile? {
        do {
            let profile = try persistenceService.saveProfile(
                name: playerName,
                locationName: playerLocation,
                dominantArm: dominantArm,
                skillLevel: skillLevel,
                paddleName: bluetoothService.connectedDevice?.name ?? selectedDevice?.name ?? "Mock Paddle"
            )
            onboardingErrorMessage = nil
            return profile
        } catch {
            onboardingErrorMessage = "Could not finish onboarding. Reset saved app data and try again."
            return nil
        }
    }
}
