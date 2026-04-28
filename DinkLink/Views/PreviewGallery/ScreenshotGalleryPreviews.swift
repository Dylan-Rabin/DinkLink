import SwiftData
import SwiftUI

#Preview("1 Home") {
    HomeView(
        profile: ScreenshotPreviewData.profile,
        sessions: ScreenshotPreviewData.sessions,
        bluetoothService: MockBluetoothService(),
        authService: ScreenshotPreviewData.signedOutAuthService(),
        weatherService: PreviewWeatherService()
    )
    .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}

#Preview("2 Stats") {
    StatsView(
        profile: ScreenshotPreviewData.profile,
        sessions: ScreenshotPreviewData.sessions
    )
}

#Preview("3 Scores") {
    RecentScoresView(
        profile: ScreenshotPreviewData.profile,
        sessions: ScreenshotPreviewData.sessions,
        authService: ScreenshotPreviewData.signedInAuthService(),
        commentsService: PreviewCommentsService()
    )
}

#Preview("4 Profile") {
    ProfileView(
        profile: ScreenshotPreviewData.profile,
        bluetoothService: MockBluetoothService(),
        authService: ScreenshotPreviewData.signedInAuthService(),
        sessions: ScreenshotPreviewData.sessions,
        progressionPersistenceService: PreviewProgressionPersistenceService(),
        onLogOut: { _ in }
    )
    .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}

#Preview("5 Session Setup") {
    NavigationStack {
        InviteSetupView(
            primaryPlayer: ScreenshotPreviewData.profile.asPlayer,
            mode: .theRealDeal,
            bluetoothService: MockBluetoothService(),
            persistenceService: PreviewPersistenceService(),
            authService: ScreenshotPreviewData.signedOutAuthService()
        )
    }
}

#Preview("6 Live Match") {
    NavigationStack {
        LiveGameView(viewModel: ScreenshotPreviewData.liveGameViewModel())
    }
}

#Preview("7 Current Session") {
    NavigationStack {
        CurrentSessionView(
            profile: ScreenshotPreviewData.profile,
            bluetoothService: MockBluetoothService(),
            authService: ScreenshotPreviewData.signedOutAuthService(),
            persistenceService: PreviewPersistenceService()
        )
    }
}

#Preview("8 Onboarding") {
    OnboardingFlowView(
        viewModel: OnboardingViewModel(
            bluetoothService: MockBluetoothService(),
            persistenceService: PreviewPersistenceService(),
            authService: ScreenshotPreviewData.signedOutAuthService(),
            existingProfile: nil
        ),
        onComplete: { _ in }
    )
}

#Preview("9 Main Tabs") {
    MainTabView(
        profile: ScreenshotPreviewData.profile,
        sessions: ScreenshotPreviewData.sessions,
        bluetoothService: MockBluetoothService(),
        authService: ScreenshotPreviewData.signedInAuthService(),
        onLogOut: { _ in }
    )
    .modelContainer(for: [PlayerProfile.self, StoredGameSession.self], inMemory: true)
}

#Preview("10 Rank Up") {
    RankUpCelebrationView(
        awardResult: ScreenshotPreviewData.rankUpAwardResult,
        onDismiss: {}
    )
}

@MainActor
private enum ScreenshotPreviewData {
    static let profile = PlayerProfile(
        name: "Dylan",
        locationName: "Austin, TX",
        dominantArm: .right,
        skillLevel: .intermediate,
        syncedPaddleName: "DL Pro Paddle",
        completedOnboarding: true
    )

    static let sessions: [StoredGameSession] = [
        StoredGameSession(
            mode: .dinkSinks,
            startDate: .now.addingTimeInterval(-172_800),
            endDate: .now.addingTimeInterval(-172_710),
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
        ),
        StoredGameSession(
            mode: .volleyWallies,
            startDate: .now.addingTimeInterval(-43_200),
            endDate: .now.addingTimeInterval(-43_120),
            playerOneName: "Dylan",
            playerTwoName: "Casey",
            playerOneScore: 28,
            playerTwoScore: 24,
            averageSwingSpeed: 31.8,
            maxSwingSpeed: 47.6,
            sweetSpotPercentage: 76.0,
            totalHits: 118,
            winnerName: "Dylan",
            longestStreak: 0,
            totalValidVolleys: 28,
            bestRallyLength: 0
        )
    ]

    static let rankUpAwardResult = XPAwardResult(
        xpGained: 140,
        leveledUp: true,
        oldLevel: 3,
        newLevel: 4,
        rankedUp: true,
        oldRank: .bronze,
        newRank: .silver,
        updatedProgression: ProgressionService.buildUserProgression(
            userID: UUID().uuidString,
            totalXP: 520
        ),
        breakdown: [
            XPBreakdownItem(source: "Complete session", xp: 50),
            XPBreakdownItem(source: "Every 10 hits", xp: 40),
            XPBreakdownItem(source: "Sweet spot >= 60%", xp: 15),
            XPBreakdownItem(source: "Played with a friend", xp: 25)
        ]
    )

    static func signedOutAuthService() -> SupabaseAuthService {
        SupabaseAuthService(storage: UserDefaults(suiteName: "ScreenshotPreviewSignedOut") ?? .standard)
    }

    static func signedInAuthService() -> SupabaseAuthService {
        let service = SupabaseAuthService(
            storage: UserDefaults(suiteName: "ScreenshotPreviewSignedIn") ?? .standard
        )
        service.currentSession = SupabaseAuthSession(
            accessToken: "preview-token",
            refreshToken: "preview-refresh",
            user: SupabaseAuthUser(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                email: "dylan@example.com"
            ),
            expiresAt: .now.addingTimeInterval(3_600)
        )
        return service
    }

    static func liveGameViewModel() -> LiveGameViewModel {
        let viewModel = LiveGameViewModel(
            mode: .theRealDeal,
            players: [
                profile.asPlayer,
                Player(name: "Jordan", dominantArm: .left, skillLevel: .intermediate)
            ],
            bluetoothService: MockBluetoothService(),
            persistenceService: PreviewPersistenceService(),
            authService: signedInAuthService(),
            progressionPersistenceService: PreviewProgressionPersistenceService()
        )
        viewModel.elapsedSeconds = 428
        viewModel.latestSwingSpeed = 34.6
        viewModel.latestFeedback = "Clean contact. Keep your paddle face steady."
        viewModel.currentRallyHits = 7
        viewModel.playerMetrics[0].totalHits = 18
        viewModel.playerMetrics[0].cumulativeSwingSpeed = 547.2
        viewModel.playerMetrics[0].maxSwingSpeed = 41.4
        viewModel.playerMetrics[0].sweetSpotHits = 12
        viewModel.playerMetrics[0].points = 4
        viewModel.playerMetrics[1].totalHits = 16
        viewModel.playerMetrics[1].cumulativeSwingSpeed = 476.8
        viewModel.playerMetrics[1].maxSwingSpeed = 39.1
        viewModel.playerMetrics[1].sweetSpotHits = 10
        viewModel.playerMetrics[1].points = 3
        viewModel.rallies = [
            Rally(initiatingPlayerName: "Dylan", hits: 9, pointWinnerName: "Dylan"),
            Rally(initiatingPlayerName: "Jordan", hits: 6, pointWinnerName: "Jordan")
        ]
        viewModel.roundBanner = "Dylan is on court."
        return viewModel
    }
}

private struct PreviewPersistenceService: PersistenceServiceProtocol {
    func seedSampleSessionsIfNeeded() {}

    func fetchSavedSessions() -> [StoredGameSession] { ScreenshotPreviewData.sessions }

    func saveProfile(
        name: String,
        locationName: String,
        dominantArm: DominantArm,
        skillLevel: SkillLevel,
        paddleName: String
    ) throws -> PlayerProfile {
        PlayerProfile(
            name: name,
            locationName: locationName,
            dominantArm: dominantArm,
            skillLevel: skillLevel,
            syncedPaddleName: paddleName,
            completedOnboarding: true
        )
    }

    func saveSession(_ draft: SessionDraft) {}
}

private struct PreviewWeatherService: WeatherServiceProtocol {
    func resolveLocation(named query: String) async throws -> CourtLocation {
        CourtLocation(name: query, latitude: 30.2672, longitude: -97.7431)
    }

    func fetchCurrentConditions(for location: CourtLocation) async throws -> CourtCurrentConditions {
        CourtCurrentConditions(temperature: 74, windSpeed: 7, weatherCode: 1)
    }
}

private struct PreviewCommentsService: CommentsServiceProtocol {
    func fetchComments(for itemID: UUID) async throws -> [PublicComment] {
        [
            PublicComment(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID(),
                itemID: itemID,
                userID: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
                authorName: "Avery",
                body: "That third-game rally was unreal.",
                createdAt: .now.addingTimeInterval(-3_600)
            ),
            PublicComment(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID(),
                itemID: itemID,
                userID: UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID(),
                authorName: "Jordan",
                body: "Your backhand speed looked much better here.",
                createdAt: .now.addingTimeInterval(-1_800)
            )
        ]
    }

    func fetchLikes(for commentIDs: [UUID]) async throws -> [CommentLikeRecord] {
        guard let firstID = commentIDs.first else { return [] }
        return [
            CommentLikeRecord(
                id: UUID(uuidString: "66666666-6666-6666-6666-666666666666") ?? UUID(),
                commentID: firstID,
                userID: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
            )
        ]
    }

    func createComment(
        itemID: UUID,
        userID: UUID,
        authorName: String,
        accessToken: String,
        body: String
    ) async throws -> PublicComment {
        PublicComment(
            id: UUID(),
            itemID: itemID,
            userID: userID,
            authorName: authorName,
            body: body,
            createdAt: .now
        )
    }

    func likeComment(commentID: UUID, userID: UUID, accessToken: String) async throws {}

    func unlikeComment(commentID: UUID, userID: UUID, accessToken: String) async throws {}
}

private struct PreviewProgressionPersistenceService: ProgressionPersistenceServiceProtocol {
    func fetchProgression(userID: UUID, accessToken: String) async throws -> UserProgression? {
        ProgressionService.buildUserProgression(userID: userID.uuidString, totalXP: 520)
    }

    func backfillProgressionIfNeeded(
        userID: UUID,
        accessToken: String,
        localProgression: UserProgression,
        remoteProgression: UserProgression?,
        sessionCount: Int
    ) async throws -> UserProgression {
        remoteProgression ?? localProgression
    }

    func applySessionAward(
        userID: UUID,
        accessToken: String,
        awardResult: XPAwardResult,
        metadata: [String: String]
    ) async throws {}
}
