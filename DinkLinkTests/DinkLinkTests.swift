import Testing
@testable import DinkLink

struct DinkLinkTests {
    @Test
    func gameEngineCalculatesOverallAverages() async throws {
        let player = Player(name: "Dylan", dominantArm: .right, skillLevel: .intermediate)
        var metrics = PlayerGameMetrics(player: player)
        metrics.totalHits = 2
        metrics.cumulativeSwingSpeed = 52
        metrics.maxSwingSpeed = 30
        metrics.sweetSpotHits = 1

        let values = GameEngine.overallAverages(from: [metrics])

        #expect(values.average == 26)
        #expect(values.max == 30)
        #expect(values.sweetSpot == 50)
        #expect(values.totalHits == 2)
    }
}
