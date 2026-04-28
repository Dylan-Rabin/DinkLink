import Foundation
import SwiftData
import Observation

@MainActor
// Root app state lives in an observable view model so SwiftUI can track reads
// without the older ObservableObject/@Published pattern.
@Observable
final class AppViewModel {
    let networkMonitor = NetworkMonitor()
    let syncService = SyncService()

    @ObservationIgnored
    private var previouslyConnected = false
    @ObservationIgnored
    private var syncTask: Task<Void, Never>?

    /// Call once at app launch; also call after sign-in completes.
    /// Refreshes the access token first if it has expired, then syncs.
    func startSync(context: ModelContext, authService: SupabaseAuthService) {
        Task {
            // If session exists but token is stale, refresh before syncing.
            if authService.isAuthenticated && !authService.hasValidAccessToken {
                await authService.refreshSessionIfNeeded()
            }
            await syncService.syncAll(context: context, authService: authService)
        }
    }

    /// Called when NetworkMonitor.isConnected changes — triggers a sync pass
    /// only when transitioning from offline → online.
    func handleConnectivityChange(
        isConnected: Bool,
        context: ModelContext,
        authService: SupabaseAuthService
    ) {
        let wasOffline = !previouslyConnected
        previouslyConnected = isConnected

        guard isConnected, wasOffline, authService.isAuthenticated else { return }

        syncTask?.cancel()
        syncTask = Task {
            await syncService.syncAll(context: context, authService: authService)
        }
    }
}
