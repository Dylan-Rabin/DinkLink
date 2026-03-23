import Foundation

struct CourtLocation {
    let name: String
    let latitude: Double
    let longitude: Double
}

struct CourtCurrentConditions {
    let temperature: Double
    let windSpeed: Double
    let weatherCode: Int

    var summary: String {
        WeatherCodeMapper.summary(for: weatherCode)
    }

    var isPlayable: Bool {
        windSpeed < 18 && !WeatherCodeMapper.isWet(weatherCode)
    }
}

protocol WeatherServiceProtocol {
    func resolveLocation(named query: String) async throws -> CourtLocation
    func fetchCurrentConditions(for location: CourtLocation) async throws -> CourtCurrentConditions
}

struct OpenMeteoWeatherService: WeatherServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolveLocation(named query: String) async throws -> CourtLocation {
        // API call: geocoding turns user-entered text such as "Austin" or a ZIP code
        // into latitude/longitude values the forecast API can understand.
        let url = try geocodingURL(for: query)
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)

        guard let result = response.results?.first else {
            throw CourtWeatherError.locationNotFound
        }

        return CourtLocation(
            name: formattedLocationName(from: result),
            latitude: result.latitude,
            longitude: result.longitude
        )
    }

    func fetchCurrentConditions(for location: CourtLocation) async throws -> CourtCurrentConditions {
        // API call: this requests today's live weather metrics that the Home screen renders
        // in the "Today on Court" card.
        let url = try currentConditionsURL(for: location)
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoCurrentResponse.self, from: data)

        guard let current = response.current else {
            throw CourtWeatherError.invalidResponse
        }

        return CourtCurrentConditions(
            temperature: current.temperature,
            windSpeed: current.windSpeed,
            weatherCode: current.weatherCode
        )
    }

    private func geocodingURL(for query: String) throws -> URL {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            throw CourtWeatherError.invalidURL
        }

        return url
    }

    private func currentConditionsURL(for location: CourtLocation) throws -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,wind_speed_10m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw CourtWeatherError.invalidURL
        }

        return url
    }

    private func formattedLocationName(from result: OpenMeteoGeocodingResponse.ResultPayload) -> String {
        if let admin = result.admin1, let country = result.country {
            return "\(result.name), \(admin), \(country)"
        }

        if let country = result.country {
            return "\(result.name), \(country)"
        }

        return result.name
    }
}

private enum CourtWeatherError: Error {
    case invalidURL
    case invalidResponse
    case locationNotFound
}

private enum WeatherCodeMapper {
    static func summary(for code: Int) -> String {
        switch code {
        case 0:
            return "Clear"
        case 1, 2:
            return "Partly Cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Fog"
        case 51, 53, 55, 61, 63, 65, 80, 81, 82:
            return "Rain"
        case 56, 57, 66, 67:
            return "Freezing Rain"
        case 71, 73, 75, 77, 85, 86:
            return "Snow"
        case 95, 96, 99:
            return "Storms"
        default:
            return "Mixed Conditions"
        }
    }

    static func isWet(_ code: Int) -> Bool {
        switch code {
        case 51 ... 67, 71 ... 86, 95 ... 99:
            return true
        default:
            return false
        }
    }
}

private struct OpenMeteoGeocodingResponse: Decodable {
    let results: [ResultPayload]?

    struct ResultPayload: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let admin1: String?
        let country: String?
    }
}

private struct OpenMeteoCurrentResponse: Decodable {
    let current: CurrentPayload?

    struct CurrentPayload: Decodable {
        let temperature: Double
        let windSpeed: Double
        let weatherCode: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case windSpeed = "wind_speed_10m"
            case weatherCode = "weather_code"
        }
    }
}
