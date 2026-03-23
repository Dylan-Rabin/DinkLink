import Foundation
import Observation

@MainActor
// Root app state lives in an observable view model so SwiftUI can track reads
// without the older ObservableObject/@Published pattern.
@Observable
final class AppViewModel {
    func bootstrapIfNeeded(persistenceService: PersistenceServiceProtocol) {
        persistenceService.seedSampleSessionsIfNeeded()
    }
}
