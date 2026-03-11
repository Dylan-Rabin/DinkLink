import SwiftData
import SwiftUI

struct MainTabView: View {
    let profile: PlayerProfile
    let sessions: [StoredGameSession]
    let bluetoothService: MockBluetoothService

    var body: some View {
        TabView {
            HomeView(profile: profile, bluetoothService: bluetoothService)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            StatsView(profile: profile, sessions: displaySessions)
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }

            RecentScoresView(sessions: displaySessions)
                .tabItem {
                    Label("Scores", systemImage: "clock.arrow.circlepath")
                }

            ProfileView(profile: profile, bluetoothService: bluetoothService)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(AppTheme.neon)
    }

    private var displaySessions: [StoredGameSession] {
        sessions.isEmpty ? SampleData.sampleSessions : sessions
    }
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: PlayerProfile
    let bluetoothService: MockBluetoothService

    @State private var selectedMode: GameMode?
    @State private var courtLocation: CourtLocation?
    @State private var currentConditions: CourtCurrentConditions?
    @State private var isLoadingWeather = false
    @State private var weatherErrorMessage: String?

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.deepShadow, AppTheme.graphite, AppTheme.steel, AppTheme.mutedGlow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(AppTheme.mutedGlow)
                    .frame(width: 340, height: 340)
                    .blur(radius: 110)
                    .offset(x: 160, y: -220)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back, \(profile.name)")
                                .dinkHeading(30, color: AppTheme.neon)
                            Text("Synced paddle: \(bluetoothService.connectedDevice?.name ?? profile.syncedPaddleName)")
                                .dinkBody(13, color: AppTheme.ash)
                        }

                        todayWeatherSection

                        LazyVGrid(columns: grid, spacing: 16) {
                            ForEach(GameMode.allCases) { mode in
                                SportCard(
                                    title: mode.rawValue,
                                    subtitle: mode.subtitle,
                                    accent: color(for: mode)
                                ) {
                                    selectedMode = mode
                                }
                            }
                        }

                        if let device = bluetoothService.connectedDevice {
                            HStack {
                                Label(device.name, systemImage: "dot.radiowaves.left.and.right")
                                Spacer()
                                Text("\(device.batteryLevel)%")
                            }
                            .dinkBody(13, color: AppTheme.smoke)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.steel, AppTheme.graphite],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(20)
                }
            }
            .task(id: profile.locationName) {
                await loadTodayWeather()
            }
            .navigationDestination(item: $selectedMode) { mode in
                InviteSetupView(
                    primaryPlayer: profile.asPlayer,
                    mode: mode,
                    bluetoothService: bluetoothService,
                    persistenceService: SwiftDataPersistenceService(context: modelContext)
                )
            }
        }
    }

    private var todayWeatherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today on Court")
                        .dinkHeading(20, color: AppTheme.smoke)

                    Text(courtLocation?.name ?? profile.locationName)
                        .dinkBody(12, color: AppTheme.ash)
                }

                Spacer()

                if isLoadingWeather {
                    ProgressView()
                        .tint(AppTheme.neon)
                }
            }

            if let currentConditions {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int(currentConditions.temperature.rounded()))°F")
                            .dinkHeading(24, color: AppTheme.neon)
                        Text(currentConditions.summary)
                            .dinkBody(13, color: AppTheme.smoke)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Wind \(Int(currentConditions.windSpeed.rounded())) mph")
                            .dinkBody(12, color: AppTheme.ash)
                        Text(currentConditions.isPlayable ? "Good court window" : "Tough court window")
                            .dinkBody(12, color: currentConditions.isPlayable ? AppTheme.neon : AppTheme.ash)
                    }
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [AppTheme.steel, AppTheme.graphite],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if let weatherErrorMessage {
                Text(weatherErrorMessage)
                    .dinkBody(12, color: AppTheme.ash)
            }
        }
    }

    private func color(for mode: GameMode) -> Color {
        switch mode {
        case .dinkSinks:
            return AppTheme.neon
        case .volleyWallies:
            return AppTheme.ash
        case .theRealDeal:
            return AppTheme.smoke
        case .pickleCup:
            return AppTheme.neon.opacity(0.75)
        }
    }

    @MainActor
    private func loadTodayWeather() async {
        guard !profile.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isLoadingWeather = true
        weatherErrorMessage = nil
        currentConditions = nil

        do {
            // Networking requirement: resolve the saved onboarding location, then fetch
            // live conditions for that player-specific place using async URLSession calls.
            let location = try await CourtWeatherService.resolveLocation(named: profile.locationName)
            courtLocation = location
            currentConditions = try await CourtWeatherService.fetchCurrentConditions(for: location)
        } catch {
            weatherErrorMessage = "Today's weather is unavailable for \(profile.locationName)."
        }

        isLoadingWeather = false
    }
}

private struct CourtLocation {
    let name: String
    let latitude: Double
    let longitude: Double
}

private struct CourtCurrentConditions {
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

private enum CourtWeatherService {
    static func resolveLocation(named query: String) async throws -> CourtLocation {
        let url = try geocodingURL(for: query)
        let (data, _) = try await URLSession.shared.data(from: url)
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

    static func fetchCurrentConditions(for location: CourtLocation) async throws -> CourtCurrentConditions {
        let url = try currentConditionsURL(for: location)
        let (data, _) = try await URLSession.shared.data(from: url)
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

    private static func geocodingURL(for query: String) throws -> URL {
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

    private static func currentConditionsURL(for location: CourtLocation) throws -> URL {
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

    private static func formattedLocationName(from result: OpenMeteoGeocodingResponse.ResultPayload) -> String {
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

private struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: PlayerProfile
    let bluetoothService: MockBluetoothService

    @State private var locationName: String
    @State private var dominantArm: DominantArm
    @State private var skillLevel: SkillLevel
    @State private var saveMessage: String?

    init(profile: PlayerProfile, bluetoothService: MockBluetoothService) {
        self.profile = profile
        self.bluetoothService = bluetoothService
        _locationName = State(initialValue: profile.locationName)
        _dominantArm = State(initialValue: profile.dominantArm)
        _skillLevel = State(initialValue: profile.skillLevel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.deepShadow, AppTheme.graphite, AppTheme.steel, AppTheme.mutedGlow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(AppTheme.mutedGlow)
                    .frame(width: 320, height: 320)
                    .blur(radius: 110)
                    .offset(x: -140, y: -260)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Profile")
                                .dinkHeading(30, color: AppTheme.neon)

                            Text(profile.name)
                                .dinkBody(13, color: AppTheme.ash)

                            Text("Update your home court location and player settings.")
                                .dinkBody(14, color: AppTheme.smoke)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Player Settings")
                                .dinkHeading(20, color: AppTheme.smoke)

                            Text("Name")
                                .dinkBody(11, color: AppTheme.ash)

                            Text(profile.name)
                                .dinkBody(14, color: AppTheme.smoke)

                            Text("Location")
                                .dinkBody(11, color: AppTheme.ash)

                            TextField("City or ZIP code", text: $locationName)
                                .font(.dinkBody(15))
                                .foregroundStyle(AppTheme.ink)
                                .tint(AppTheme.ink)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(AppTheme.smoke)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Text("Dominant Arm")
                                .dinkBody(11, color: AppTheme.ash)

                            Picker("Dominant Arm", selection: $dominantArm) {
                                ForEach(DominantArm.allCases) { arm in
                                    Text(arm.rawValue).tag(arm)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Skill Level")
                                .dinkBody(11, color: AppTheme.ash)

                            Picker("Skill Level", selection: $skillLevel) {
                                ForEach(SkillLevel.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.graphite, AppTheme.steel],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Button("Save Changes") {
                                saveProfileChanges()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.neon)
                            .foregroundStyle(AppTheme.ink)
                            .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if let saveMessage {
                                Text(saveMessage)
                                    .dinkBody(12, color: AppTheme.ash)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.steel.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Paddle")
                                .dinkHeading(20, color: AppTheme.smoke)

                            detailRow(title: "Connected", value: bluetoothService.connectedDevice?.name ?? profile.syncedPaddleName)
                            detailRow(title: "Battery", value: "\(bluetoothService.connectedDevice?.batteryLevel ?? 100)%")
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.steel.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .dinkBody(13, color: AppTheme.ash)
            Spacer()
            Text(value)
                .dinkBody(13, color: AppTheme.smoke)
        }
    }

    @MainActor
    private func saveProfileChanges() {
        profile.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.dominantArmRawValue = dominantArm.rawValue
        profile.skillLevelRawValue = skillLevel.rawValue

        do {
            try modelContext.save()
            saveMessage = "Profile updated."
        } catch {
            saveMessage = "Couldn't save changes right now."
        }
    }
}
