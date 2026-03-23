import SwiftUI

struct LiveGameView: View {
    // The live game screen edits view-model state through bindings produced by
    // the Observation framework instead of ObservedObject.
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
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .dinkBody(14, color: AppTheme.smoke)
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
        .dinkBody(14, color: AppTheme.smoke)
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

            if viewModel.activeMode == .dinkSinks {
                metricRow(
                    title: "Best Streak",
                    value: "\(viewModel.playerMetrics[viewModel.activePlayerIndex].dinkBestStreak)"
                )
            }

            if viewModel.activeMode == .volleyWallies {
                metricRow(
                    title: "Valid Volleys",
                    value: "\(viewModel.playerMetrics[viewModel.activePlayerIndex].validVolleys)"
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .dinkBody(14, color: AppTheme.smoke)
    }

    private var rallyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Rally Tracking")
                .dinkHeading(18, color: AppTheme.smoke)

            Text("Current rally hits: \(viewModel.currentRallyHits)")
                .dinkBody(13, color: AppTheme.ash)

            ForEach(Array(viewModel.playerMetrics.enumerated()), id: \.offset) { index, metrics in
                Button("Award Point to \(metrics.player.name)") {
                    viewModel.awardPoint(to: index)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.ink)
            }
        }
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

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Scoreboard")
                .dinkHeading(18, color: AppTheme.smoke)

            ForEach(viewModel.playerMetrics) { metrics in
                HStack {
                    Text(metrics.player.name)
                    Spacer()
                    Text(scoreText(for: metrics))
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppTheme.steel, AppTheme.graphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .dinkBody(14, color: AppTheme.smoke)
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Complete")
                .dinkHeading(20, color: AppTheme.ink)
            Text("\(viewModel.sessionWinner) wins.")
                .dinkBody(14, color: AppTheme.ink)
            if viewModel.mode == .pickleCup {
                Text("Cup score: \(viewModel.cupWins.map(String.init).joined(separator: " - "))")
                    .dinkBody(13, color: AppTheme.graphite)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.neon)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .dinkBody(14, color: AppTheme.neon)
        }
    }

    private func scoreText(for metrics: PlayerGameMetrics) -> String {
        switch viewModel.mode {
        case .dinkSinks:
            return "\(metrics.dinkBestStreak)"
        case .volleyWallies:
            return "\(metrics.validVolleys)"
        case .theRealDeal:
            return "\(metrics.points)"
        case .pickleCup:
            guard let index = viewModel.playerMetrics.firstIndex(where: { $0.id == metrics.id }) else {
                return "0"
            }
            return "\(viewModel.cupWins[index])"
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
