import Foundation
import SwiftData

protocol PersistenceServiceProtocol {
    func seedSampleSessionsIfNeeded()
    func saveProfile(
        name: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String
    )
    func saveSession(_ draft: SessionDraft)
}

@MainActor
struct SwiftDataPersistenceService: PersistenceServiceProtocol {
    let context: ModelContext

    func seedSampleSessionsIfNeeded() {
        let descriptor = FetchDescriptor<StoredGameSession>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        SampleData.sampleSessions.forEach(context.insert)
        try? context.save()
    }

    func saveProfile(
        name: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String
    ) {
        let descriptor = FetchDescriptor<PlayerProfile>()
        let profile = ((try? context.fetch(descriptor)) ?? []).first

        if let profile {
            profile.name = name
            profile.dominantArmRawValue = dominantArm.rawValue
            profile.skillLevelRawValue = skillLevel.rawValue
            profile.syncedPaddleName = paddleName
            profile.completedOnboarding = true
        } else {
            context.insert(
                PlayerProfile(
                    name: name,
                    dominantArm: dominantArm,
                    skillLevel: skillLevel,
                    syncedPaddleName: paddleName,
                    completedOnboarding: true
                )
            )
        }

        try? context.save()
    }

    func saveSession(_ draft: SessionDraft) {
        context.insert(
            StoredGameSession(
                mode: draft.mode,
                startDate: draft.startDate,
                endDate: draft.endDate,
                playerOneName: draft.playerOneName,
                playerTwoName: draft.playerTwoName,
                playerOneScore: draft.playerOneScore,
                playerTwoScore: draft.playerTwoScore,
                averageSwingSpeed: draft.averageSwingSpeed,
                maxSwingSpeed: draft.maxSwingSpeed,
                sweetSpotPercentage: draft.sweetSpotPercentage,
                totalHits: draft.totalHits,
                winnerName: draft.winnerName,
                longestStreak: draft.longestStreak,
                totalValidVolleys: draft.totalValidVolleys,
                bestRallyLength: draft.bestRallyLength
            )
        )
        try? context.save()
    }
}

enum SampleData {
    static let sampleSessions: [StoredGameSession] = [
        StoredGameSession(
            mode: .dinkSinks,
            startDate: .now.addingTimeInterval(-172_800),
            endDate: .now.addingTimeInterval(-172_720),
            playerOneName: "Dylan",
            playerTwoName: "Avery",
            playerOneScore: 19,
            playerTwoScore: 15,
            averageSwingSpeed: 24.7,
            maxSwingSpeed: 41.2,
            sweetSpotPercentage: 73.0,
            totalHits: 96,
            winnerName: "Dylan",
            longestStreak: 19,
            totalValidVolleys: 0,
            bestRallyLength: 0
        ),
        StoredGameSession(
            mode: .theRealDeal,
            startDate: .now.addingTimeInterval(-86_400),
            endDate: .now.addingTimeInterval(-86_100),
            playerOneName: "Dylan",
            playerTwoName: "Jordan",
            playerOneScore: 5,
            playerTwoScore: 3,
            averageSwingSpeed: 29.4,
            maxSwingSpeed: 45.8,
            sweetSpotPercentage: 68.0,
            totalHits: 72,
            winnerName: "Dylan",
            longestStreak: 0,
            totalValidVolleys: 0,
            bestRallyLength: 14
        )
    ]
}
