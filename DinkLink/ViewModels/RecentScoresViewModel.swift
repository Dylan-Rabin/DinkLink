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
    var likeCountsByCommentID: [UUID: Int] = [:]
    var likedCommentIDs: Set<UUID> = []
    var togglingLikeCommentIDs: Set<UUID> = []

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
            let comments = try await commentsService.fetchComments(for: sessionID)
            commentsBySessionID[sessionID] = comments
            try await loadLikes(for: comments)
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
            likeCountsByCommentID[newComment.id] = 0
            likedCommentIDs.remove(newComment.id)
            draftBySessionID[sessionID] = ""
            errorBySessionID[sessionID] = nil
        } catch {
            errorBySessionID[sessionID] = "Couldn't post that comment."
        }
    }

    func comments(for sessionID: UUID) -> [PublicComment] {
        commentsBySessionID[sessionID] ?? []
    }

    func toggleLike(for comment: PublicComment) async {
        guard !togglingLikeCommentIDs.contains(comment.id) else { return }
        guard let accessToken = authService.accessToken, let userID = authService.currentUserID else {
            errorBySessionID[comment.itemID] = "Sign in from Profile to like comments."
            return
        }

        togglingLikeCommentIDs.insert(comment.id)
        defer { togglingLikeCommentIDs.remove(comment.id) }

        do {
            if likedCommentIDs.contains(comment.id) {
                try await commentsService.unlikeComment(
                    commentID: comment.id,
                    userID: userID,
                    accessToken: accessToken
                )
                likedCommentIDs.remove(comment.id)
                likeCountsByCommentID[comment.id] = max(0, likeCount(for: comment.id) - 1)
            } else {
                try await commentsService.likeComment(
                    commentID: comment.id,
                    userID: userID,
                    accessToken: accessToken
                )
                likedCommentIDs.insert(comment.id)
                likeCountsByCommentID[comment.id] = likeCount(for: comment.id) + 1
            }
            errorBySessionID[comment.itemID] = nil
        } catch {
            errorBySessionID[comment.itemID] = "Couldn't update that like."
        }
    }

    func draft(for sessionID: UUID) -> String {
        draftBySessionID[sessionID] ?? ""
    }

    func setDraft(_ value: String, for sessionID: UUID) {
        draftBySessionID[sessionID] = value
    }

    func likeCount(for commentID: UUID) -> Int {
        likeCountsByCommentID[commentID] ?? 0
    }

    func isLiked(commentID: UUID) -> Bool {
        likedCommentIDs.contains(commentID)
    }

    func isTogglingLike(commentID: UUID) -> Bool {
        togglingLikeCommentIDs.contains(commentID)
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

    private func loadLikes(for comments: [PublicComment]) async throws {
        let likeRecords = try await commentsService.fetchLikes(for: comments.map(\.id))
        let currentUserID = authService.currentUserID
        let countsByCommentID = Dictionary(grouping: likeRecords, by: \.commentID).mapValues(\.count)
        let loadedCommentIDs = Set(comments.map(\.id))

        for commentID in loadedCommentIDs {
            likeCountsByCommentID[commentID] = countsByCommentID[commentID] ?? 0
        }

        let likedIDs = Set(
            likeRecords.compactMap { record in
                record.userID == currentUserID ? record.commentID : nil
            }
        )

        likedCommentIDs.subtract(loadedCommentIDs)
        likedCommentIDs.formUnion(likedIDs)
    }
}
