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
                                summaryCard(title: "Hit Strength", value: GameEngine.hitStrengthLabel(impactStrength: Int(averageImpactStrength.rounded())))
                                summaryCard(title: "Peak Contact", value: GameEngine.hitStrengthLabel(impactStrength: maxImpactStrength))
                                summaryCard(title: "Motion", value: GameEngine.motionLabel(motionValue: averageMotion))
                                summaryCard(title: "Clean Hits", value: "\(formatted(centerHitPercentage, decimals: 0))%")
                            }

                            comparisonCard
                            impactTrendCard
                            motionTrendCard
                            zoneBreakdownCard
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

            Text("Track how impact strength, motion, and hit placement are trending.")
                .dinkBody(14, color: AppTheme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No sessions yet")
                .dinkHeading(22, color: AppTheme.smoke)

            Text("Finish a game and your paddle charts will populate here.")
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
                        title: "Hit Strength",
                        value: latest.averageImpactStrength,
                        baseline: averageImpactStrength,
                        unit: " strength"
                    )

                    comparisonRow(
                        title: "Motion",
                        value: latest.averageMotion,
                        baseline: averageMotion,
                        unit: ""
                    )

                    comparisonRow(
                        title: "Clean Hits",
                        value: latest.centerHitPercentage,
                        baseline: centerHitPercentage,
                        unit: "%"
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.steel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var impactTrendCard: some View {
        chartCard(
            title: "Impact Trend",
            subtitle: "Average hit quality across your recent sessions."
        ) {
            Chart(recentImpactPoints) { point in
                LineMark(
                    x: .value("Session", point.label),
                    y: .value("Average Impact", point.value)
                )
                .foregroundStyle(AppTheme.neon)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

                PointMark(
                    x: .value("Session", point.label),
                    y: .value("Average Impact", point.value)
                )
                .foregroundStyle(AppTheme.smoke)
            }
            .frame(height: 220)
        }
    }

    private var motionTrendCard: some View {
        chartCard(
            title: "Motion Trend",
            subtitle: "Average movement intensity across your recent sessions."
        ) {
            Chart(recentMotionPoints) { point in
                BarMark(
                    x: .value("Session", point.label),
                    y: .value("Average Motion", point.value)
                )
                .foregroundStyle(AppTheme.neon)
            }
            .frame(height: 220)
        }
    }

    private var zoneBreakdownCard: some View {
        chartCard(
            title: "Zone Breakdown",
            subtitle: "Lifetime totals by friendly paddle zones."
        ) {
            Chart(zoneSummaries) { summary in
                BarMark(
                    x: .value("Hits", summary.totalHits),
                    y: .value("Zone", summary.label)
                )
                .foregroundStyle(AppTheme.neon)
            }
            .frame(height: 220)
        }
    }

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .dinkHeading(20, color: AppTheme.smoke)

            VStack(spacing: 12) {
                ForEach(recentSessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.mode.rawValue)
                                    .dinkBody(14, color: AppTheme.smoke)
                                Text(session.endDate.formatted(date: .abbreviated, time: .shortened))
                                    .dinkBody(11, color: AppTheme.ash)
                            }

                            Spacer()

                            Text(session.winnerName)
                                .dinkBody(13, color: AppTheme.neon)
                        }

                        Text("Hit Strength \(GameEngine.hitStrengthLabel(impactStrength: Int(session.averageImpactStrength.rounded()))) • Motion \(GameEngine.motionLabel(motionValue: session.averageMotion)) • Clean Hits \(formatted(session.centerHitPercentage, decimals: 0))%")
                            .dinkBody(12, color: AppTheme.ash)
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
    }

    private var latestSession: StoredGameSession? {
        sessions.sorted { $0.endDate > $1.endDate }.first
    }

    private var averageImpactStrength: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.averageImpactStrength } / Double(sessions.count)
    }

    private var maxImpactStrength: Int {
        sessions.map(\.maxImpactStrength).max() ?? 0
    }

    private var averageMotion: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.averageMotion } / Double(sessions.count)
    }

    private var centerHitPercentage: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.centerHitPercentage } / Double(sessions.count)
    }

    private var recentSessions: [StoredGameSession] {
        Array(sessions.sorted { $0.endDate < $1.endDate }.suffix(4)).reversed()
    }

    private var recentImpactPoints: [TrendPoint] {
        Array(sessions.sorted { $0.endDate < $1.endDate }.suffix(6))
            .enumerated()
            .map { index, session in
                TrendPoint(id: session.id, label: "S\(index + 1)", value: session.averageImpactStrength)
            }
    }

    private var recentMotionPoints: [TrendPoint] {
        Array(sessions.sorted { $0.endDate < $1.endDate }.suffix(6))
            .enumerated()
            .map { index, session in
                TrendPoint(id: session.id, label: "S\(index + 1)", value: session.averageMotion)
            }
    }

    private var zoneSummaries: [ZoneSummary] {
        [
            ZoneSummary(label: "Top", totalHits: sessions.reduce(0) { $0 + $1.topHits }),
            ZoneSummary(label: "Bottom", totalHits: sessions.reduce(0) { $0 + $1.bottomHits }),
            ZoneSummary(label: "Left", totalHits: sessions.reduce(0) { $0 + $1.leftHits }),
            ZoneSummary(label: "Right", totalHits: sessions.reduce(0) { $0 + $1.rightHits }),
            ZoneSummary(label: "Front", totalHits: sessions.reduce(0) { $0 + $1.frontHits }),
            ZoneSummary(label: "Back", totalHits: sessions.reduce(0) { $0 + $1.backHits })
        ]
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
    }

    private func comparisonRow(
        title: String,
        value: Double,
        baseline: Double,
        unit: String
    ) -> some View {
        let delta = value - baseline
        let symbol = delta >= 0 ? "▲" : "▼"
        let latestLabel: String
        let deltaLabel: String

        if title == "Hit Strength" {
            latestLabel = GameEngine.hitStrengthLabel(impactStrength: Int(value.rounded()))
            deltaLabel = GameEngine.hitStrengthLabel(impactStrength: Int(abs(delta).rounded()))
        } else if title == "Motion" {
            latestLabel = GameEngine.motionLabel(motionValue: value)
            deltaLabel = GameEngine.motionLabel(motionValue: abs(delta))
        } else {
            latestLabel = "\(formatted(value, decimals: unit == "%" ? 0 : 2))\(unit)"
            deltaLabel = "\(formatted(abs(delta), decimals: unit == "%" ? 0 : 2))\(unit)"
        }

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .dinkBody(13, color: AppTheme.ash)

                Text("Latest: \(latestLabel)")
                    .dinkBody(14, color: AppTheme.smoke)
            }

            Spacer()

            Text("\(symbol) \(deltaLabel)")
                .dinkBody(14, color: delta >= 0 ? AppTheme.neon : AppTheme.ash)
        }
        .padding(14)
        .background(AppTheme.graphite.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
    }

    private func formatted(_ value: Double, decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

private struct TrendPoint: Identifiable {
    let id: UUID
    let label: String
    let value: Double
}

private struct ZoneSummary: Identifiable {
    let id = UUID()
    let label: String
    let totalHits: Int
}
