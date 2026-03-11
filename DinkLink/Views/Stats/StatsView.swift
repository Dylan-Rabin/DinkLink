import SwiftUI

struct StatsView: View {
    let profile: PlayerProfile
    let sessions: [StoredGameSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statCard(title: "Average Swing Speed", value: "\(formatted(averageSwingSpeed)) mph")
                    statCard(title: "Max Swing Speed", value: "\(formatted(maxSwingSpeed)) mph")
                    statCard(title: "Sweet Spot Percentage", value: "\(formatted(sweetSpotPercentage, decimals: 0))%")
                    statCard(title: "Total Hits", value: "\(totalHits)")
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(profile.name)'s Stats")
        }
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

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func formatted(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
