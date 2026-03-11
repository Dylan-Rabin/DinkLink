import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    private var hasBootstrapped = false

    func bootstrapIfNeeded(persistenceService: PersistenceServiceProtocol) {
        guard !hasBootstrapped else { return }
        persistenceService.seedSampleSessionsIfNeeded()
        hasBootstrapped = true
    }
}
