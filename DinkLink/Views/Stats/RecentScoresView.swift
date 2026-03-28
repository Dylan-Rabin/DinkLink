import SwiftUI

struct RecentScoresView: View {
    let profile: PlayerProfile
    let sessions: [StoredGameSession]
    let authService: SupabaseAuthService

    @State private var viewModel: RecentScoresViewModel

    init(
        profile: PlayerProfile,
        sessions: [StoredGameSession],
        authService: SupabaseAuthService,
        commentsService: CommentsServiceProtocol = SupabaseCommentsService()
    ) {
        self.profile = profile
        self.sessions = sessions
        self.authService = authService
        _viewModel = State(
            initialValue: RecentScoresViewModel(
                commentsService: commentsService,
                authService: authService
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.deepShadow, AppTheme.graphite, AppTheme.steel, AppTheme.mutedGlow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(AppTheme.mutedGlow)
                    .frame(width: 320, height: 320)
                    .blur(radius: 110)
                    .offset(x: -140, y: -260)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        if sessions.isEmpty {
                            emptyStateCard
                        } else {
                            VStack(spacing: 14) {
                                ForEach(sessions) { session in
                                    scoreCard(for: session)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scores")
                .dinkHeading(30, color: AppTheme.neon)

            Text("\(sessions.count) recent \(sessions.count == 1 ? "result" : "results")")
                .dinkBody(13, color: AppTheme.ash)

            Text("Review winners, scorelines, and add public comments to each finished game.")
                .dinkBody(14, color: AppTheme.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No scores yet")
                .dinkHeading(22, color: AppTheme.smoke)

            Text("Completed matches will appear here once sessions are recorded.")
                .dinkBody(14, color: AppTheme.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(AppTheme.steel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func scoreCard(for session: StoredGameSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.mode.rawValue)
                        .dinkHeading(18, color: AppTheme.smoke)

                    Text(session.endDate.formatted(date: .abbreviated, time: .shortened))
                        .dinkBody(11, color: AppTheme.ash)
                }

                Spacer()

                Text("WINNER")
                    .dinkBody(10, color: AppTheme.ash)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.playerOneName)
                        .dinkBody(13, color: AppTheme.smoke)
                    Text(session.playerTwoName)
                        .dinkBody(13, color: AppTheme.smoke)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(session.playerOneScore)")
                        .dinkHeading(20, color: AppTheme.neon)
                    Text("\(session.playerTwoScore)")
                        .dinkHeading(20, color: AppTheme.neon)
                }
            }

            Text("Winner: \(session.winnerName)")
                .dinkBody(13, color: AppTheme.neon)

            Divider()
                .overlay(AppTheme.smoke.opacity(0.08))

            commentsSection(for: session)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.steel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
        )
        .task(id: commentLoadTaskID(for: session)) {
            await viewModel.loadComments(for: session.id)
        }
    }

    private func commentsSection(for session: StoredGameSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Comments")
                    .dinkHeading(16, color: AppTheme.smoke)

                Spacer()

                if viewModel.isLoadingComments(for: session.id) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.neon)
                } else {
                    Text("\(viewModel.comments(for: session.id).count)")
                        .dinkBody(12, color: AppTheme.ash)
                }
            }

            let comments = viewModel.comments(for: session.id)

            if !authService.isAuthenticated {
                Text("Sign in from Profile to join the public thread for this game.")
                    .dinkBody(12, color: AppTheme.ash)
            }

            if comments.isEmpty, !viewModel.isLoadingComments(for: session.id) {
                Text("No comments yet. Start the conversation on this match.")
                    .dinkBody(13, color: AppTheme.ash)
            } else {
                VStack(spacing: 10) {
                    ForEach(comments) { comment in
                        commentCard(comment)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TextField(
                    "Write a public comment about this game",
                    text: Binding(
                        get: { viewModel.draft(for: session.id) },
                        set: { viewModel.setDraft($0, for: session.id) }
                    ),
                    axis: .vertical
                )
                .lineLimit(2...4)
                .font(.dinkBody(14))
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .padding(14)
                .background(AppTheme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(!authService.isAuthenticated)

                HStack {
                    Text(commentComposerLabel)
                        .dinkBody(11, color: AppTheme.ash)

                    Spacer()

                    Button {
                        Task {
                            await viewModel.submitComment(for: session.id, authorName: profile.name)
                        }
                    } label: {
                        if viewModel.isSubmittingComment(for: session.id) {
                            ProgressView()
                                .tint(AppTheme.ink)
                        } else {
                            Text("Post")
                                .font(.dinkHeading(14))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.neon)
                    .foregroundStyle(AppTheme.ink)
                    .disabled(
                        !authService.isAuthenticated ||
                        viewModel.draft(for: session.id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            viewModel.isSubmittingComment(for: session.id)
                    )
                }
            }

            if let errorMessage = viewModel.errorMessage(for: session.id) {
                Text(errorMessage)
                    .dinkBody(12, color: AppTheme.ash)
            }
        }
    }

    private func commentCard(_ comment: PublicComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(comment.authorName)
                    .dinkHeading(14, color: AppTheme.neon)

                Spacer()

                Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .dinkBody(10, color: AppTheme.ash)
            }

            Text(comment.body)
                .dinkBody(13, color: AppTheme.smoke)

            HStack {
                Button {
                    Task {
                        await viewModel.toggleLike(for: comment)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isTogglingLike(commentID: comment.id) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.neon)
                        } else {
                            Image(systemName: viewModel.isLiked(commentID: comment.id) ? "heart.fill" : "heart")
                                .foregroundStyle(
                                    viewModel.isLiked(commentID: comment.id) ? AppTheme.neon : AppTheme.ash
                                )
                        }

                        Text("\(viewModel.likeCount(for: comment.id))")
                            .dinkBody(11, color: AppTheme.ash)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!authService.isAuthenticated || viewModel.isTogglingLike(commentID: comment.id))

                Spacer()

                if !authService.isAuthenticated {
                    Text("Sign in to like")
                        .dinkBody(11, color: AppTheme.ash)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.graphite.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var commentComposerLabel: String {
        if let email = authService.currentUserEmail {
            return "Signed in as \(email)"
        }

        return "Posting as \(profile.name)"
    }

    private func commentLoadTaskID(for session: StoredGameSession) -> String {
        "\(session.id.uuidString)-\(authService.currentUserID?.uuidString ?? "anon")"
    }
}
