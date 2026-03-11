import Combine
import Foundation

@MainActor
final class LiveGameViewModel: ObservableObject {
    @Published var activePlayerIndex = 0
    @Published var secondsRemaining = GameEngine.timedRoundLength
    @Published var elapsedSeconds = 0
    @Published var latestFeedback = "Waiting for live paddle data"
    @Published var latestSwingSpeed: Double = 0
    @Published var currentRallyHits = 0
    @Published var rallies: [Rally] = []
    @Published var playerMetrics: [PlayerGameMetrics]
    @Published var isSessionComplete = false
    @Published var sessionWinner = ""
    @Published var roundBanner = "Warm up the hands."
    @Published var cupWins: [Int]
    @Published var currentCupStageIndex = 0

    let mode: GameMode

    private let bluetoothService: BluetoothServiceProtocol
    private let persistenceService: PersistenceServiceProtocol
    private let sessionStartDate: Date
    private var timer: Timer?
    private var hasSaved = false

    init(
        mode: GameMode,
        players: [Player],
        bluetoothService: BluetoothServiceProtocol,
        persistenceService: PersistenceServiceProtocol
    ) {
        self.mode = mode
        self.bluetoothService = bluetoothService
        self.persistenceService = persistenceService
        sessionStartDate = .now
        playerMetrics = players.map(PlayerGameMetrics.init)
        cupWins = Array(repeating: 0, count: players.count)
        configureRoundBanner()
    }

    deinit {
        timer?.invalidate()
    }

    var activeMode: GameMode {
        if mode == .pickleCup {
            switch currentCupStageIndex {
            case 0: return .dinkSinks
            case 1: return .volleyWallies
            default: return .theRealDeal
            }
        }
        return mode
    }

    var activePlayerName: String {
        playerMetrics[activePlayerIndex].player.name
    }

    var overallStats: (average: Double, max: Double, sweetSpot: Double, totalHits: Int) {
        GameEngine.overallAverages(from: playerMetrics)
    }

    func start() {
        bluetoothService.onShotEvent = { [weak self] shot in
            self?.ingest(shot: shot)
        }
        bluetoothService.startStreaming()
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        bluetoothService.stopStreaming()
    }

    func switchActivePlayer() {
        activePlayerIndex = (activePlayerIndex + 1) % playerMetrics.count
        roundBanner = "\(activePlayerName) is on court."
    }

    func awardPoint(to index: Int) {
        guard activeMode == .theRealDeal else { return }

        playerMetrics[index].points += 1
        let rally = Rally(
            initiatingPlayerName: activePlayerName,
            hits: max(currentRallyHits, 1),
            pointWinnerName: playerMetrics[index].player.name
        )
        rallies.insert(rally, at: 0)
        currentRallyHits = 0
        roundBanner = "\(playerMetrics[index].player.name) took the rally."

        if playerMetrics[index].points >= 5 {
            if mode == .pickleCup {
                cupWins[index] += 1
                completeSession(winnerName: cupChampionName())
            } else {
                completeSession(winnerName: playerMetrics[index].player.name)
            }
        }
    }

    private func ingest(shot: ShotEvent) {
        guard !isSessionComplete else { return }

        latestSwingSpeed = shot.speedMPH
        latestFeedback = GameEngine.feedback(for: shot)

        playerMetrics[activePlayerIndex].totalHits += 1
        playerMetrics[activePlayerIndex].cumulativeSwingSpeed += shot.speedMPH
        playerMetrics[activePlayerIndex].maxSwingSpeed = max(
            playerMetrics[activePlayerIndex].maxSwingSpeed,
            shot.speedMPH
        )

        if shot.hitSweetSpot {
            playerMetrics[activePlayerIndex].sweetSpotHits += 1
        }

        switch activeMode {
        case .dinkSinks:
            if shot.hitSweetSpot {
                playerMetrics[activePlayerIndex].dinkCurrentStreak += 1
            } else {
                playerMetrics[activePlayerIndex].dinkCurrentStreak = 0
            }

            playerMetrics[activePlayerIndex].dinkBestStreak = max(
                playerMetrics[activePlayerIndex].dinkBestStreak,
                playerMetrics[activePlayerIndex].dinkCurrentStreak
            )
        case .volleyWallies:
            if shot.speedMPH >= 15 {
                playerMetrics[activePlayerIndex].validVolleys += 1
            }
        case .theRealDeal:
            currentRallyHits += 1
        case .pickleCup:
            break
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(handleTimerTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func handleTimerTick() {
        elapsedSeconds += 1

        if activeMode.isTimed {
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                handleTimedRoundCompletion()
            }
        }
    }

    private func handleTimedRoundCompletion() {
        if playerMetrics.count > 1, activePlayerIndex == 0 {
            activePlayerIndex = 1
            secondsRemaining = GameEngine.timedRoundLength
            roundBanner = "\(activePlayerName), your turn starts now."
            return
        }

        if mode == .pickleCup {
            let winnerIndex = GameEngine.winnerIndex(for: activeMode, metrics: playerMetrics)
            cupWins[winnerIndex] += 1

            if currentCupStageIndex < 1 {
                currentCupStageIndex += 1
                activePlayerIndex = 0
                secondsRemaining = GameEngine.timedRoundLength
                configureRoundBanner()
            } else {
                currentCupStageIndex = 2
                activePlayerIndex = 0
                configureRoundBanner()
            }
            return
        }

        let winnerIndex = GameEngine.winnerIndex(for: activeMode, metrics: playerMetrics)
        completeSession(winnerName: playerMetrics[winnerIndex].player.name)
    }

    private func completeSession(winnerName: String) {
        stop()
        isSessionComplete = true
        sessionWinner = winnerName
        roundBanner = "\(winnerName) wins the session."
        persistIfNeeded()
    }

    private func persistIfNeeded() {
        guard !hasSaved else { return }
        hasSaved = true

        let stats = overallStats
        let playerOne = playerMetrics.first
        let playerTwo = playerMetrics.dropFirst().first

        let longestStreak = playerMetrics.map(\.dinkBestStreak).max() ?? 0
        let totalVolleys = playerMetrics.reduce(0) { $0 + $1.validVolleys }
        let bestRally = rallies.map(\.hits).max() ?? 0

        persistenceService.saveSession(
            SessionDraft(
                mode: mode,
                startDate: sessionStartDate,
                endDate: .now,
                playerOneName: playerOne?.player.name ?? "Player 1",
                playerTwoName: playerTwo?.player.name ?? "Solo Session",
                playerOneScore: playerOne?.points ?? roundScore(for: 0),
                playerTwoScore: playerTwo?.points ?? roundScore(for: 1),
                averageSwingSpeed: stats.average,
                maxSwingSpeed: stats.max,
                sweetSpotPercentage: stats.sweetSpot,
                totalHits: stats.totalHits,
                winnerName: sessionWinner,
                longestStreak: longestStreak,
                totalValidVolleys: totalVolleys,
                bestRallyLength: bestRally
            )
        )
    }

    private func roundScore(for index: Int) -> Int {
        guard playerMetrics.indices.contains(index) else { return 0 }

        switch mode {
        case .dinkSinks:
            return playerMetrics[index].dinkBestStreak
        case .volleyWallies:
            return playerMetrics[index].validVolleys
        case .theRealDeal:
            return playerMetrics[index].points
        case .pickleCup:
            return cupWins[index]
        }
    }

    private func cupChampionName() -> String {
        guard cupWins.count > 1 else { return playerMetrics.first?.player.name ?? "Champion" }
        let winnerIndex = cupWins[0] >= cupWins[1] ? 0 : 1
        return playerMetrics[winnerIndex].player.name
    }

    private func configureRoundBanner() {
        switch activeMode {
        case .dinkSinks:
            roundBanner = "Track the biggest dink streak."
            secondsRemaining = GameEngine.timedRoundLength
        case .volleyWallies:
            roundBanner = "Every clean volley counts."
            secondsRemaining = GameEngine.timedRoundLength
        case .theRealDeal:
            roundBanner = "Manual rally scoring to five."
        case .pickleCup:
            break
        }
    }
}
