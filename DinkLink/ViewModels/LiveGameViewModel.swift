import Foundation
import Observation

@MainActor
@Observable
final class LiveGameViewModel {
    var activePlayerIndex = 0
    var secondsRemaining = GameEngine.timedRoundLength
    var elapsedSeconds = 0
    var latestFeedback = "Waiting for live paddle data"
    var latestSwingSpeed: Double = 0
    var liveSwingSpeeds: [Double] = []
    var isPaused = false
    var currentRallyHits = 0
    var rallies: [Rally] = []
    var playerMetrics: [PlayerGameMetrics]
    var isSessionComplete = false
    var sessionWinner = ""
    var roundBanner = "Warm up the hands."
    var cupWins: [Int]
    var currentCupStageIndex = 0

    let mode: GameMode

    @ObservationIgnored
    private let bluetoothService: BluetoothServiceProtocol
    @ObservationIgnored
    private let persistenceService: PersistenceServiceProtocol
    @ObservationIgnored
    private let authService: SupabaseAuthService
    @ObservationIgnored
    private let progressionPersistenceService: ProgressionPersistenceServiceProtocol
    @ObservationIgnored
    private let sessionStartDate: Date
    @ObservationIgnored
    private var timer: Timer?
    @ObservationIgnored
    private var hasSaved = false

    init(
        mode: GameMode,
        players: [Player],
        bluetoothService: BluetoothServiceProtocol,
        persistenceService: PersistenceServiceProtocol,
        authService: SupabaseAuthService,
        progressionPersistenceService: ProgressionPersistenceServiceProtocol
    ) {
        self.mode = mode
        self.bluetoothService = bluetoothService
        self.persistenceService = persistenceService
        self.authService = authService
        self.progressionPersistenceService = progressionPersistenceService
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
        liveSwingSpeeds = []
        isPaused = false

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

    func togglePause() {
        guard !isSessionComplete else { return }

        isPaused.toggle()

        if isPaused {
            timer?.invalidate()
            timer = nil
            bluetoothService.stopStreaming()
            roundBanner = "Session paused."
        } else {
            bluetoothService.startStreaming()
            startTimer()
            roundBanner = "\(activePlayerName) is on court."
        }
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

    func endSessionEarly() {
        guard !isSessionComplete else { return }
        completeSession(winnerName: winnerNameForCurrentState())
    }

    private func ingest(shot: ShotEvent) {
        guard !isSessionComplete, !isPaused else { return }

        latestSwingSpeed = shot.speedMPH
        liveSwingSpeeds.append(shot.speedMPH)
        if liveSwingSpeeds.count > 20 {
            liveSwingSpeeds.removeFirst(liveSwingSpeeds.count - 20)
        }

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
        guard !isPaused else { return }

        elapsedSeconds += 1

        if activeMode.isTimed {
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                handleTimedRoundCompletion()
            }
        }
    }

    private func handleTimedRoundCompletion() {
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
        let sessionEndDate = Date.now
        let priorSessions = persistenceService.fetchSavedSessions()

        persistenceService.saveSession(
            SessionDraft(
                mode: mode,
                startDate: sessionStartDate,
                endDate: sessionEndDate,
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

        syncProgressionIfPossible(
            sessionEndDate: sessionEndDate,
            totalHits: stats.totalHits,
            sweetSpotPercentage: stats.sweetSpot,
            maxSwingSpeed: stats.max,
            priorSessions: priorSessions
        )
    }

    private func syncProgressionIfPossible(
        sessionEndDate: Date,
        totalHits: Int,
        sweetSpotPercentage: Double,
        maxSwingSpeed: Double,
        priorSessions: [StoredGameSession]
    ) {
        guard
            let userID = authService.currentUserID,
            let accessToken = authService.accessToken
        else {
            return
        }

        let previousProgression = ProgressionService.buildProgression(
            userID: userID.uuidString,
            sessions: priorSessions
        )

        let sessionStats = SessionStats(
            durationMinutes: max(1, Int(sessionEndDate.timeIntervalSince(sessionStartDate) / 60)),
            totalHits: totalHits,
            sweetSpotPercentage: sweetSpotPercentage,
            playedWithFriend: playerMetrics.count > 1,
            isNewSwingSpeedPB: maxSwingSpeed > (priorSessions.map(\.maxSwingSpeed).max() ?? 0),
            isNewSweetSpotPB: sweetSpotPercentage > (priorSessions.map(\.sweetSpotPercentage).max() ?? 0)
        )

        let awardResult = ProgressionService.applySessionXP(
            previous: previousProgression.progression,
            stats: sessionStats
        )

        Task {
            try? await progressionPersistenceService.applySessionAward(
                userID: userID,
                accessToken: accessToken,
                awardResult: awardResult,
                metadata: [
                    "mode": mode.rawValue,
                    "winner": sessionWinner,
                    "hits": String(totalHits)
                ]
            )
        }
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

    private func winnerNameForCurrentState() -> String {
        if mode == .pickleCup {
            if cupWins.contains(where: { $0 > 0 }) {
                return cupChampionName()
            }

            let winnerIndex = GameEngine.winnerIndex(for: activeMode, metrics: playerMetrics)
            return playerMetrics[winnerIndex].player.name
        }

        let winnerIndex = GameEngine.winnerIndex(for: activeMode, metrics: playerMetrics)
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
