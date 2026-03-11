import Foundation

enum GameEngine {
    static let timedRoundLength = 60

    static func feedback(for shot: ShotEvent) -> String {
        switch (shot.hitSweetSpot, shot.speedMPH) {
        case (true, let speed) where speed >= 35:
            return "Sweet spot laser"
        case (true, _):
            return "Clean contact"
        case (false, let speed) where speed >= 30:
            return "Fast but off-center"
        default:
            return "Reset and reload"
        }
    }

    static func winnerIndex(
        for mode: GameMode,
        metrics: [PlayerGameMetrics]
    ) -> Int {
        guard metrics.count > 1 else { return 0 }

        switch mode {
        case .dinkSinks:
            return metrics[0].dinkBestStreak >= metrics[1].dinkBestStreak ? 0 : 1
        case .volleyWallies:
            return metrics[0].validVolleys >= metrics[1].validVolleys ? 0 : 1
        case .theRealDeal:
            return metrics[0].points >= metrics[1].points ? 0 : 1
        case .pickleCup:
            return 0
        }
    }

    static func overallAverages(from metrics: [PlayerGameMetrics]) -> (average: Double, max: Double, sweetSpot: Double, totalHits: Int) {
        let totalHits = metrics.reduce(0) { $0 + $1.totalHits }
        let speedSum = metrics.reduce(0.0) { $0 + $1.cumulativeSwingSpeed }
        let maxSpeed = metrics.map(\.maxSwingSpeed).max() ?? 0
        let sweetSpotHits = metrics.reduce(0) { $0 + $1.sweetSpotHits }
        let average = totalHits > 0 ? speedSum / Double(totalHits) : 0
        let sweetSpot = totalHits > 0 ? (Double(sweetSpotHits) / Double(totalHits)) * 100 : 0
        return (average, maxSpeed, sweetSpot, totalHits)
    }
}
