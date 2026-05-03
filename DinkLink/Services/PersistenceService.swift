import Foundation
import SwiftData

protocol PersistenceServiceProtocol {
    func seedDylanSessions(profileID: UUID)
    func fetchSavedSessions() -> [StoredGameSession]
    func saveProfile(
        name: String,
        locationName: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String,
        supabaseUserID: UUID?
    ) throws -> PlayerProfile
    func saveSession(_ draft: SessionDraft)
}

// Convenience overload so existing call sites that don't pass a userID still compile.
extension PersistenceServiceProtocol {
    func saveProfile(
        name: String,
        locationName: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String
    ) throws -> PlayerProfile {
        try saveProfile(
            name: name,
            locationName: locationName,
            dominantArm: dominantArm,
            skillLevel: skillLevel,
            paddleName: paddleName,
            supabaseUserID: nil
        )
    }
}

@MainActor
struct SwiftDataPersistenceService: PersistenceServiceProtocol {
    let context: ModelContext

    func seedDylanSessions(profileID: UUID) {
        SampleData.makeSessions(ownerProfileID: profileID).forEach(context.insert)
        try? context.save()
    }

    func fetchSavedSessions() -> [StoredGameSession] {
        let descriptor = FetchDescriptor<StoredGameSession>()
        return (try? context.fetch(descriptor)) ?? []
    }

    func saveProfile(
        name: String,
        locationName: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String,
        supabaseUserID: UUID?
    ) throws -> PlayerProfile {
        let descriptor = FetchDescriptor<PlayerProfile>()
        let allProfiles = (try? context.fetch(descriptor)) ?? []

        // The auth UUID IS the profile ID. Look up the profile by ID so switching
        // users on the same device creates separate, non-overlapping profiles.
        let existingProfile: PlayerProfile?
        if let uid = supabaseUserID {
            existingProfile = allProfiles.first { $0.id == uid }
        } else {
            existingProfile = allProfiles.first
        }

        let savedProfile: PlayerProfile

        if let existingProfile {
            existingProfile.name = name
            existingProfile.locationName = locationName
            existingProfile.dominantArmRawValue = dominantArm.rawValue
            existingProfile.skillLevelRawValue = skillLevel.rawValue
            existingProfile.syncedPaddleName = paddleName
            existingProfile.completedOnboarding = true
            savedProfile = existingProfile
        } else {
            // Create the profile with id = auth UUID so every piece of ownership
            // data in the app (session.ownerProfileID, Supabase user_id) shares
            // the exact same value — no secondary lookup key needed.
            let newProfile = PlayerProfile(
                id: supabaseUserID ?? UUID(),
                name: name,
                locationName: locationName,
                dominantArm: dominantArm,
                skillLevel: skillLevel,
                syncedPaddleName: paddleName,
                completedOnboarding: true
            )
            context.insert(newProfile)
            savedProfile = newProfile
        }

        try context.save()
        return savedProfile
    }

    func saveSession(_ draft: SessionDraft) {
        let session = StoredGameSession(
            mode: draft.mode,
            startDate: draft.startDate,
            endDate: draft.endDate,
            playerOneName: draft.playerOneName,
            playerTwoName: draft.playerTwoName,
            playerOneScore: draft.playerOneScore,
            playerTwoScore: draft.playerTwoScore,
            totalHits: draft.totalHits,
            averageImpactStrength: draft.averageImpactStrength,
            maxImpactStrength: draft.maxImpactStrength,
            averageMotion: draft.averageMotion,
            centerHitPercentage: draft.centerHitPercentage,
            frontHits: draft.frontHits,
            backHits: draft.backHits,
            topHits: draft.topHits,
            bottomHits: draft.bottomHits,
            leftHits: draft.leftHits,
            rightHits: draft.rightHits,
            winnerName: draft.winnerName,
            longestStreak: draft.longestStreak,
            totalValidVolleys: draft.totalValidVolleys,
            bestRallyLength: draft.bestRallyLength,
            ownerProfileID: draft.ownerProfileID
        )
        // isDirty defaults to true on the model — marks it for upload on next sync.
        context.insert(session)
        try? context.save()
    }
}

enum SampleData {
    static func makeSessions(ownerProfileID: UUID) -> [StoredGameSession] {
        [
            StoredGameSession(
                mode: .dinkSinks,
                startDate: .now.addingTimeInterval(-172_800),
                endDate: .now.addingTimeInterval(-172_720),
                playerOneName: "Dylan",
                playerTwoName: "Avery",
                playerOneScore: 19,
                playerTwoScore: 15,
                totalHits: 96,
                averageImpactStrength: 742.0,
                maxImpactStrength: 930,
                averageMotion: 1.44,
                centerHitPercentage: 38.0,
                frontHits: 18,
                backHits: 14,
                topHits: 22,
                bottomHits: 16,
                leftHits: 12,
                rightHits: 14,
                winnerName: "Dylan",
                longestStreak: 19,
                totalValidVolleys: 0,
                bestRallyLength: 0,
                ownerProfileID: ownerProfileID
            ),
            StoredGameSession(
                mode: .theRealDeal,
                startDate: .now.addingTimeInterval(-86_400),
                endDate: .now.addingTimeInterval(-86_100),
                playerOneName: "Dylan",
                playerTwoName: "Jordan",
                playerOneScore: 5,
                playerTwoScore: 3,
                totalHits: 72,
                averageImpactStrength: 701.0,
                maxImpactStrength: 910,
                averageMotion: 1.62,
                centerHitPercentage: 34.0,
                frontHits: 11,
                backHits: 13,
                topHits: 17,
                bottomHits: 10,
                leftHits: 9,
                rightHits: 12,
                winnerName: "Dylan",
                longestStreak: 0,
                totalValidVolleys: 0,
                bestRallyLength: 14,
                ownerProfileID: ownerProfileID
            )
        ]
    }
}
