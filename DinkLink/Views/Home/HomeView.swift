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

            StatsView(profile: profile, sessions: sessions)
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }

            RecentScoresView(sessions: sessions)
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
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: PlayerProfile
    let bluetoothService: MockBluetoothService

    @State private var selectedMode: GameMode?

    private let grid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.ink, AppTheme.graphite, AppTheme.steel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back, \(profile.name)")
                                .dinkHeading(30, color: AppTheme.neon)
                            Text("Synced paddle: \(bluetoothService.connectedDevice?.name ?? profile.syncedPaddleName)")
                                .dinkBody(13, color: AppTheme.ash)
                        }

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
                            .background(AppTheme.steel)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(20)
                }
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
    let profile: PlayerProfile
    let bluetoothService: MockBluetoothService

    var body: some View {
        NavigationStack {
            List {
                Section("Player") {
                    LabeledContent("Name", value: profile.name)
                    LabeledContent("Dominant Arm", value: profile.dominantArm.rawValue)
                    LabeledContent("Skill Level", value: profile.skillLevel.rawValue)
                }

                Section("Paddle") {
                    LabeledContent("Connected", value: bluetoothService.connectedDevice?.name ?? profile.syncedPaddleName)
                    LabeledContent("Battery", value: "\(bluetoothService.connectedDevice?.batteryLevel ?? 100)%")
                }
            }
            .navigationTitle("Profile")
        }
    }
}
