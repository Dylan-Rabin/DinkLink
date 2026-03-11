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
        .tint(.orange)
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
                    colors: [Color(red: 0.06, green: 0.09, blue: 0.16), .black, Color(red: 0.18, green: 0.41, blue: 0.32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back, \(profile.name)")
                                .font(.largeTitle.weight(.black))
                                .foregroundStyle(.white)
                            Text("Synced paddle: \(bluetoothService.connectedDevice?.name ?? profile.syncedPaddleName)")
                                .foregroundStyle(.white.opacity(0.7))
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding()
                            .background(.white.opacity(0.08))
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
            return .teal
        case .volleyWallies:
            return .orange
        case .theRealDeal:
            return .red
        case .pickleCup:
            return .green
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
