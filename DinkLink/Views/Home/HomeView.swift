import SwiftData
import SwiftUI

struct MainTabView: View {
    let profile: PlayerProfile
    let sessions: [StoredGameSession]
    let bluetoothService: MockBluetoothService
    let authService: SupabaseAuthService
    let onLogOut: (PlayerProfile) -> Void
    var onSessionSaved: (() -> Void)? = nil

    var body: some View {
        TabView {
            HomeView(
                profile: profile,
                sessions: displaySessions,
                bluetoothService: bluetoothService,
                authService: authService
            )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            StatsView(profile: profile, sessions: sessions)
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
                sessions: sessions,
                onLogOut: onLogOut
            )
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
        .tint(AppTheme.neon)
    }

}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: PlayerProfile
    let sessions: [StoredGameSession]
    let bluetoothService: MockBluetoothService
    let authService: SupabaseAuthService
    var onSessionSaved: (() -> Void)? = nil

    @State private var viewModel: HomeViewModel
    @State private var selectedMode: GameMode?
    @State private var showCurrentSession = false   // I added a quick way to open the live session screen.

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    init(
        profile: PlayerProfile,
        sessions: [StoredGameSession],
        bluetoothService: MockBluetoothService,
        authService: SupabaseAuthService,
        onSessionSaved: (() -> Void)? = nil,
        weatherService: WeatherServiceProtocol = OpenMeteoWeatherService()
    ) {
        self.profile = profile
        self.sessions = sessions
        self.bluetoothService = bluetoothService
        self.authService = authService
        self.onSessionSaved = onSessionSaved
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
                            Text("\(homeProgression.rank.badgeTitle) • Level \(homeProgression.level)")
                                .dinkBody(12, color: AppTheme.smoke)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCurrentSession = true
                    } label: {
                        Image(systemName: "figure.pickleball")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .tint(AppTheme.neon)
                    .accessibilityLabel("Open Current Session")
                }
            }
            .task(id: profile.locationName) {
                await viewModel.loadTodayWeather(for: profile.locationName)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCurrentSession = true
                    } label: {
                        Image(systemName: "figure.pickleball")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .tint(AppTheme.neon)
                    .accessibilityLabel("Open Current Session")
                }
            }
            .navigationDestination(isPresented: $showCurrentSession) {
                CurrentSessionView(
                    profile: profile,
                    bluetoothService: bluetoothService,
                    authService: authService,
                    persistenceService: SwiftDataPersistenceService(context: modelContext),
                    onSessionSaved: onSessionSaved
                )
            }
            .navigationDestination(item: $selectedMode) { mode in
                InviteSetupView(
                    primaryPlayer: profile.asPlayer,
                    profileID: profile.id,
                    mode: mode,
                    bluetoothService: bluetoothService,
                    persistenceService: SwiftDataPersistenceService(context: modelContext),
                    authService: authService,
                    onSessionSaved: onSessionSaved
                )
            }
            .navigationDestination(isPresented: $showCurrentSession) {
                // I route the top-right icon into the live gameplay screen.
                CurrentSessionView(
                    profile: profile,
                    bluetoothService: bluetoothService,
                    authService: authService,
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

    private var homeProgression: UserProgression {
        ProgressionService.buildProgression(for: profile, sessions: sessions).progression
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
