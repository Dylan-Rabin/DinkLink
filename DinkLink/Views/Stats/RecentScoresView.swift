import SwiftUI

struct RecentScoresView: View {
    let sessions: [StoredGameSession]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.mode.rawValue)
                                .dinkHeading(16, color: AppTheme.smoke)
                            Spacer()
                            Text(session.endDate.formatted(date: .abbreviated, time: .shortened))
                                .dinkBody(11, color: AppTheme.ash)
                        }

                        Text("\(session.playerOneName) \(session.playerOneScore) - \(session.playerTwoScore) \(session.playerTwoName)")
                            .dinkBody(13, color: AppTheme.smoke)

                        Text("Winner: \(session.winnerName)")
                            .dinkBody(13, color: AppTheme.neon)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.steel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.ink)
            .navigationTitle("Recent Scores")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
