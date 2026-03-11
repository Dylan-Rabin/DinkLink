import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    func bootstrapIfNeeded(persistenceService: PersistenceServiceProtocol) {
        persistenceService.seedSampleSessionsIfNeeded()
    }
}
