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
    var ownerProfileID: UUID?
}

struct PublicComment: Identifiable, Codable, Hashable {
    let id: UUID
    let itemID: UUID
    let userID: UUID
    let authorName: String
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case itemID = "item_id"
        case userID = "user_id"
        case authorName = "author_name"
        case body
        case createdAt = "created_at"
    }
}

struct CreateCommentRequest: Encodable {
    let itemID: UUID
    let userID: UUID
    let authorName: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case userID = "user_id"
        case authorName = "author_name"
        case body
    }
}

struct SupabaseAuthUser: Codable, Hashable {
    let id: UUID
    let email: String?
}

struct SupabaseAuthSession: Codable, Hashable {
    let accessToken: String
    let refreshToken: String?
    let user: SupabaseAuthUser
    let expiresAt: Date?
}

struct CommentLikeRecord: Codable, Hashable {
    let id: UUID
    let commentID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case commentID = "comment_id"
        case userID = "user_id"
    }
}

enum ProgressionRank: String, Codable, CaseIterable {
    case bronze
    case silver
    case gold
    case diamond

    var badgeTitle: String {
        switch self {
        case .bronze:
            return "Bronze Paddle"
        case .silver:
            return "Silver Spin"
        case .gold:
            return "Gold Rally"
        case .diamond:
            return "Diamond Dink"
        }
    }

    var badgeAssetName: String {
        switch self {
        case .bronze:  return "bronze_paddle_badge"
        case .silver:  return "silver_spin_badge"
        case .gold:    return "gold_rally_badge"
        case .diamond: return "diamond_dink_badge"
        }
    }
}

struct UserProgression: Codable, Hashable {
    let userID: String
    let totalXP: Int
    let level: Int
    let rank: ProgressionRank
    let currentLevelMinXP: Int
    let nextLevelMinXP: Int?
    let progressInLevel: Int
    let progressToNextLevel: Double
    let isMaxLevel: Bool
    let updatedAt: String
}

struct SessionStats: Hashable {
    let durationMinutes: Int
    let totalHits: Int
    let sweetSpotPercentage: Double
    let playedWithFriend: Bool
    let isNewSwingSpeedPB: Bool
    let isNewSweetSpotPB: Bool
}

struct XPBreakdownItem: Hashable, Codable {
    let source: String
    let xp: Int
}

struct XPAwardResult: Hashable {
    let xpGained: Int
    let leveledUp: Bool
    let oldLevel: Int
    let newLevel: Int
    let rankedUp: Bool
    let oldRank: ProgressionRank
    let newRank: ProgressionRank
    let updatedProgression: UserProgression
    let breakdown: [XPBreakdownItem]
}

struct ProgressionCardViewData: Hashable {
    let rankBadge: String
    let level: Int
    let totalXP: Int
    let progressBarValue: Double
    let currentLevelXPRangeLabel: String
    let nextLevelLabel: String
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
    // Phase 1 — Supabase sync
    var supabaseProfileSynced: Bool = false
    // Phase 3 — home location cache
    var homeLocationLabel: String = ""
    // Phase 6 — GPN integration
    var gpnUsername: String = ""
    // MVP — daily-play streak tracking
    var currentStreak: Int = 0
    var longestDailyStreak: Int = 0
    var lastActiveDate: Date? = nil

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
    // Phase 2 — Supabase sync
    var remoteID: UUID? = nil
    var isDirty: Bool = true
    // MVP — challenge and Pickle Cup flags
    var isChallenge: Bool = false
    var isPickleCupWin: Bool = false
    // Owner scoping — prevents sessions from leaking across profiles
    var ownerProfileID: UUID?

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
        bestRallyLength: Int,
        ownerProfileID: UUID? = nil
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
        self.ownerProfileID = ownerProfileID
    }

    var mode: GameMode {
        GameMode(rawValue: modeRawValue) ?? .dinkSinks
    }
}

// MARK: - Phase 3: Saved Locations

@Model
final class SavedLocation {
    @Attribute(.unique) var id: UUID
    var label: String
    var placeName: String
    var address: String
    var latitude: Double
    var longitude: Double
    var isHome: Bool
    var supabaseID: UUID? = nil
    var isDirty: Bool = true
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        placeName: String,
        address: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        isHome: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.label = label
        self.placeName = placeName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.isHome = isHome
        self.createdAt = createdAt
    }
}

// MARK: - Phase 1: Offline Sync Queue

/// Cached GPN profile data for a player. One row per `PlayerProfile`.
/// Populated by the `sync-gpn-profile` Supabase Edge Function, which handles
/// GPN OAuth server-side. The app only reads/displays these cached fields.
@Model
final class GPNProfile {
    @Attribute(.unique) var id: UUID
    /// FK to the owning `PlayerProfile.id`
    var ownerProfileID: UUID

    // MARK: GPN Identity
    var gpnUsername: String = ""
    var gpnDisplayName: String = ""
    var gpnAvatarUrl: String = ""
    var gpnProfileUrl: String = ""
    var gpnLocation: String = ""

    // MARK: Skill Levels (e.g. 3.50)
    var singlesLevel: Double = 0.0
    var doublesLevel: Double = 0.0
    var overallLevel: Double = 0.0

    // MARK: DUPR Rating
    var duprRating: Double = 0.0

    // MARK: Match Stats
    var totalMatches: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var winPercentage: Double = 0.0

    // MARK: Sync metadata
    var lastSyncedAt: Date?
    var isDirty: Bool = false
    var createdAt: Date

    init(ownerProfileID: UUID) {
        self.id = UUID()
        self.ownerProfileID = ownerProfileID
        self.lastSyncedAt = nil
        self.createdAt = .now
    }
}

// MARK: - GPN Service wire types

/// Request body sent to the `sync-gpn-profile` Supabase Edge Function.
/// On the first link both fields are populated. For subsequent refresh syncs
/// both fields are nil and the Edge Function uses the cached server-side
/// session to refresh data.
struct GPNSyncRequest: Encodable {
    let gpnUsername: String?
    let gpnPassword: String?

    enum CodingKeys: String, CodingKey {
        case gpnUsername = "gpn_username"
        case gpnPassword = "gpn_password"
    }
}

/// Response returned by the Edge Function after authenticating with GPN and
/// writing the result to `gpn_profiles` in Supabase.
struct GPNEdgeFunctionResponse: Decodable {
    let gpnUsername: String
    let gpnDisplayName: String?
    let gpnAvatarUrl: String?
    let gpnProfileUrl: String?
    let gpnLocation: String?
    let singlesLevel: Double?
    let doublesLevel: Double?
    let overallLevel: Double?
    let duprRating: Double?
    let totalMatches: Int?
    let wins: Int?
    let losses: Int?
    let winPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case gpnUsername = "gpn_username"
        case gpnDisplayName = "gpn_display_name"
        case gpnAvatarUrl = "gpn_avatar_url"
        case gpnProfileUrl = "gpn_profile_url"
        case gpnLocation = "gpn_location"
        case singlesLevel = "singles_level"
        case doublesLevel = "doubles_level"
        case overallLevel = "overall_level"
        case duprRating = "dupr_rating"
        case totalMatches = "total_matches"
        case wins
        case losses
        case winPercentage = "win_percentage"
    }
}

/// Row shape returned by `GET /rest/v1/gpn_profiles`.
struct RemoteGPNProfile: Decodable {
    let gpnUsername: String
    let gpnDisplayName: String?
    let gpnAvatarUrl: String?
    let gpnProfileUrl: String?
    let gpnLocation: String?
    let singlesLevel: Double?
    let doublesLevel: Double?
    let overallLevel: Double?
    let duprRating: Double?
    let totalMatches: Int?
    let wins: Int?
    let losses: Int?
    let winPercentage: Double?
    let lastSyncedAt: String?

    enum CodingKeys: String, CodingKey {
        case gpnUsername = "gpn_username"
        case gpnDisplayName = "gpn_display_name"
        case gpnAvatarUrl = "gpn_avatar_url"
        case gpnProfileUrl = "gpn_profile_url"
        case gpnLocation = "gpn_location"
        case singlesLevel = "singles_level"
        case doublesLevel = "doubles_level"
        case overallLevel = "overall_level"
        case duprRating = "dupr_rating"
        case totalMatches = "total_matches"
        case wins
        case losses
        case winPercentage = "win_percentage"
        case lastSyncedAt = "last_synced_at"
    }
}

/// Serialised write queue for Supabase-bound operations when the device is offline.
/// SyncService drains this queue oldest-first when connectivity is restored.
@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: UUID
    /// Operation type. Allowed: upsert_profile | save_session | upsert_location | award_badge | xp_events
    var operation: String
    /// Target Supabase table name, e.g. "game_sessions"
    var tableName: String
    /// JSON-encoded request body to replay against the Supabase REST endpoint
    var payload: Data
    var createdAt: Date
    var retryCount: Int

    init(
        id: UUID = UUID(),
        operation: String,
        tableName: String,
        payload: Data,
        createdAt: Date = .now,
        retryCount: Int = 0
    ) {
        self.id = id
        self.operation = operation
        self.tableName = tableName
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}
