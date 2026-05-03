import SwiftUI

struct CurrentSessionView: View {
    let profile: PlayerProfile
    let bluetoothService: MockBluetoothService
    let authService: SupabaseAuthService
    let persistenceService: PersistenceServiceProtocol

    @State private var liveViewModel: LiveGameViewModel?

    var body: some View {
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
                .offset(x: 160, y: -240)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let viewModel = liveViewModel {
                        LiveWorkoutDashboard(viewModel: viewModel) {
                            liveViewModel = nil
                        }
                    } else {
                        startCard
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Current Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Session")
                .dinkHeading(30, color: AppTheme.neon)
            Text("Track motion, clean hits, and game-ready feedback from the paddle.")
                .dinkBody(14, color: AppTheme.smoke)
        }
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start Gameplay")
                .dinkHeading(22, color: AppTheme.smoke)

            Text("Open a one-player live session to see friendly paddle feedback in real time.")
                .dinkBody(13, color: AppTheme.ash)

            Button("Start Session") {
                liveViewModel = LiveGameViewModel(
                    mode: .theRealDeal,
                    players: [profile.asPlayer],
                    bluetoothService: bluetoothService,
                    persistenceService: persistenceService,
                    authService: authService,
                    progressionPersistenceService: SupabaseProgressionPersistenceService(),
                    ownerProfileID: profile.id
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)

            VStack(alignment: .leading, spacing: 8) {
                Text("You’ll see:")
                    .dinkBody(12, color: AppTheme.ash)
                Text("• Hit Strength labels")
                    .dinkBody(12, color: AppTheme.smoke)
                Text("• Motion intensity labels")
                    .dinkBody(12, color: AppTheme.smoke)
                Text("• Favorite contact zones")
                    .dinkBody(12, color: AppTheme.smoke)
                Text("• Rally and control metrics")
                    .dinkBody(12, color: AppTheme.smoke)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct LiveWorkoutDashboard: View {
    @Bindable var viewModel: LiveGameViewModel
    let onStartOver: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            hero
            metricSection(title: "Game Metrics", metrics: viewModel.activeMetrics)
            metricSection(title: "Session Summary", metrics: viewModel.summaryMetrics)
            recentHitsCard
            controlButtons

            if viewModel.isSessionComplete {
                metricSection(title: "Final Results", metrics: viewModel.sessionResultMetrics)
                Button("Start New Session") {
                    onStartOver()
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.neon)
            }
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formattedTime(viewModel.elapsedSeconds))
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.neon)

            Text(viewModel.latestEvent != nil ? viewModel.latestFeedback : "Waiting for paddle movement.")
                .dinkBody(13, color: AppTheme.smoke)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.deepShadow, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func metricSection(title: String, metrics: [GameMetric]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .dinkHeading(18, color: AppTheme.smoke)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.title.uppercased())
                            .dinkBody(10, color: AppTheme.ash)
                        Text(metric.value)
                            .dinkHeading(16, color: AppTheme.neon)
                        if let subtitle = metric.subtitle {
                            Text(subtitle)
                                .dinkBody(11, color: AppTheme.smoke)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .padding(12)
                    .background(AppTheme.graphite.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var recentHitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Hits")
                .dinkHeading(18, color: AppTheme.smoke)

            if viewModel.recentEvents.isEmpty {
                Text("Recent hit labels will appear here once the paddle starts sending HIT lines.")
                    .dinkBody(13, color: AppTheme.ash)
            } else {
                ForEach(viewModel.recentEvents) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(GameEngine.zoneLabel(event.zone ?? .unknown))
                                .dinkBody(14, color: AppTheme.smoke)
                            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                .dinkBody(11, color: AppTheme.ash)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(GameEngine.hitStrengthLabel(impactStrength: event.impactStrength ?? 0))
                                .dinkBody(13, color: AppTheme.neon)
                            Text(GameEngine.motionLabel(motionValue: event.motionValue))
                                .dinkBody(12, color: AppTheme.ash)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.graphite.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(viewModel.isPaused ? "Resume" : "Pause") {
                viewModel.togglePause()
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
            .disabled(viewModel.isSessionComplete)

            Button("End Session") {
                viewModel.endSessionEarly()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
            .disabled(viewModel.isSessionComplete)
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    NavigationStack {
        CurrentSessionView(
            profile: PlayerProfile(
                name: "Dylan",
                locationName: "Austin, TX",
                dominantArm: .right,
                skillLevel: .intermediate,
                syncedPaddleName: "DL Pro Paddle",
                completedOnboarding: true
            ),
            bluetoothService: MockBluetoothService(),
            authService: SupabaseAuthService(
                storage: UserDefaults(suiteName: "CurrentSessionPreview") ?? .standard
            ),
            persistenceService: PreviewPersistenceService()
        )
    }
}

private struct PreviewPersistenceService: PersistenceServiceProtocol {
    func seedDylanSessions(profileID: UUID) {}
    func fetchSavedSessions() -> [StoredGameSession] { [] }

    func saveProfile(
        name: String,
        locationName: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String,
        supabaseUserID: UUID?
    ) throws -> PlayerProfile {
        PlayerProfile(
            id: supabaseUserID ?? UUID(),
            name: name,
            locationName: locationName,
            dominantArm: dominantArm,
            skillLevel: skillLevel,
            syncedPaddleName: paddleName,
            completedOnboarding: true
        )
    }

    func saveSession(_ draft: SessionDraft) {}
}
