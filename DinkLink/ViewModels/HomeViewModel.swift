import Foundation
import Observation

@MainActor
// The home view model coordinates weather loading so the view renders state
// without owning API calls or response-mapping logic.
@Observable
final class HomeViewModel {
    var courtLocation: CourtLocation?
    var currentConditions: CourtCurrentConditions?
    var isLoadingWeather = false
    var weatherErrorMessage: String?

    @ObservationIgnored
    private let weatherService: WeatherServiceProtocol

    init(weatherService: WeatherServiceProtocol) {
        self.weatherService = weatherService
    }

    func loadTodayWeather(for locationName: String) async {
        guard !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoadingWeather = true
        weatherErrorMessage = nil
        currentConditions = nil

        do {
            // API usage: first convert the saved city/ZIP into coordinates with Open-Meteo's
            // geocoding endpoint, then request live current conditions for that location.
            let location = try await weatherService.resolveLocation(named: locationName)
            courtLocation = location
            currentConditions = try await weatherService.fetchCurrentConditions(for: location)
        } catch {
            weatherErrorMessage = "Today's weather is unavailable for \(locationName)."
        }

        isLoadingWeather = false
    }
}
