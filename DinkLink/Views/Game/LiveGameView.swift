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
                    metricSection(title: "Game Metrics", metrics: viewModel.activeMetrics)
                    metricSection(title: "Session Summary", metrics: viewModel.summaryMetrics)
                    recentHitsCard
                    playerSwitcher
                    sessionControls

                    if viewModel.isSessionComplete {
                        metricSection(title: "Final Results", metrics: viewModel.sessionResultMetrics)
                    }
                }
                .padding(20)
            }

            if let rankUpAwardResult {
                RankUpCelebrationView(awardResult: rankUpAwardResult) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.dismissRankUpCelebration()
                    }
                }
            }
        }
        .navigationTitle(viewModel.mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .dinkBackButton()
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

            if let latestEvent = viewModel.latestEvent {
                Text(GameEngine.feedback(for: latestEvent))
                    .dinkBody(14, color: AppTheme.ink)
            } else {
                Text("Connect the paddle and start moving.")
                    .dinkBody(14, color: AppTheme.ink)
            }
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

    private func metricSection(title: String, metrics: [GameMetric]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .dinkHeading(18, color: AppTheme.smoke)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(metrics) { metric in
                    metricCard(metric)
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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metricCard(_ metric: GameMetric) -> some View {
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
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var recentHitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Hits")
                .dinkHeading(18, color: AppTheme.smoke)

            if viewModel.recentEvents.isEmpty {
                Text("Controlled contacts, drives, and center hits will appear here.")
                    .dinkBody(13, color: AppTheme.ash)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.recentEvents) { event in
                        HStack(alignment: .top) {
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

    private var sessionControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Controls")
                .dinkHeading(18, color: AppTheme.smoke)

            Button(viewModel.isPaused ? "Resume" : "Pause") {
                viewModel.togglePause()
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.neon)
            .disabled(viewModel.isSessionComplete)

            Button("Game Over") {
                viewModel.endSessionEarly()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
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

    private var rankUpAwardResult: XPAwardResult? {
        guard let awardResult = viewModel.latestXPAwardResult, awardResult.rankedUp else {
            return nil
        }
        return awardResult
    }

    private func formattedTime(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        let remainingSeconds = max(seconds, 0) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
