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
                                .font(.headline)
                            Spacer()
                            Text(session.endDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(session.playerOneName) \(session.playerOneScore) - \(session.playerTwoScore) \(session.playerTwoName)")
                            .font(.subheadline.weight(.semibold))

                        Text("Winner: \(session.winnerName)")
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Recent Scores")
        }
    }
}
