import SwiftUI

struct LiveGameView: View {
    @ObservedObject var viewModel: LiveGameViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                playerSwitcher
                liveMetrics

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
        .background(Color(.systemBackground))
        .navigationTitle(viewModel.mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
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
                .font(.title2.weight(.bold))

            if viewModel.activeMode.isTimed {
                Text("Timer: \(viewModel.secondsRemaining)s")
                    .font(.headline.monospacedDigit())
            } else {
                Text("Elapsed: \(viewModel.elapsedSeconds)s")
                    .font(.headline.monospacedDigit())
            }

            Text("Latest hit: \(formatted(viewModel.latestSwingSpeed)) mph")
                .foregroundStyle(.secondary)

            Text(viewModel.latestFeedback)
                .font(.headline)
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.black, .orange.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var playerSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Player")
                .font(.headline)

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
            }
        }
    }

    private var liveMetrics: some View {
        let stats = viewModel.overallStats

        return VStack(alignment: .leading, spacing: 12) {
            Text("Live Sensor Summary")
                .font(.headline)

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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rallyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Rally Tracking")
                .font(.headline)

            Text("Current rally hits: \(viewModel.currentRallyHits)")
                .foregroundStyle(.secondary)

            ForEach(Array(viewModel.playerMetrics.enumerated()), id: \.offset) { index, metrics in
                Button("Award Point to \(metrics.player.name)") {
                    viewModel.awardPoint(to: index)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Scoreboard")
                .font(.headline)

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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var completionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session Complete")
                .font(.title3.weight(.bold))
            Text("\(viewModel.sessionWinner) wins.")
            if viewModel.mode == .pickleCup {
                Text("Cup score: \(viewModel.cupWins.map(String.init).joined(separator: " - "))")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
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
}
