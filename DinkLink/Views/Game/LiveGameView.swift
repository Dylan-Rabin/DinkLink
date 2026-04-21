import SwiftUI

struct LiveGameView: View {
    @Bindable var viewModel: LiveGameViewModel

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
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 170, y: -220)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    liveHud
                    playerSwitcher
                    liveMetrics
                    sessionControls

                    if viewModel.activeMode == .theRealDeal {
                        rallyControls
                    }

                    scoreboard

                    if viewModel.isSessionComplete {
                        completionCard
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(viewModel.mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // MARK: - NEW LIVE HUD

    private var liveHud: some View {
        let stats = viewModel.overallStats

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Live Stats")
                    .dinkHeading(18, color: AppTheme.smoke)

                Spacer()

                Text(viewModel.activePlayerName)
                    .dinkBody(12, color: AppTheme.ash)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                statTile(title: "Avg Swing", value: "\(formatted(stats.average)) mph")
                statTile(title: "Max Swing", value: "\(formatted(stats.max)) mph")
                statTile(title: "Sweet Spot", value: "\(formatted(stats.sweetSpot, decimals: 0))%")
                statTile(title: "Hits", value: "\(stats.totalHits)")
            }

            modeSpecificLiveStat
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
        )
    }

    private var modeSpecificLiveStat: some View {
        Group {
            switch viewModel.activeMode {
            case .dinkSinks:
                statRow(
                    title: "Best Streak",
                    value: "\(viewModel.playerMetrics[viewModel.activePlayerIndex].dinkBestStreak)"
                )

            case .volleyWallies:
                statRow(
                    title: "Valid Volleys",
                    value: "\(viewModel.playerMetrics[viewModel.activePlayerIndex].validVolleys)"
                )

            case .theRealDeal:
                statRow(
                    title: "Rally Hits",
                    value: "\(viewModel.currentRallyHits)"
                )

            case .pickleCup:
                statRow(
                    title: "Cup Stage",
                    value: "\(viewModel.currentCupStageIndex + 1)/3"
                )
            }
        }
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
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .dinkBody(13, color: AppTheme.ash)

            Spacer()

            Text(value)
                .dinkBody(14, color: AppTheme.neon)
        }
    }

    // MARK: - EXISTING CODE (UNCHANGED)

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.roundBanner)
                .dinkHeading(22, color: AppTheme.ink)

            if viewModel.activeMode.isTimed {
                Text("Timer: \(formattedTime(viewModel.secondsRemaining))")
                    .dinkBody(14, color: AppTheme.ink)
            } else {
                Text("Elapsed: \(formattedTime(viewModel.elapsedSeconds))")
                    .dinkBody(14, color: AppTheme.ink)
            }

            Text("Latest hit: \(formatted(viewModel.latestSwingSpeed)) mph")
                .dinkBody(13, color: AppTheme.graphite)

            Text(viewModel.latestFeedback)
                .dinkBody(14, color: AppTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.neon, AppTheme.ash],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Controls")
                .dinkHeading(18, color: AppTheme.smoke)

            Text(viewModel.activeMode.isTimed ? "Timed modes run on a single 1:00 countdown." : "End the session whenever the game is decided.")
                .dinkBody(13, color: AppTheme.ash)

            Button("Game Over") {
                viewModel.endSessionEarly()
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.neon)
            .disabled(viewModel.isSessionComplete)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var playerSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Player")
                .dinkHeading(18, color: AppTheme.smoke)

            Picker("Player", selection: $viewModel.activePlayerIndex) {
                ForEach(Array(viewModel.playerMetrics.enumerated()), id: \.offset) { index, metrics in
                    Text(metrics.player.name).tag(index)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.playerMetrics.count > 1 {
                Button("Switch Player Turn") {
                    viewModel.switchActivePlayer()
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.neon)
            }
        }
    }

    private var liveMetrics: some View {
        let stats = viewModel.overallStats

        return VStack(alignment: .leading, spacing: 12) {
            Text("Live Sensor Summary")
                .dinkHeading(18, color: AppTheme.smoke)

            metricRow(title: "Average Swing Speed", value: "\(formatted(stats.average)) mph")
            metricRow(title: "Max Swing Speed", value: "\(formatted(stats.max)) mph")
            metricRow(title: "Sweet Spot", value: "\(formatted(stats.sweetSpot, decimals: 0))%")
            metricRow(title: "Total Hits", value: "\(stats.totalHits)")
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var rallyControls: some View { EmptyView() }
    private var scoreboard: some View { EmptyView() }
    private var completionCard: some View { EmptyView() }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .dinkBody(14, color: AppTheme.smoke) // 👈 FIX

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
