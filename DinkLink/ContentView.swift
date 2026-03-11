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
                OnboardingFlowView(
                    viewModel: OnboardingViewModel(
                        bluetoothService: bluetoothService,
                        persistenceService: SwiftDataPersistenceService(context: modelContext),
                        existingProfile: profiles.first
                    )
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

#Preview {
    ContentView()
        .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}
