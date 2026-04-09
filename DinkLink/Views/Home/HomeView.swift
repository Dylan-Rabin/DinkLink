import SwiftData
import SwiftUI

struct MainTabView: View {
    let profile: PlayerProfile
    let sessions: [StoredGameSession]
    let bluetoothService: MockBluetoothService
    let authService: SupabaseAuthService
    let onLogOut: (PlayerProfile) -> Void

    var body: some View {
        TabView {
            HomeView(profile: profile, bluetoothService: bluetoothService, authService: authService)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            StatsView(profile: profile, sessions: displaySessions)
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }

            RecentScoresView(profile: profile, sessions: sessions, authService: authService)
                .tabItem {
                    Label("Scores", systemImage: "clock.arrow.circlepath")
                }

            ProfileView(
                profile: profile,
                bluetoothService: bluetoothService,
                authService: authService,
                sessions: displaySessions,
                onLogOut: onLogOut
            )
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
    let authService: SupabaseAuthService

    @State private var viewModel: HomeViewModel
    @State private var selectedMode: GameMode?

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    init(
        profile: PlayerProfile,
        bluetoothService: MockBluetoothService,
        authService: SupabaseAuthService,
        weatherService: WeatherServiceProtocol = OpenMeteoWeatherService()
    ) {
        self.profile = profile
        self.bluetoothService = bluetoothService
        self.authService = authService
        _viewModel = State(initialValue: HomeViewModel(weatherService: weatherService))
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
                await viewModel.loadTodayWeather(for: profile.locationName)
            }
            .navigationDestination(item: $selectedMode) { mode in
                InviteSetupView(
                    primaryPlayer: profile.asPlayer,
                    mode: mode,
                    bluetoothService: bluetoothService,
                    persistenceService: SwiftDataPersistenceService(context: modelContext),
                    authService: authService
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

                    Text(viewModel.courtLocation?.name ?? profile.locationName)
                        .dinkBody(12, color: AppTheme.ash)
                }

                Spacer()

                if viewModel.isLoadingWeather {
                    ProgressView()
                        .tint(AppTheme.neon)
                }
            }

            if let currentConditions = viewModel.currentConditions {
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

            if let weatherErrorMessage = viewModel.weatherErrorMessage {
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
}
