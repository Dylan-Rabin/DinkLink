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

    @State private var viewModel: HomeViewModel
    @State private var selectedMode: GameMode?

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    init(
        profile: PlayerProfile,
        bluetoothService: MockBluetoothService,
        weatherService: WeatherServiceProtocol = OpenMeteoWeatherService()
    ) {
        self.profile = profile
        self.bluetoothService = bluetoothService
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
