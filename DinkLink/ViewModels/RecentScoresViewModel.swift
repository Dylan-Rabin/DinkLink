import Foundation
import Observation

@MainActor
@Observable
final class RecentScoresViewModel {
    var commentsBySessionID: [UUID: [PublicComment]] = [:]
    var draftBySessionID: [UUID: String] = [:]
    var errorBySessionID: [UUID: String] = [:]
    var loadingSessionIDs: Set<UUID> = []
    var submittingSessionIDs: Set<UUID> = []

    @ObservationIgnored
    private let commentsService: CommentsServiceProtocol
    @ObservationIgnored
    private let authService: SupabaseAuthService

    init(
        commentsService: CommentsServiceProtocol,
        authService: SupabaseAuthService
    ) {
        self.commentsService = commentsService
        self.authService = authService
    }

    func loadComments(for sessionID: UUID) async {
        guard !loadingSessionIDs.contains(sessionID) else { return }

        loadingSessionIDs.insert(sessionID)
        defer { loadingSessionIDs.remove(sessionID) }

        do {
            commentsBySessionID[sessionID] = try await commentsService.fetchComments(for: sessionID)
            errorBySessionID[sessionID] = nil
        } catch {
            commentsBySessionID[sessionID] = commentsBySessionID[sessionID] ?? []
            errorBySessionID[sessionID] = "Comments are unavailable right now."
        }
    }

    func submitComment(for sessionID: UUID, authorName: String) async {
        guard !submittingSessionIDs.contains(sessionID) else { return }

        let trimmedBody = draft(for: sessionID).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { return }
        guard let accessToken = authService.accessToken, let userID = authService.currentUserID else {
            errorBySessionID[sessionID] = "Sign in from Profile to post comments."
            return
        }

        submittingSessionIDs.insert(sessionID)
        defer { submittingSessionIDs.remove(sessionID) }

        do {
            let newComment = try await commentsService.createComment(
                itemID: sessionID,
                userID: userID,
                authorName: authorName,
                accessToken: accessToken,
                body: trimmedBody
            )
            commentsBySessionID[sessionID, default: []].insert(newComment, at: 0)
            draftBySessionID[sessionID] = ""
            errorBySessionID[sessionID] = nil
        } catch {
            errorBySessionID[sessionID] = "Couldn't post that comment."
        }
    }

    func comments(for sessionID: UUID) -> [PublicComment] {
        commentsBySessionID[sessionID] ?? []
    }

    func draft(for sessionID: UUID) -> String {
        draftBySessionID[sessionID] ?? ""
    }

    func setDraft(_ value: String, for sessionID: UUID) {
        draftBySessionID[sessionID] = value
    }

    func errorMessage(for sessionID: UUID) -> String? {
        errorBySessionID[sessionID]
    }

    func isLoadingComments(for sessionID: UUID) -> Bool {
        loadingSessionIDs.contains(sessionID)
    }

    func isSubmittingComment(for sessionID: UUID) -> Bool {
        submittingSessionIDs.contains(sessionID)
    }
}
