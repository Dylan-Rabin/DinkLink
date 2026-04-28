import Foundation
import SwiftData
@testable import DinkLink

// MARK: - SwiftData in-memory container

extension ModelContainer {
    /// Returns an in-memory container with all DinkLink model types registered.
    static func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([
            PlayerProfile.self,
            StoredGameSession.self,
            SavedLocation.self,
            SyncQueueItem.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

// MARK: - Sample model builders

enum SyncTestFixtures {

    // MARK: PlayerProfile

    static func makeProfile(
        name: String = "Test Player",
        currentStreak: Int = 3,
        longestStreak: Int = 7,
        lastActiveDate: Date? = .now,
        gpnUsername: String = ""
    ) -> PlayerProfile {
        let p = PlayerProfile(
            name: name,
            locationName: "Test Court",
            dominantArm: .right,
            skillLevel: .intermediate,
            syncedPaddleName: "TestPaddle",
            completedOnboarding: true
        )
        p.currentStreak = currentStreak
        p.longestDailyStreak = longestStreak
        p.lastActiveDate = lastActiveDate
        p.gpnUsername = gpnUsername
        return p
    }

    // MARK: StoredGameSession

    static func makeSession(
        mode: GameMode = .dinkSinks,
        isDirty: Bool = true,
        isChallenge: Bool = false,
        isPickleCupWin: Bool = false,
        totalHits: Int = 50
    ) -> StoredGameSession {
        let s = StoredGameSession(
            mode: mode,
            startDate: Date(timeIntervalSinceNow: -300),
            endDate: .now,
            playerOneName: "Alice",
            playerTwoName: "Bob",
            playerOneScore: 5,
            playerTwoScore: 3,
            averageSwingSpeed: 25.0,
            maxSwingSpeed: 40.0,
            sweetSpotPercentage: 65.0,
            totalHits: totalHits,
            winnerName: "Alice",
            longestStreak: 5,
            totalValidVolleys: 20,
            bestRallyLength: 8
        )
        s.isDirty = isDirty
        s.isChallenge = isChallenge
        s.isPickleCupWin = isPickleCupWin
        return s
    }

    // MARK: SavedLocation

    static func makeLocation(
        label: String = "Home",
        isHome: Bool = true,
        isDirty: Bool = true
    ) -> SavedLocation {
        let l = SavedLocation(
            label: label,
            placeName: "Test Court",
            address: "123 Pickleball Lane",
            latitude: 37.331,
            longitude: -122.031,
            isHome: isHome
        )
        l.isDirty = isDirty
        return l
    }

    // MARK: XPAwardResult

    static func makeXPAwardResult(totalXP: Int = 100) -> XPAwardResult {
        let progression = ProgressionService.buildUserProgression(
            userID: UUID().uuidString,
            totalXP: totalXP,
            updatedAt: ISO8601DateFormatter().string(from: .now)
        )
        return XPAwardResult(
            xpGained: totalXP,
            leveledUp: false,
            oldLevel: 1,
            newLevel: 1,
            rankedUp: false,
            oldRank: .bronze,
            newRank: .bronze,
            updatedProgression: progression,
            breakdown: [XPBreakdownItem(source: "Complete session", xp: totalXP)]
        )
    }
}
