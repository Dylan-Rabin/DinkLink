import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \StoredGameSession.endDate, order: .reverse) private var sessions: [StoredGameSession]

    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var bluetoothService = MockBluetoothService()
    @State private var locallyCompletedProfile: PlayerProfile?

    var body: some View {
        Group {
            if let profile = activeProfile {
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
                ) { profile in
                    locallyCompletedProfile = profile
                }
            }
        }
        .task {
            appViewModel.bootstrapIfNeeded(
                persistenceService: SwiftDataPersistenceService(context: modelContext)
            )
        }
    }

    private var activeProfile: PlayerProfile? {
        locallyCompletedProfile ?? completedProfile
    }

    private var completedProfile: PlayerProfile? {
        profiles.first(where: \.completedOnboarding)
    }
}

private struct OnboardingRootView: View {
    @StateObject private var viewModel: OnboardingViewModel
    let onComplete: (PlayerProfile) -> Void

    init(
        bluetoothService: MockBluetoothService,
        existingProfile: PlayerProfile?,
        persistenceService: PersistenceServiceProtocol,
        onComplete: @escaping (PlayerProfile) -> Void
    ) {
        self.onComplete = onComplete
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                bluetoothService: bluetoothService,
                persistenceService: persistenceService,
                existingProfile: existingProfile
            )
        )
    }

    var body: some View {
        OnboardingFlowView(viewModel: viewModel, onComplete: onComplete)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}
