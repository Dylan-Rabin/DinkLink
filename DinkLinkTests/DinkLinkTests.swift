import Testing
@testable import DinkLink

@MainActor
struct DinkLinkTests {
    @Test
    func gameEngineCalculatesOverallAverages() async throws {
        // Build one metrics sample with predictable values so the aggregate math
        // can be verified without any live game state involved.
        let player = Player(name: "Dylan", dominantArm: .right, skillLevel: .intermediate)
        var metrics = PlayerGameMetrics(player: player)
        metrics.totalHits = 2
        metrics.cumulativeSwingSpeed = 52
        metrics.maxSwingSpeed = 30
        metrics.sweetSpotHits = 1

        let values = GameEngine.overallAverages(from: [metrics])

        // These expectations confirm the average speed, peak speed, sweet spot rate,
        // and total hit count returned by the engine.
        #expect(values.average == 26)
        #expect(values.max == 30)
        #expect(values.sweetSpot == 50)
        #expect(values.totalHits == 2)
    }
}
