import Testing
@testable import DinkLink

@MainActor
struct DinkLinkTests {
    @Test
    func gameEngineCalculatesOverallAverages() async throws {
        let player = Player(name: "Dylan", dominantArm: .right, skillLevel: .intermediate)
        var metrics = PlayerGameMetrics(player: player)
        metrics.totalHits = 2
        metrics.totalImpactStrength = 1392
        metrics.maxImpactStrength = 742
        metrics.cumulativeMotionValue = 2.05
        metrics.cleanHits = 1

        let values = GameEngine.overallAverages(from: [metrics])

        #expect(values.averageImpactStrength == 696)
        #expect(values.maxImpactStrength == 742)
        #expect(values.averageMotion == 1.025)
        #expect(values.centerHitPercentage == 50)
        #expect(values.totalHits == 2)
    }
}
