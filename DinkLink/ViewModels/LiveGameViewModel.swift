import Foundation
import Observation

@MainActor
@Observable
final class LiveGameViewModel {
    var activePlayerIndex = 0
    var secondsRemaining = GameEngine.timedRoundLength
    var elapsedSeconds = 0
    var latestFeedback = "Waiting for live paddle data"
    var latestEvent: PaddleEvent?
    var recentEvents: [PaddleEvent] = []
    var isPaused = false
    var rallies: [Rally] = []
    var playerMetrics: [PlayerGameMetrics]
    var isSessionComplete = false
    var sessionWinner = ""
    var roundBanner = "Warm up the hands."
    var cupWins: [Int]
    var currentCupStageIndex = 0
    var latestXPAwardResult: XPAwardResult?
    var cupStageScores: [[Double]]

    let mode: GameMode

    @ObservationIgnored private let bluetoothService: BluetoothServiceProtocol
    @ObservationIgnored private let persistenceService: PersistenceServiceProtocol
    @ObservationIgnored private let authService: SupabaseAuthService
    @ObservationIgnored private let progressionPersistenceService: ProgressionPersistenceServiceProtocol
    @ObservationIgnored private let sessionStartDate: Date
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var hasSaved = false
    @ObservationIgnored private let onSessionSaved: (() -> Void)?
    @ObservationIgnored private let ownerProfileID: UUID
    @ObservationIgnored private var lastDinkHitDates: [Date?]
    @ObservationIgnored private var lastVolleyHitDates: [Date?]
    @ObservationIgnored private var lastRallyHitDates: [Date?]
    @ObservationIgnored private var volleyMissArmed: [Bool]
    @ObservationIgnored private var rallyAwaitingClose: [Bool]

    init(
        mode: GameMode,
        players: [Player],
        bluetoothService: BluetoothServiceProtocol,
        persistenceService: PersistenceServiceProtocol,
        authService: SupabaseAuthService,
        progressionPersistenceService: ProgressionPersistenceServiceProtocol,
        ownerProfileID: UUID,
        onSessionSaved: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.bluetoothService = bluetoothService
        self.persistenceService = persistenceService
        self.authService = authService
        self.progressionPersistenceService = progressionPersistenceService
        self.ownerProfileID = ownerProfileID
        self.onSessionSaved = onSessionSaved
        self.sessionStartDate = .now
        self.playerMetrics = players.map(PlayerGameMetrics.init)
        self.cupWins = Array(repeating: 0, count: players.count)
        self.cupStageScores = Array(repeating: Array(repeating: 0, count: 3), count: players.count)
        self.lastDinkHitDates = Array(repeating: nil, count: players.count)
        self.lastVolleyHitDates = Array(repeating: nil, count: players.count)
        self.lastRallyHitDates = Array(repeating: nil, count: players.count)
        self.volleyMissArmed = Array(repeating: false, count: players.count)
        self.rallyAwaitingClose = Array(repeating: false, count: players.count)
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

    var overallStats: (
        averageImpactStrength: Double,
        maxImpactStrength: Int,
        averageMotion: Double,
        centerHitPercentage: Double,
        totalHits: Int,
        frontHits: Int,
        backHits: Int,
        topHits: Int,
        bottomHits: Int,
        leftHits: Int,
        rightHits: Int
    ) {
        GameEngine.overallAverages(from: playerMetrics)
    }

    var activeMetrics: [GameMetric] {
        let metrics = playerMetrics[activePlayerIndex]

        switch activeMode {
        case .dinkSinks:
            return GameEngine.dinkSinksMetrics(from: metrics)
        case .volleyWallies:
            return GameEngine.volleyWalliesMetrics(from: metrics)
        case .theRealDeal:
            return GameEngine.realDealMetrics(from: metrics)
        case .pickleCup:
            return GameEngine.pickleCupMetrics(
                totalScore: pickleCupTotalScore(for: activePlayerIndex),
                gamesWon: cupWins[activePlayerIndex],
                strongestSkill: strongestSkillLabel(for: activePlayerIndex)
            )
        }
    }

    var summaryMetrics: [GameMetric] {
        let stats = overallStats
        let averageStrength = Int(stats.averageImpactStrength.rounded())

        return [
            GameMetric(title: "Hit Strength", value: GameEngine.hitStrengthLabel(impactStrength: averageStrength), subtitle: "Average contact quality"),
            GameMetric(title: "Motion", value: GameEngine.motionLabel(motionValue: stats.averageMotion), subtitle: "Typical movement level"),
            GameMetric(title: "Clean Hits", value: GameEngine.percentageString(stats.centerHitPercentage), subtitle: "Front/Back center contact"),
            GameMetric(title: "Total Hits", value: "\(stats.totalHits)", subtitle: "All hit events")
        ]
    }

    var sessionResultMetrics: [GameMetric] {
        if mode == .pickleCup {
            return GameEngine.pickleCupMetrics(
                totalScore: pickleCupTotalScore(for: activePlayerIndex),
                gamesWon: cupWins[activePlayerIndex],
                strongestSkill: strongestSkillLabel(for: activePlayerIndex)
            )
        }

        return activeMetrics
    }

    func start() {
        isPaused = false
        bluetoothService.onPaddleEvent = { [weak self] event in
            self?.ingest(event: event)
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
        closeRallyIfNeeded(for: activePlayerIndex)

        let rally = Rally(
            initiatingPlayerName: activePlayerName,
            hits: max(playerMetrics[activePlayerIndex].currentRallyLength, 1),
            pointWinnerName: playerMetrics[index].player.name
        )
        rallies.insert(rally, at: 0)
        roundBanner = "\(playerMetrics[index].player.name) took the rally."

        if playerMetrics[index].points >= 5 {
            if mode == .pickleCup {
                finalizePickleCupStage(.theRealDeal)
            }
            completeSession(winnerName: playerMetrics[index].player.name)
        }
    }

    func endSessionEarly() {
        guard !isSessionComplete else { return }
        if activeMode == .theRealDeal {
            closeRallyIfNeeded(for: activePlayerIndex)
        }
        if mode == .pickleCup {
            finalizePickleCupStage(activeMode)
        }
        completeSession(winnerName: winnerNameForCurrentState())
    }

    func dismissRankUpCelebration() {
        latestXPAwardResult = nil
    }

    private func ingest(event: PaddleEvent) {
        guard !isSessionComplete, !isPaused else { return }

        latestEvent = event
        latestFeedback = GameEngine.feedback(for: event)

        switch event.type {
        case .motion:
            playerMetrics[activePlayerIndex].totalMotionEvents += 1
            playerMetrics[activePlayerIndex].cumulativeMotionValue += event.motionValue

        case .hit:
            handleHitEvent(event)
        }
    }

    private func handleHitEvent(_ event: PaddleEvent) {
        guard let impactStrength = event.impactStrength, let zone = event.zone else { return }

        recentEvents.insert(event, at: 0)
        if recentEvents.count > 8 {
            recentEvents.removeLast(recentEvents.count - 8)
        }

        var metrics = playerMetrics[activePlayerIndex]
        metrics.totalHits += 1
        metrics.totalImpactStrength += impactStrength
        metrics.maxImpactStrength = max(metrics.maxImpactStrength, impactStrength)
        metrics.cumulativeMotionValue += event.motionValue

        switch zone {
        case .top:
            metrics.topHits += 1
        case .bottom:
            metrics.bottomHits += 1
        case .left:
            metrics.leftHits += 1
        case .right:
            metrics.rightHits += 1
        case .centerFront:
            metrics.centerFrontHits += 1
            metrics.cleanHits += 1
        case .centerBack:
            metrics.centerBackHits += 1
            metrics.cleanHits += 1
        case .unknown:
            break
        }

        playerMetrics[activePlayerIndex] = metrics

        switch activeMode {
        case .dinkSinks:
            updateDinkSinks(with: event)
        case .volleyWallies:
            updateVolleyWallies(with: event)
        case .theRealDeal:
            updateRealDeal(with: event)
        case .pickleCup:
            break
        }
    }

    private func updateDinkSinks(with event: PaddleEvent) {
        var metrics = playerMetrics[activePlayerIndex]
        let now = event.timestamp

        if let lastHit = lastDinkHitDates[activePlayerIndex], now.timeIntervalSince(lastHit) > GameEngine.dinkTimeout {
            metrics.dinkCurrentStreak = 0
        }

        if GameEngine.isValidDink(event) {
            metrics.dinkTotal += 1
            if event.zone == .centerFront || event.zone == .centerBack || event.zone == .left || event.zone == .right {
                metrics.dinkPreferredHits += 1
            }

            switch event.zone {
            case .top:
                metrics.dinkTopHits += 1
            case .bottom:
                metrics.dinkBottomHits += 1
            case .left:
                metrics.dinkLeftHits += 1
            case .right:
                metrics.dinkRightHits += 1
            case .centerFront:
                metrics.dinkCenterFrontHits += 1
            case .centerBack:
                metrics.dinkCenterBackHits += 1
            case .unknown, .none:
                break
            }

            metrics.dinkCurrentStreak += 1
            metrics.dinkBestStreak = max(metrics.dinkBestStreak, metrics.dinkCurrentStreak)
        } else {
            metrics.dinkCurrentStreak = 0
        }

        lastDinkHitDates[activePlayerIndex] = now
        playerMetrics[activePlayerIndex] = metrics
    }

    private func updateVolleyWallies(with event: PaddleEvent) {
        var metrics = playerMetrics[activePlayerIndex]
        let now = event.timestamp

        metrics.volleyHits += 1
        if let lastHit = lastVolleyHitDates[activePlayerIndex] {
            let interval = now.timeIntervalSince(lastHit)
            metrics.volleyIntervalSum += interval
            metrics.volleyIntervalCount += 1
        }

        lastVolleyHitDates[activePlayerIndex] = now
        volleyMissArmed[activePlayerIndex] = true
        playerMetrics[activePlayerIndex] = metrics
    }

    private func updateRealDeal(with event: PaddleEvent) {
        var metrics = playerMetrics[activePlayerIndex]
        let now = event.timestamp

        if let lastHit = lastRallyHitDates[activePlayerIndex], now.timeIntervalSince(lastHit) > GameEngine.rallyTimeout {
            finalizeCurrentRally(for: activePlayerIndex)
            metrics = playerMetrics[activePlayerIndex]
        }

        metrics.currentRallyLength += 1
        metrics.longestRally = max(metrics.longestRally, metrics.currentRallyLength)
        lastRallyHitDates[activePlayerIndex] = now
        rallyAwaitingClose[activePlayerIndex] = true
        playerMetrics[activePlayerIndex] = metrics
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
        handleModeTimeouts()

        if activeMode.isTimed {
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                handleTimedRoundCompletion()
            }
        }
    }

    private func handleModeTimeouts() {
        let now = Date.now

        if activeMode == .volleyWallies,
           volleyMissArmed[activePlayerIndex],
           let lastHit = lastVolleyHitDates[activePlayerIndex],
           now.timeIntervalSince(lastHit) > GameEngine.volleyMissTimeout {
            playerMetrics[activePlayerIndex].volleyMisses += 1
            volleyMissArmed[activePlayerIndex] = false
        }

        if activeMode == .theRealDeal,
           rallyAwaitingClose[activePlayerIndex],
           let lastHit = lastRallyHitDates[activePlayerIndex],
           now.timeIntervalSince(lastHit) > GameEngine.rallyTimeout {
            finalizeCurrentRally(for: activePlayerIndex)
        }

        if activeMode == .dinkSinks,
           let lastHit = lastDinkHitDates[activePlayerIndex],
           now.timeIntervalSince(lastHit) > GameEngine.dinkTimeout {
            playerMetrics[activePlayerIndex].dinkCurrentStreak = 0
        }
    }

    private func handleTimedRoundCompletion() {
        if mode == .pickleCup {
            finalizePickleCupStage(activeMode)

            if currentCupStageIndex < 2 {
                currentCupStageIndex += 1
                activePlayerIndex = 0
                secondsRemaining = GameEngine.timedRoundLength
                resetModeProgress()
                configureRoundBanner()
                return
            }
        }

        let winnerIndex = GameEngine.winnerIndex(for: activeMode, metrics: playerMetrics)
        completeSession(winnerName: playerMetrics[winnerIndex].player.name)
    }

    private func finalizePickleCupStage(_ stage: GameMode) {
        for index in playerMetrics.indices {
            let score: Double
            switch stage {
            case .dinkSinks:
                score = GameEngine.dinkSinksScore(from: playerMetrics[index])
                cupStageScores[index][0] = score
            case .volleyWallies:
                score = GameEngine.volleyWalliesScore(from: playerMetrics[index])
                cupStageScores[index][1] = score
            case .theRealDeal:
                closeRallyIfNeeded(for: index)
                score = GameEngine.realDealScore(from: playerMetrics[index])
                cupStageScores[index][2] = score
            case .pickleCup:
                continue
            }
        }

        if playerMetrics.count > 1 {
            let winningIndex: Int
            switch stage {
            case .dinkSinks:
                winningIndex = cupStageScores[0][0] >= cupStageScores[1][0] ? 0 : 1
            case .volleyWallies:
                winningIndex = cupStageScores[0][1] >= cupStageScores[1][1] ? 0 : 1
            case .theRealDeal:
                winningIndex = cupStageScores[0][2] >= cupStageScores[1][2] ? 0 : 1
            case .pickleCup:
                winningIndex = 0
            }
            cupWins[winningIndex] += 1
        }
    }

    private func finalizeCurrentRally(for index: Int) {
        guard playerMetrics[index].currentRallyLength > 0 else {
            rallyAwaitingClose[index] = false
            return
        }

        playerMetrics[index].completedRallyLengthTotal += playerMetrics[index].currentRallyLength
        playerMetrics[index].completedRallies += 1
        playerMetrics[index].longestRally = max(playerMetrics[index].longestRally, playerMetrics[index].currentRallyLength)
        playerMetrics[index].currentRallyLength = 0
        rallyAwaitingClose[index] = false
    }

    private func closeRallyIfNeeded(for index: Int) {
        if rallyAwaitingClose[index] || playerMetrics[index].currentRallyLength > 0 {
            finalizeCurrentRally(for: index)
        }
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
                totalHits: stats.totalHits,
                averageImpactStrength: stats.averageImpactStrength,
                maxImpactStrength: stats.maxImpactStrength,
                averageMotion: stats.averageMotion,
                centerHitPercentage: stats.centerHitPercentage,
                frontHits: stats.frontHits,
                backHits: stats.backHits,
                topHits: stats.topHits,
                bottomHits: stats.bottomHits,
                leftHits: stats.leftHits,
                rightHits: stats.rightHits,
                winnerName: sessionWinner,
                longestStreak: playerMetrics.map(\.dinkBestStreak).max() ?? 0,
                totalValidVolleys: playerMetrics.reduce(0) { $0 + $1.volleyHits },
                bestRallyLength: playerMetrics.map(\.longestRally).max() ?? 0,
                ownerProfileID: ownerProfileID
            )
        )

        onSessionSaved?()

        syncProgressionIfPossible(
            sessionEndDate: sessionEndDate,
            totalHits: stats.totalHits,
            centerHitPercentage: stats.centerHitPercentage,
            maxImpactStrength: stats.maxImpactStrength,
            priorSessions: priorSessions
        )
    }

    private func syncProgressionIfPossible(
        sessionEndDate: Date,
        totalHits: Int,
        centerHitPercentage: Double,
        maxImpactStrength: Int,
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
            centerHitPercentage: centerHitPercentage,
            playedWithFriend: playerMetrics.count > 1,
            isNewImpactStrengthPB: maxImpactStrength > (priorSessions.map(\.maxImpactStrength).max() ?? 0),
            isNewCenterHitPB: centerHitPercentage > (priorSessions.map(\.centerHitPercentage).max() ?? 0)
        )

        let awardResult = ProgressionService.applySessionXP(
            previous: previousProgression.progression,
            stats: sessionStats
        )
        latestXPAwardResult = awardResult

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
            return playerMetrics[index].volleyHits
        case .theRealDeal:
            return playerMetrics[index].points
        case .pickleCup:
            return Int(pickleCupTotalScore(for: index).rounded())
        }
    }

    private func pickleCupTotalScore(for index: Int) -> Double {
        cupStageScores[index].reduce(0, +) / 3.0
    }

    private func strongestSkillLabel(for index: Int) -> String {
        let stageScores = cupStageScores[index]
        let maxScore = stageScores.max() ?? 0
        switch stageScores.firstIndex(of: maxScore) {
        case 0:
            return "Dink Sinks"
        case 1:
            return "Volley Wallies"
        case 2:
            return "The Real Deal"
        default:
            return "Balanced"
        }
    }

    private func winnerNameForCurrentState() -> String {
        if mode == .pickleCup {
            let winnerIndex = pickleCupTotalScore(for: 0) >= pickleCupTotalScore(for: min(1, playerMetrics.count - 1)) ? 0 : 1
            return playerMetrics[winnerIndex].player.name
        }

        let winnerIndex = GameEngine.winnerIndex(for: activeMode, metrics: playerMetrics)
        return playerMetrics[winnerIndex].player.name
    }

    private func resetModeProgress() {
        for index in playerMetrics.indices {
            playerMetrics[index].resetModeProgress()
            lastDinkHitDates[index] = nil
            lastVolleyHitDates[index] = nil
            lastRallyHitDates[index] = nil
            volleyMissArmed[index] = false
            rallyAwaitingClose[index] = false
        }
    }

    private func configureRoundBanner() {
        switch activeMode {
        case .dinkSinks:
            roundBanner = "Keep the rally alive at the net. Soft hands win."
            secondsRemaining = GameEngine.timedRoundLength
        case .volleyWallies:
            roundBanner = "Test your reflexes. Faster hands, more volleys."
            secondsRemaining = GameEngine.timedRoundLength
        case .theRealDeal:
            roundBanner = "Play real points. Win with consistency."
        case .pickleCup:
            break
        }
    }
}
