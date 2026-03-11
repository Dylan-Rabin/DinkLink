import SwiftUI

struct RecentScoresView: View {
    let sessions: [StoredGameSession]

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
                            VStack(spacing: 14) {
                                ForEach(sessions) { session in
                                    scoreCard(for: session)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scores")
                .dinkHeading(30, color: AppTheme.neon)

            Text("\(sessions.count) recent \(sessions.count == 1 ? "result" : "results")")
                .dinkBody(13, color: AppTheme.ash)

            Text("Review winners, scorelines, and session dates from your latest games.")
                .dinkBody(14, color: AppTheme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No scores yet")
                .dinkHeading(22, color: AppTheme.smoke)

            Text("Completed matches will appear here once sessions are recorded.")
                .dinkBody(14, color: AppTheme.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(AppTheme.steel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func scoreCard(for session: StoredGameSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.mode.rawValue)
                        .dinkHeading(18, color: AppTheme.smoke)

                    Text(session.endDate.formatted(date: .abbreviated, time: .shortened))
                        .dinkBody(11, color: AppTheme.ash)
                }

                Spacer()

                Text("WINNER")
                    .dinkBody(10, color: AppTheme.ash)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.playerOneName)
                        .dinkBody(13, color: AppTheme.smoke)
                    Text(session.playerTwoName)
                        .dinkBody(13, color: AppTheme.smoke)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(session.playerOneScore)")
                        .dinkHeading(20, color: AppTheme.neon)
                    Text("\(session.playerTwoScore)")
                        .dinkHeading(20, color: AppTheme.neon)
                }
            }

            Text("Winner: \(session.winnerName)")
                .dinkBody(13, color: AppTheme.neon)
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
}
