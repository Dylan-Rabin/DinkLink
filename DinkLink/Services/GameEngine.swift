import Foundation

enum GameEngine {
    static let timedRoundLength = 60
    static let dinkTimeout: TimeInterval = 2.0
    static let volleyMissTimeout: TimeInterval = 2.0
    static let rallyTimeout: TimeInterval = 3.0

    static func hitStrengthLabel(impactStrength: Int) -> String {
        switch impactStrength {
        case ..<400:
            return "Soft"
        case 400..<700:
            return "Medium"
        default:
            return "Hard"
        }
    }

    static func motionLabel(motionValue: Double) -> String {
        switch motionValue {
        case ..<0.5:
            return "Still"
        case 0.5..<1.5:
            return "Light"
        case 1.5..<3.0:
            return "Quick"
        default:
            return "Explosive"
        }
    }

    static func zoneLabel(_ zone: PaddleZone) -> String {
        switch zone {
        case .top:
            return "Top Edge"
        case .bottom:
            return "Bottom Edge"
        case .left:
            return "Left Side"
        case .right:
            return "Right Side"
        case .centerFront:
            return "Front Center"
        case .centerBack:
            return "Back Center"
        case .unknown:
            return "Unknown"
        }
    }

    static func feedback(for event: PaddleEvent) -> String {
        guard event.type == .hit, let impactStrength = event.impactStrength, let zone = event.zone else {
            return "Motion: \(motionLabel(motionValue: event.motionValue))"
        }

        let strength = hitStrengthLabel(impactStrength: impactStrength)
        return "\(zoneLabel(zone)) • \(strength) • \(motionLabel(motionValue: event.motionValue))"
    }

    static func isValidDink(_ event: PaddleEvent) -> Bool {
        guard
            event.type == .hit,
            let impactStrength = event.impactStrength,
            let zone = event.zone
        else {
            return false
        }

        let isPreferredZone: Bool = switch zone {
        case .centerFront, .centerBack, .left, .right:
            true
        default:
            false
        }

        return (300...650).contains(impactStrength)
            && (0.5...2.2).contains(event.motionValue)
            && isPreferredZone
    }

    static func isCleanHit(_ zone: PaddleZone?) -> Bool {
        zone == .centerFront || zone == .centerBack
    }

    static func handSpeedLabel(for averageInterval: Double?) -> String {
        guard let averageInterval else { return "Warming Up" }
        switch averageInterval {
        case ..<0.8:
            return "Fast"
        case 0.8...1.5:
            return "Solid"
        default:
            return "Slow"
        }
    }

    static func overallRankLabel(for totalScore: Double) -> String {
        switch totalScore {
        case 85...:
            return "Champion"
        case 70..<85:
            return "Contender"
        case 50..<70:
            return "Challenger"
        default:
            return "Rising"
        }
    }

    static func dinkSinksMetrics(from metrics: PlayerGameMetrics) -> [GameMetric] {
        [
            GameMetric(title: "Best Streak", value: "\(metrics.dinkBestStreak)", subtitle: "Longest controlled chain"),
            GameMetric(title: "Total Dinks", value: "\(metrics.dinkTotal)", subtitle: "Controlled net balls"),
            GameMetric(title: "Control %", value: percentageString(metrics.controlPercentage), subtitle: "Valid dinks per hit"),
            GameMetric(title: "Favorite Zone", value: zoneLabel(metrics.favoriteDinkZone), subtitle: "Most common control zone")
        ]
    }

    static func volleyWalliesMetrics(from metrics: PlayerGameMetrics) -> [GameMetric] {
        let averageStrength = metrics.totalHits > 0 ? Int(metrics.averageImpactStrength.rounded()) : 0
        return [
            GameMetric(title: "Volleys Hit", value: "\(metrics.volleyHits)", subtitle: "Recorded contacts"),
            GameMetric(title: "Hand Speed", value: handSpeedLabel(for: metrics.averageVolleyInterval), subtitle: intervalSubtitle(metrics.averageVolleyInterval)),
            GameMetric(title: "Hit Strength", value: hitStrengthLabel(impactStrength: averageStrength), subtitle: "Average contact feel"),
            GameMetric(title: "Misses", value: "\(metrics.volleyMisses)", subtitle: "Timeout windows missed")
        ]
    }

    static func realDealMetrics(from metrics: PlayerGameMetrics) -> [GameMetric] {
        [
            GameMetric(title: "Rally Length", value: "\(metrics.currentRallyLength)", subtitle: "Current live rally"),
            GameMetric(title: "Longest Rally", value: "\(metrics.longestRally)", subtitle: "Session best"),
            GameMetric(title: "Consistency", value: String(format: "%.1f", metrics.consistencyScore), subtitle: "Average completed rally"),
            GameMetric(title: "Clean Hits", value: percentageString(metrics.centerHitPercentage), subtitle: "Front/Back center contact")
        ]
    }

    static func pickleCupMetrics(
        totalScore: Double,
        gamesWon: Int,
        strongestSkill: String
    ) -> [GameMetric] {
        [
            GameMetric(title: "Total Score", value: "\(Int(totalScore.rounded()))", subtitle: "Average of 3 games"),
            GameMetric(title: "Games Won", value: "\(gamesWon)", subtitle: "Stage wins secured"),
            GameMetric(title: "Overall Rank", value: overallRankLabel(for: totalScore), subtitle: "Cup standing"),
            GameMetric(title: "Strongest Skill", value: strongestSkill, subtitle: "Best normalized stage")
        ]
    }

    static func dinkSinksScore(from metrics: PlayerGameMetrics) -> Double {
        let streakScore = min(Double(metrics.dinkBestStreak) / 12.0, 1.0) * 40
        let dinkScore = min(Double(metrics.dinkTotal) / 30.0, 1.0) * 35
        let controlScore = min(metrics.controlPercentage / 100.0, 1.0) * 25
        return streakScore + dinkScore + controlScore
    }

    static func volleyWalliesScore(from metrics: PlayerGameMetrics) -> Double {
        let volleyScore = min(Double(metrics.volleyHits) / 40.0, 1.0) * 40
        let speedValue: Double = switch handSpeedLabel(for: metrics.averageVolleyInterval) {
        case "Fast": 35
        case "Solid": 25
        default: 10
        }
        let missPenalty = min(Double(metrics.volleyMisses) * 5.0, 25.0)
        return max(0, volleyScore + speedValue - missPenalty + 25)
    }

    static func realDealScore(from metrics: PlayerGameMetrics) -> Double {
        let longestRallyScore = min(Double(metrics.longestRally) / 15.0, 1.0) * 40
        let consistencyScore = min(metrics.consistencyScore / 10.0, 1.0) * 35
        let cleanScore = min(metrics.centerHitPercentage / 100.0, 1.0) * 25
        return longestRallyScore + consistencyScore + cleanScore
    }

    static func winnerIndex(for mode: GameMode, metrics: [PlayerGameMetrics]) -> Int {
        guard metrics.count > 1 else { return 0 }

        switch mode {
        case .dinkSinks:
            return dinkSinksScore(from: metrics[0]) >= dinkSinksScore(from: metrics[1]) ? 0 : 1
        case .volleyWallies:
            return volleyWalliesScore(from: metrics[0]) >= volleyWalliesScore(from: metrics[1]) ? 0 : 1
        case .theRealDeal:
            return realDealScore(from: metrics[0]) >= realDealScore(from: metrics[1]) ? 0 : 1
        case .pickleCup:
            return 0
        }
    }

    static func overallAverages(from metrics: [PlayerGameMetrics]) -> (
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
        let totalHits = metrics.reduce(0) { $0 + $1.totalHits }
        let totalImpactStrength = metrics.reduce(0) { $0 + $1.totalImpactStrength }
        let totalMotion = metrics.reduce(0.0) { $0 + $1.cumulativeMotionValue }
        let totalEvents = metrics.reduce(0) { $0 + $1.totalHits + $1.totalMotionEvents }
        let cleanHits = metrics.reduce(0) { $0 + $1.cleanHits }

        return (
            averageImpactStrength: totalHits > 0 ? Double(totalImpactStrength) / Double(totalHits) : 0,
            maxImpactStrength: metrics.map(\.maxImpactStrength).max() ?? 0,
            averageMotion: totalEvents > 0 ? totalMotion / Double(totalEvents) : 0,
            centerHitPercentage: totalHits > 0 ? (Double(cleanHits) / Double(totalHits)) * 100 : 0,
            totalHits: totalHits,
            frontHits: metrics.reduce(0) { $0 + $1.centerFrontHits },
            backHits: metrics.reduce(0) { $0 + $1.centerBackHits },
            topHits: metrics.reduce(0) { $0 + $1.topHits },
            bottomHits: metrics.reduce(0) { $0 + $1.bottomHits },
            leftHits: metrics.reduce(0) { $0 + $1.leftHits },
            rightHits: metrics.reduce(0) { $0 + $1.rightHits }
        )
    }

    static func percentageString(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func intervalSubtitle(_ value: Double?) -> String? {
        guard let value else { return "Need more hits" }
        return String(format: "%.1fs between hits", value)
    }
}
