import Foundation

enum ProgressionService {
    static let levelThresholds: [Int: Int] = [
        1: 0,
        2: 100,
        3: 250,
        4: 500,
        5: 900,
        6: 1400,
        7: 2000,
        8: 2800,
        9: 3800,
        10: 5000,
        11: 6500
    ]

    static let maxLevel = 11

    static func getLevel(from totalXP: Int) -> Int {
        let safeXP = max(0, totalXP)

        for level in stride(from: maxLevel, through: 1, by: -1) {
            if safeXP >= (levelThresholds[level] ?? 0) {
                return level
            }
        }

        return 1
    }

    static func getRank(from level: Int) -> ProgressionRank {
        switch level {
        case 11...:
            return .diamond
        case 8...10:
            return .gold
        case 4...7:
            return .silver
        default:
            return .bronze
        }
    }

    static func getLevelBounds(for level: Int) -> (currentLevelMinXP: Int, nextLevelMinXP: Int?) {
        let safeLevel = min(max(level, 1), maxLevel)
        return (
            currentLevelMinXP: levelThresholds[safeLevel] ?? 0,
            nextLevelMinXP: safeLevel == maxLevel ? nil : levelThresholds[safeLevel + 1]
        )
    }

    static func buildUserProgression(
        userID: String,
        totalXP: Int,
        updatedAt: String = ISO8601DateFormatter().string(from: .now)
    ) -> UserProgression {
        let safeXP = max(0, totalXP)
        let level = getLevel(from: safeXP)
        let rank = getRank(from: level)
        let bounds = getLevelBounds(for: level)
        let isMaxLevel = level == maxLevel
        let progressInLevel = safeXP - bounds.currentLevelMinXP

        let progressToNextLevel: Double
        if isMaxLevel || bounds.nextLevelMinXP == nil {
            progressToNextLevel = 1
        } else {
            let span = max(1, (bounds.nextLevelMinXP ?? bounds.currentLevelMinXP) - bounds.currentLevelMinXP)
            progressToNextLevel = min(1, max(0, Double(progressInLevel) / Double(span)))
        }

        return UserProgression(
            userID: userID,
            totalXP: safeXP,
            level: level,
            rank: rank,
            currentLevelMinXP: bounds.currentLevelMinXP,
            nextLevelMinXP: bounds.nextLevelMinXP,
            progressInLevel: progressInLevel,
            progressToNextLevel: progressToNextLevel,
            isMaxLevel: isMaxLevel,
            updatedAt: updatedAt
        )
    }

    static func calculateSessionXP(from stats: SessionStats) -> (totalXP: Int, breakdown: [XPBreakdownItem]) {
        var breakdown = [XPBreakdownItem(source: "Complete session", xp: 50)]

        if stats.durationMinutes >= 10 {
            breakdown.append(XPBreakdownItem(source: "Played 10+ minutes", xp: 10))
        }
        if stats.durationMinutes >= 20 {
            breakdown.append(XPBreakdownItem(source: "Played 20+ minutes", xp: 10))
        }
        if stats.durationMinutes >= 30 {
            breakdown.append(XPBreakdownItem(source: "Played 30+ minutes", xp: 10))
        }

        let hitXP = (max(0, stats.totalHits) / 10) * 10
        if hitXP > 0 {
            breakdown.append(XPBreakdownItem(source: "Every 10 hits", xp: hitXP))
        }

        if stats.sweetSpotPercentage >= 40 {
            breakdown.append(XPBreakdownItem(source: "Sweet spot >= 40%", xp: 15))
        }
        if stats.sweetSpotPercentage >= 60 {
            breakdown.append(XPBreakdownItem(source: "Sweet spot >= 60%", xp: 15))
        }
        if stats.sweetSpotPercentage >= 75 {
            breakdown.append(XPBreakdownItem(source: "Sweet spot >= 75%", xp: 20))
        }

        if stats.playedWithFriend {
            breakdown.append(XPBreakdownItem(source: "Played with a friend", xp: 25))
        }
        if stats.isNewSwingSpeedPB {
            breakdown.append(XPBreakdownItem(source: "New swing speed personal best", xp: 25))
        }
        if stats.isNewSweetSpotPB {
            breakdown.append(XPBreakdownItem(source: "New sweet spot personal best", xp: 25))
        }

        return (breakdown.reduce(0) { $0 + $1.xp }, breakdown)
    }

    static func applySessionXP(previous: UserProgression, stats: SessionStats) -> XPAwardResult {
        let sessionXP = calculateSessionXP(from: stats)
        let updatedProgression = buildUserProgression(
            userID: previous.userID,
            totalXP: previous.totalXP + sessionXP.totalXP
        )

        return XPAwardResult(
            xpGained: sessionXP.totalXP,
            leveledUp: updatedProgression.level > previous.level,
            oldLevel: previous.level,
            newLevel: updatedProgression.level,
            rankedUp: updatedProgression.rank != previous.rank,
            oldRank: previous.rank,
            newRank: updatedProgression.rank,
            updatedProgression: updatedProgression,
            breakdown: sessionXP.breakdown
        )
    }

    static func buildProgressionCardViewData(from progression: UserProgression) -> ProgressionCardViewData {
        let currentLevelXPRangeLabel: String
        if let nextLevelMinXP = progression.nextLevelMinXP {
            currentLevelXPRangeLabel = "\(progression.totalXP) / \(nextLevelMinXP) XP"
        } else {
            currentLevelXPRangeLabel = "\(progression.totalXP) XP"
        }

        return ProgressionCardViewData(
            rankBadge: progression.rank.badgeTitle,
            level: progression.level,
            totalXP: progression.totalXP,
            progressBarValue: progression.progressToNextLevel,
            currentLevelXPRangeLabel: currentLevelXPRangeLabel,
            nextLevelLabel: progression.isMaxLevel ? "MAX" : "Level \(progression.level + 1)"
        )
    }

    static func buildProgression(
        for profile: PlayerProfile,
        sessions: [StoredGameSession]
    ) -> (progression: UserProgression, latestAward: XPAwardResult?) {
        buildProgression(userID: profile.id.uuidString, sessions: sessions)
    }

    static func buildProgression(
        userID: String,
        sessions: [StoredGameSession]
    ) -> (progression: UserProgression, latestAward: XPAwardResult?) {
        let sortedSessions = sessions.sorted { $0.endDate < $1.endDate }
        var progression = buildUserProgression(userID: userID, totalXP: 0)
        var latestAward: XPAwardResult?
        var previousTopSpeed = 0.0
        var previousBestSweetSpot = 0.0

        for session in sortedSessions {
            let stats = SessionStats(
                durationMinutes: max(1, Int(session.endDate.timeIntervalSince(session.startDate) / 60)),
                totalHits: session.totalHits,
                sweetSpotPercentage: session.sweetSpotPercentage,
                playedWithFriend: !session.playerTwoName.localizedCaseInsensitiveContains("solo"),
                isNewSwingSpeedPB: session.maxSwingSpeed > previousTopSpeed,
                isNewSweetSpotPB: session.sweetSpotPercentage > previousBestSweetSpot
            )

            let award = applySessionXP(previous: progression, stats: stats)
            progression = award.updatedProgression
            latestAward = award
            previousTopSpeed = max(previousTopSpeed, session.maxSwingSpeed)
            previousBestSweetSpot = max(previousBestSweetSpot, session.sweetSpotPercentage)
        }

        return (progression, latestAward)
    }
}
