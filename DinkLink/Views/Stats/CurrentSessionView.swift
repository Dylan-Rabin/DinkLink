import SwiftUI

struct CurrentSessionView: View {
  let profile: PlayerProfile
  let bluetoothService: MockBluetoothService
  let authService: SupabaseAuthService
  let persistenceService: PersistenceServiceProtocol
  var onSessionSaved: (() -> Void)? = nil

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
            LiveWorkoutDashboard(
              viewModel: viewModel,
              onStartOver: {
                liveViewModel = nil
              }
            )
          } else {
            startCard
          }
        }
        .padding(20)
      }
    }
    .navigationTitle("Current Session")
    .navigationBarTitleDisplayMode(.inline)
    .dinkBackButton()
    .toolbarColorScheme(.dark, for: .navigationBar)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Current Session")
        .dinkHeading(30, color: AppTheme.neon)

      Text("Track your performance live while you play.")
        .dinkBody(14, color: AppTheme.smoke)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var startCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Start Gameplay")
        .dinkHeading(22, color: AppTheme.smoke)

      Text("Tap start when you are ready to begin tracking your match.")
        .dinkBody(13, color: AppTheme.ash)

      Button("Start Session") {
        startSession()
      }
      .buttonStyle(.borderedProminent)
      .tint(AppTheme.neon)
      .foregroundStyle(AppTheme.ink)

      VStack(alignment: .leading, spacing: 8) {
        Text("Live session will track:")
          .dinkBody(12, color: AppTheme.ash)

        Text("• Elapsed time")
          .dinkBody(12, color: AppTheme.smoke)
        Text("• Swing speed")
          .dinkBody(12, color: AppTheme.smoke)
        Text("• Sweet spot rate")
          .dinkBody(12, color: AppTheme.smoke)
        Text("• Hits")
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
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
    )
  }

  private func startSession() {
    liveViewModel = LiveGameViewModel(
      mode: .theRealDeal,
      players: [profile.asPlayer],
      bluetoothService: bluetoothService,
      persistenceService: persistenceService,
      authService: authService,
      progressionPersistenceService: SupabaseProgressionPersistenceService(),
      ownerProfileID: profile.id,
      onSessionSaved: onSessionSaved
    )
  }
}

private struct LiveWorkoutDashboard: View {
    @Bindable var viewModel: LiveGameViewModel
       let onStartOver: () -> Void

    private var intensityLabel: String {
        switch viewModel.latestSwingSpeed {
        case 40...:
            return "HIGH 🔥"
        case 25..<40:
            return "MEDIUM ⚡️"
        default:
            return "LOW"
        }
    }

  private var intensityColor: Color {
    switch viewModel.latestSwingSpeed {
    case 40...:
      return AppTheme.neon
    case 25..<40:
      return AppTheme.smoke
    default:
      return AppTheme.ash
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      if viewModel.isSessionComplete {
        completionCard
      }

      controlButtons
      timerCard
      liveStatsCard

      if viewModel.isSessionComplete {
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

  private var controlButtons: some View {
    HStack(spacing: 12) {
      Button("End Session") {
        viewModel.endSessionEarly()
      }
      .buttonStyle(.borderedProminent)
      .tint(AppTheme.neon)
      .foregroundStyle(AppTheme.ink)
      .disabled(viewModel.isSessionComplete)
    }
  }

  private var timerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Session Live")
        .dinkHeading(20, color: AppTheme.smoke)

      Text(formattedTime(viewModel.elapsedSeconds))
        .font(.system(size: 54, weight: .bold, design: .rounded))
        .foregroundStyle(AppTheme.neon)
        .animation(.easeInOut(duration: 0.25), value: viewModel.elapsedSeconds)

      Text("Tracking your current session live.")
        .dinkBody(13, color: AppTheme.smoke)

      Text("Latest hit: \(formatted(viewModel.latestSwingSpeed)) mph")
        .dinkBody(12, color: AppTheme.ash)
        .animation(.easeInOut(duration: 0.2), value: viewModel.latestSwingSpeed)

      Text("Intensity: \(intensityLabel)")
        .dinkBody(13, color: intensityColor)
        .animation(.easeInOut(duration: 0.2), value: viewModel.latestSwingSpeed)
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
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
    )
  }

  private var liveStatsCard: some View {
    let stats = viewModel.overallStats

    return VStack(alignment: .leading, spacing: 14) {
      Text("Live Stats")
        .dinkHeading(18, color: AppTheme.smoke)

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 10),
          GridItem(.flexible(), spacing: 10)
        ],
        spacing: 10
      ) {
        statTile(title: "Avg Swing", value: "\(formatted(stats.average)) mph")
        statTile(title: "Max Swing", value: "\(formatted(stats.max)) mph")
        statTile(title: "Sweet Spot", value: "\(formatted(stats.sweetSpot, decimals: 0))%")
        statTile(title: "Hits", value: "\(stats.totalHits)")
      }

      liveSummaryRow(title: "Average Swing Speed", value: "\(formatted(stats.average)) mph")
      liveSummaryRow(title: "Max Swing Speed", value: "\(formatted(stats.max)) mph")
      liveSummaryRow(title: "Sweet Spot", value: "\(formatted(stats.sweetSpot, decimals: 0))%")
      liveSummaryRow(title: "Total Hits", value: "\(stats.totalHits)")
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
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
    )
  }

  private var completionCard: some View {
    let stats = viewModel.overallStats

    return VStack(alignment: .leading, spacing: 8) {
      Text("Session Complete")
        .dinkHeading(20, color: AppTheme.ink)

      Text("Hits: \(stats.totalHits)")
        .dinkBody(13, color: AppTheme.ink)

      Text("Avg Speed: \(formatted(stats.average)) mph")
        .dinkBody(13, color: AppTheme.ink)

      Text("Sweet Spot: \(formatted(stats.sweetSpot, decimals: 0))%")
        .dinkBody(13, color: AppTheme.ink)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.neon)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func statTile(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .dinkBody(10, color: AppTheme.ash)

      Text(value)
        .dinkHeading(16, color: AppTheme.neon)
    }
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
    .padding(12)
    .background(AppTheme.graphite.opacity(0.9))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func liveSummaryRow(title: String, value: String) -> some View {
    HStack {
      Text(title)
        .dinkBody(13, color: AppTheme.smoke)

      Spacer()

      Text(value)
        .dinkBody(14, color: AppTheme.neon)
    }
  }

  private func formatted(_ value: Double, decimals: Int = 1) -> String {
    String(format: "%.\(decimals)f", value)
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

