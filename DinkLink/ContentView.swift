import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \StoredGameSession.endDate, order: .reverse) private var sessions: [StoredGameSession]

    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var bluetoothService = MockBluetoothService()

    var body: some View {
        Group {
            if let profile = profiles.first, profile.completedOnboarding {
                MainTabView(
                    profile: profile,
                    sessions: sessions,
                    bluetoothService: bluetoothService
                )
            } else {
                OnboardingRootView(
                    bluetoothService: bluetoothService,
                    existingProfile: profiles.first,
                    persistenceService: SwiftDataPersistenceService(context: modelContext)
                )
            }
        }
        .task {
            appViewModel.bootstrapIfNeeded(
                persistenceService: SwiftDataPersistenceService(context: modelContext)
            )
        }
    }
}

private struct OnboardingRootView: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(
        bluetoothService: MockBluetoothService,
        existingProfile: PlayerProfile?,
        persistenceService: PersistenceServiceProtocol
    ) {
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                bluetoothService: bluetoothService,
                persistenceService: persistenceService,
                existingProfile: existingProfile
            )
        )
    }

    var body: some View {
        OnboardingFlowView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}
