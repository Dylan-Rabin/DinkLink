import Charts
import SwiftUI

struct StatsView: View {
    let profile: PlayerProfile
    let sessions: [StoredGameSession]

    private let statsGrid = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

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
                        header

                        if sessions.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVGrid(columns: statsGrid, spacing: 14) {
                                summaryCard(title: "Avg Swing", value: "\(formatted(averageSwingSpeed)) mph")
                                summaryCard(title: "Top Speed", value: "\(formatted(maxSwingSpeed)) mph")
                                summaryCard(title: "Sweet Spot", value: "\(formatted(sweetSpotPercentage, decimals: 0))%")
                                summaryCard(title: "Total Hits", value: "\(totalHits)")
                            }

                            comparisonCard

                            chartCard(
                                title: "Sweet Spot Trend",
                                subtitle: "Contact quality across recent sessions."
                            ) {
                                Chart(sweetSpotPoints) { point in
                                    AreaMark(
                                        x: .value("Session", point.label),
                                        y: .value("Sweet Spot", point.sweetSpotPercentage)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.neon.opacity(0.25), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                    LineMark(
                                        x: .value("Session", point.label),
                                        y: .value("Sweet Spot", point.sweetSpotPercentage)
                                    )
                                    .interpolationMethod(.catmullRom)
                                    .foregroundStyle(AppTheme.neon)
                                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                                    PointMark(
                                        x: .value("Session", point.label),
                                        y: .value("Sweet Spot", point.sweetSpotPercentage)
                                    )
                                    .foregroundStyle(AppTheme.smoke)
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(AppTheme.ash)
                                    }
                                }
                                .frame(height: 220)
                            }

                            chartCard(
                                title: "Mode Breakdown",
                                subtitle: "How your total hits are distributed across game modes."
                            ) {
                                Chart(modeSummaries) { summary in
                                    BarMark(
                                        x: .value("Hits", summary.totalHits),
                                        y: .value("Mode", summary.mode.rawValue)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .foregroundStyle(color(for: summary.mode))
                                }
                                .chartXAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(AppTheme.ash)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel()
                                            .foregroundStyle(AppTheme.ash)
                                    }
                                }
                                .frame(height: 220)
                            }

                            recentSessionsCard
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stats")
                .dinkHeading(30, color: AppTheme.neon)

            Text("\(profile.name) • \(sessions.count) recorded \(sessions.count == 1 ? "session" : "sessions")")
                .dinkBody(13, color: AppTheme.ash)

            Text("Track how your swing speed, contact quality, and game volume are trending.")
                .dinkBody(14, color: AppTheme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No sessions yet")
                .dinkHeading(22, color: AppTheme.smoke)

            Text("Finish a game and your charts will populate here.")
                .dinkBody(14, color: AppTheme.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(AppTheme.steel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Latest Session Comparison")
                .dinkHeading(20, color: AppTheme.smoke)

            if let latest = latestSession {
                VStack(spacing: 12) {
                    comparisonRow(
                        title: "Swing Speed",
                        value: latest.averageSwingSpeed,
                        baseline: averageSwingSpeed,
                        unit: "mph"
                    )

                    comparisonRow(
                        title: "Sweet Spot",
                        value: latest.sweetSpotPercentage,
                        baseline: sweetSpotPercentage,
                        unit: "%"
                    )

                    comparisonRow(
                        title: "Hits",
                        value: Double(latest.totalHits),
                        baseline: averageHitsPerSession,
                        unit: ""
                    )
                }
            } else {
                Text("No recent session to compare yet.")
                    .dinkBody(13, color: AppTheme.ash)
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
    }

    private func comparisonRow(
        title: String,
        value: Double,
        baseline: Double,
        unit: String
    ) -> some View {
        let delta = value - baseline
        let symbol = delta >= 0 ? "▲" : "▼"
        let valueDecimals = unit == "%" ? 0 : 1
        let deltaDecimals = unit == "%" ? 0 : 1

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dinkBody(13, color: AppTheme.ash)

                Text("Latest: \(formatted(value, decimals: valueDecimals))\(unit)")
                    .dinkBody(14, color: AppTheme.smoke)
            }

            Spacer()

            Text("\(symbol) \(formatted(abs(delta), decimals: deltaDecimals))\(unit)")
                .dinkBody(14, color: delta >= 0 ? AppTheme.neon : AppTheme.ash)
        }
        .padding(14)
        .background(AppTheme.graphite.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .dinkHeading(20, color: AppTheme.smoke)

            VStack(spacing: 12) {
                ForEach(recentSessions) { session in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.mode.rawValue)
                                .dinkBody(14, color: AppTheme.smoke)

                            Text(session.endDate.formatted(date: .abbreviated, time: .shortened))
                                .dinkBody(11, color: AppTheme.ash)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Winner")
                                .dinkBody(10, color: AppTheme.ash)

                            Text(session.winnerName)
                                .dinkBody(13, color: AppTheme.neon)
                        }
                    }
                    .padding(14)
                    .background(AppTheme.graphite.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
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
    }

    private var latestSession: StoredGameSession? {
        sessions.sorted { $0.endDate > $1.endDate }.first
    }

    private var averageHitsPerSession: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(totalHits) / Double(sessions.count)
    }

    private var averageSwingSpeed: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.averageSwingSpeed } / Double(sessions.count)
    }

    private var maxSwingSpeed: Double {
        sessions.map(\.maxSwingSpeed).max() ?? 0
    }

    private var sweetSpotPercentage: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.sweetSpotPercentage } / Double(sessions.count)
    }

    private var totalHits: Int {
        sessions.reduce(0) { $0 + $1.totalHits }
    }

    private var recentSessions: [StoredGameSession] {
        Array(sessions.sorted { $0.endDate < $1.endDate }.suffix(4)).reversed()
    }

    private var sweetSpotPoints: [SweetSpotTrendPoint] {
        Array(sessions.sorted { $0.endDate < $1.endDate }.suffix(6))
            .enumerated()
            .map { index, session in
                SweetSpotTrendPoint(
                    id: session.id,
                    label: "S\(index + 1)",
                    sweetSpotPercentage: session.sweetSpotPercentage
                )
            }
    }

    private var modeSummaries: [ModeSummary] {
        GameMode.allCases.compactMap { mode in
            let modeSessions = sessions.filter { $0.mode == mode }
            guard !modeSessions.isEmpty else { return nil }

            return ModeSummary(
                mode: mode,
                totalHits: modeSessions.reduce(0) { $0 + $1.totalHits },
                sessionCount: modeSessions.count
            )
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .dinkBody(11, color: AppTheme.ash)

            Text(value)
                .dinkHeading(20, color: AppTheme.neon)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(18)
        .background(AppTheme.steel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
        )
    }

    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .dinkHeading(20, color: AppTheme.smoke)

                Text(subtitle)
                    .dinkBody(12, color: AppTheme.ash)
            }

            content()
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

    private func formatted(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

private struct SweetSpotTrendPoint: Identifiable {
    let id: UUID
    let label: String
    let sweetSpotPercentage: Double
}

private struct ModeSummary: Identifiable {
    let mode: GameMode
    let totalHits: Int
    let sessionCount: Int

    var id: GameMode { mode }
}
