import Foundation
import SwiftData

enum DominantArm: String, CaseIterable, Codable, Identifiable {
    case right = "Right"
    case left = "Left"
    case ambidextrous = "Ambidextrous"

    var id: String { rawValue }
}

enum SkillLevel: String, CaseIterable, Codable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case tournament = "Tournament"

    var id: String { rawValue }
}

enum GameMode: String, CaseIterable, Codable, Identifiable {
    case dinkSinks = "Dink Sinks"
    case volleyWallies = "Volley Wallies"
    case theRealDeal = "The Real Deal"
    case pickleCup = "Pickle Cup"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .dinkSinks:
            return "Highest dink streak in sixty seconds."
        case .volleyWallies:
            return "Count every clean volley in the round."
        case .theRealDeal:
            return "Manual rally scoring. First to five points wins."
        case .pickleCup:
            return "All three modes. One overall champion."
        }
    }

    var isTimed: Bool {
        switch self {
        case .dinkSinks, .volleyWallies:
            return true
        case .theRealDeal, .pickleCup:
            return false
        }
    }
}

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var dominantArm: DominantArm
    var skillLevel: SkillLevel

    init(
        id: UUID = UUID(),
        name: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel
    ) {
        self.id = id
        self.name = name
        self.dominantArm = dominantArm
        self.skillLevel = skillLevel
    }
}

struct PaddleDevice: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var batteryLevel: Int
    var isConnected: Bool

    init(
        id: UUID = UUID(),
        name: String,
        batteryLevel: Int,
        isConnected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.batteryLevel = batteryLevel
        self.isConnected = isConnected
    }
}

struct ShotEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let speedMPH: Double
    let hitSweetSpot: Bool
    let spinRPM: Double

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        speedMPH: Double,
        hitSweetSpot: Bool,
        spinRPM: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.speedMPH = speedMPH
        self.hitSweetSpot = hitSweetSpot
        self.spinRPM = spinRPM
    }
}

struct Rally: Identifiable, Codable, Hashable {
    let id: UUID
    let initiatingPlayerName: String
    let hits: Int
    let pointWinnerName: String

    init(
        id: UUID = UUID(),
        initiatingPlayerName: String,
        hits: Int,
        pointWinnerName: String
    ) {
        self.id = id
        self.initiatingPlayerName = initiatingPlayerName
        self.hits = hits
        self.pointWinnerName = pointWinnerName
    }
}

struct PlayerGameMetrics: Identifiable, Hashable {
    let id: UUID
    var player: Player
    var totalHits: Int
    var cumulativeSwingSpeed: Double
    var maxSwingSpeed: Double
    var sweetSpotHits: Int
    var dinkCurrentStreak: Int
    var dinkBestStreak: Int
    var validVolleys: Int
    var points: Int

    init(player: Player) {
        id = UUID()
        self.player = player
        totalHits = 0
        cumulativeSwingSpeed = 0
        maxSwingSpeed = 0
        sweetSpotHits = 0
        dinkCurrentStreak = 0
        dinkBestStreak = 0
        validVolleys = 0
        points = 0
    }

    var averageSwingSpeed: Double {
        guard totalHits > 0 else { return 0 }
        return cumulativeSwingSpeed / Double(totalHits)
    }

    var sweetSpotPercentage: Double {
        guard totalHits > 0 else { return 0 }
        return (Double(sweetSpotHits) / Double(totalHits)) * 100
    }
}

struct SessionDraft {
    var mode: GameMode
    var startDate: Date
    var endDate: Date
    var playerOneName: String
    var playerTwoName: String
    var playerOneScore: Int
    var playerTwoScore: Int
    var averageSwingSpeed: Double
    var maxSwingSpeed: Double
    var sweetSpotPercentage: Double
    var totalHits: Int
    var winnerName: String
    var longestStreak: Int
    var totalValidVolleys: Int
    var bestRallyLength: Int
}

@Model
final class PlayerProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var locationName: String
    var dominantArmRawValue: String
    var skillLevelRawValue: String
    var syncedPaddleName: String
    var completedOnboarding: Bool

    init(
        id: UUID = UUID(),
        name: String,
        locationName: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        syncedPaddleName: String,
        completedOnboarding: Bool
    ) {
        self.id = id
        self.name = name
        self.locationName = locationName
        dominantArmRawValue = dominantArm.rawValue
        skillLevelRawValue = skillLevel.rawValue
        self.syncedPaddleName = syncedPaddleName
        self.completedOnboarding = completedOnboarding
    }

    var dominantArm: DominantArm {
        DominantArm(rawValue: dominantArmRawValue) ?? .right
    }

    var skillLevel: SkillLevel {
        SkillLevel(rawValue: skillLevelRawValue) ?? .beginner
    }

    var asPlayer: Player {
        Player(
            id: id,
            name: name,
            dominantArm: dominantArm,
            skillLevel: skillLevel
        )
    }
}

@Model
final class StoredGameSession {
    @Attribute(.unique) var id: UUID
    var modeRawValue: String
    var startDate: Date
    var endDate: Date
    var playerOneName: String
    var playerTwoName: String
    var playerOneScore: Int
    var playerTwoScore: Int
    var averageSwingSpeed: Double
    var maxSwingSpeed: Double
    var sweetSpotPercentage: Double
    var totalHits: Int
    var winnerName: String
    var longestStreak: Int
    var totalValidVolleys: Int
    var bestRallyLength: Int

    init(
        id: UUID = UUID(),
        mode: GameMode,
        startDate: Date,
        endDate: Date,
        playerOneName: String,
        playerTwoName: String,
        playerOneScore: Int,
        playerTwoScore: Int,
        averageSwingSpeed: Double,
        maxSwingSpeed: Double,
        sweetSpotPercentage: Double,
        totalHits: Int,
        winnerName: String,
        longestStreak: Int,
        totalValidVolleys: Int,
        bestRallyLength: Int
    ) {
        self.id = id
        modeRawValue = mode.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.playerOneName = playerOneName
        self.playerTwoName = playerTwoName
        self.playerOneScore = playerOneScore
        self.playerTwoScore = playerTwoScore
        self.averageSwingSpeed = averageSwingSpeed
        self.maxSwingSpeed = maxSwingSpeed
        self.sweetSpotPercentage = sweetSpotPercentage
        self.totalHits = totalHits
        self.winnerName = winnerName
        self.longestStreak = longestStreak
        self.totalValidVolleys = totalValidVolleys
        self.bestRallyLength = bestRallyLength
    }

    var mode: GameMode {
        GameMode(rawValue: modeRawValue) ?? .dinkSinks
    }
}
