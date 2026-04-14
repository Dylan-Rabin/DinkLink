import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \StoredGameSession.endDate, order: .reverse) private var allSessions: [StoredGameSession]

    // These reference types are owned by the root view, so with the Observation
    // framework they live in @State instead of @StateObject.
    @State private var appViewModel = AppViewModel()
    @State private var bluetoothService = MockBluetoothService()
    @State private var authService = SupabaseAuthService()
    @State private var locallyCompletedProfile: PlayerProfile?

    var body: some View {
        Group {
            if let profile = activeProfile {
                MainTabView(
                    profile: profile,
                    sessions: sessions(for: profile),
                    bluetoothService: bluetoothService,
                    authService: authService,
                    onLogOut: handleLogOut,
                    onSessionSaved: {
                        appViewModel.startSync(context: modelContext, authService: authService)
                    }
                )
            } else {
                OnboardingRootView(
                    bluetoothService: bluetoothService,
                    existingProfile: profiles.first,
                    persistenceService: SwiftDataPersistenceService(context: modelContext),
                    authService: authService,
                    onSignedIn: {
                        // Sync immediately when auth completes mid-onboarding
                        // so the user_profiles row is created/refreshed right away.
                        appViewModel.startSync(context: modelContext, authService: authService)
                    }
                ) { profile in
                    locallyCompletedProfile = profile
                    // Kick off a sync right after the user finishes onboarding.
                    appViewModel.startSync(context: modelContext, authService: authService)
                }
            }
        }
        .task {
            // Purge any sessions that have no ownerProfileID match (legacy seed data, etc.)
            let knownIDs = Set(profiles.map(\.id))
            let orphans = allSessions.filter { session in
                guard let ownerID = session.ownerProfileID else { return true }
                return !knownIDs.contains(ownerID)
            }
            orphans.forEach { modelContext.delete($0) }
            if !orphans.isEmpty { try? modelContext.save() }

            // Initial sync on launch if already signed in.
            appViewModel.startSync(context: modelContext, authService: authService)
        }
        // Re-sync whenever connectivity is restored.
        .onChange(of: appViewModel.networkMonitor.isConnected) { _, isConnected in
            appViewModel.handleConnectivityChange(
                isConnected: isConnected,
                context: modelContext,
                authService: authService
            )
        }
    }

    private var activeProfile: PlayerProfile? {
        locallyCompletedProfile ?? completedProfile
    }

    private var completedProfile: PlayerProfile? {
        // profile.id == auth UUID, so find the profile for the currently signed-in user.
        // Fall back to any completed profile for unauthenticated (demo) users.
        if let userID = authService.currentUserID {
            return profiles.first { $0.id == userID }
        }
        return profiles.first(where: \.completedOnboarding)
    }

    private func sessions(for profile: PlayerProfile) -> [StoredGameSession] {
        allSessions.filter { $0.ownerProfileID == profile.id }
    }


    @MainActor
    private func handleLogOut(_ profile: PlayerProfile) {
        authService.signOut()
        profile.completedOnboarding = false
        locallyCompletedProfile = nil

        do {
            try modelContext.save()
        } catch {
            // If the logout save fails, falling back to onboarding is still better than
            // leaving the UI in an inconsistent signed-in state.
        }
    }
}

private struct OnboardingRootView: View {
    // The onboarding flow owns its view model for the lifetime of this subtree.
    @State private var viewModel: OnboardingViewModel
    let onComplete: (PlayerProfile) -> Void

    init(
        bluetoothService: MockBluetoothService,
        existingProfile: PlayerProfile?,
        persistenceService: PersistenceServiceProtocol,
        authService: SupabaseAuthService,
        onSignedIn: @escaping () -> Void,
        onComplete: @escaping (PlayerProfile) -> Void
    ) {
        self.onComplete = onComplete
        var vm = OnboardingViewModel(
            bluetoothService: bluetoothService,
            persistenceService: persistenceService,
            authService: authService,
            existingProfile: existingProfile
        )
        vm.onSignedIn = onSignedIn
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        OnboardingFlowView(viewModel: viewModel, onComplete: onComplete)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}
