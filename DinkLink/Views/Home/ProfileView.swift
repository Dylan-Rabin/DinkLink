import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: PlayerProfile
    let bluetoothService: MockBluetoothService
    let authService: SupabaseAuthService
    let sessions: [StoredGameSession]
    let onLogOut: (PlayerProfile) -> Void
    private let progressionPersistenceService: ProgressionPersistenceServiceProtocol

    @State private var locationName: String
    @State private var dominantArm: DominantArm
    @State private var skillLevel: SkillLevel
    @State private var saveMessage: String?
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var remoteProgression: UserProgression?
    @State private var progressionErrorMessage: String?

    init(
        profile: PlayerProfile,
        bluetoothService: MockBluetoothService,
        authService: SupabaseAuthService,
        sessions: [StoredGameSession],
        progressionPersistenceService: ProgressionPersistenceServiceProtocol = SupabaseProgressionPersistenceService(),
        onLogOut: @escaping (PlayerProfile) -> Void
    ) {
        self.profile = profile
        self.bluetoothService = bluetoothService
        self.authService = authService
        self.sessions = sessions
        self.progressionPersistenceService = progressionPersistenceService
        self.onLogOut = onLogOut
        _locationName = State(initialValue: profile.locationName)
        _dominantArm = State(initialValue: profile.dominantArm)
        _skillLevel = State(initialValue: profile.skillLevel)
        _authEmail = State(initialValue: authService.currentUserEmail ?? "")
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Profile")
                                .dinkHeading(30, color: AppTheme.neon)

                            Text(profile.name)
                                .dinkBody(13, color: AppTheme.ash)

                            Text("Update your home court location and player settings.")
                                .dinkBody(14, color: AppTheme.smoke)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        progressionCard

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Player Settings")
                                .dinkHeading(20, color: AppTheme.smoke)

                            Text("Name")
                                .dinkBody(11, color: AppTheme.ash)

                            Text(profile.name)
                                .dinkBody(14, color: AppTheme.smoke)

                            Text("Location")
                                .dinkBody(11, color: AppTheme.ash)

                            TextField("City or ZIP code", text: $locationName)
                                .font(.dinkBody(15))
                                .foregroundStyle(AppTheme.ink)
                                .tint(AppTheme.ink)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(AppTheme.smoke)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            /* Text("Dominant Arm")
                                .dinkBody(11, color: AppTheme.ash)

                            Picker("Dominant Arm", selection: $dominantArm) {
                                ForEach(DominantArm.allCases) { arm in
                                    Text(arm.rawValue).tag(arm)
                                }
                            }
                            .pickerStyle(.segmented)

                            Text("Skill Level")
                                .dinkBody(11, color: AppTheme.ash)

                            Picker("Skill Level", selection: $skillLevel) {
                                ForEach(SkillLevel.allCases) { level in
                                    Text(level.rawValue).tag(level)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.graphite, AppTheme.steel],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            */

                            Button("Save Changes") {
                                saveProfileChanges()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.neon)
                            .foregroundStyle(AppTheme.ink)
                            .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if let saveMessage {
                                Text(saveMessage)
                                    .dinkBody(12, color: AppTheme.ash)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.steel.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Paddle")
                                .dinkHeading(20, color: AppTheme.smoke)

                            detailRow(title: "Connected", value: bluetoothService.connectedDevice?.name ?? profile.syncedPaddleName)
                            detailRow(title: "Battery", value: "\(bluetoothService.connectedDevice?.batteryLevel ?? 100)%")
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.steel.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Comments Account")
                                .dinkHeading(20, color: AppTheme.smoke)

                            if authService.isAuthenticated {
                                detailRow(
                                    title: "Signed In",
                                    value: authService.currentUserEmail ?? "Authenticated user"
                                )

                                Button("Sign Out") {
                                    authService.signOut()
                                }
                                .buttonStyle(.bordered)
                                .tint(AppTheme.neon)
                            } else {
                                Text("Sign in or create an account to post public comments on finished matches.")
                                    .dinkBody(14, color: AppTheme.ash)

                                TextField("Email", text: $authEmail)
                                    .font(.dinkBody(15))
                                    .foregroundStyle(AppTheme.ink)
                                    .tint(AppTheme.ink)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding()
                                    .background(AppTheme.smoke)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                SecureField("Password", text: $authPassword)
                                    .font(.dinkBody(15))
                                    .foregroundStyle(AppTheme.ink)
                                    .tint(AppTheme.ink)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding()
                                    .background(AppTheme.smoke)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                HStack {
                                    Button("Sign In") {
                                        Task {
                                            await authService.signIn(email: authEmail, password: authPassword)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.neon)
                                    .foregroundStyle(AppTheme.ink)
                                    .disabled(authService.isAuthenticating)

                                    Button("Create Account") {
                                        Task {
                                            await authService.signUp(email: authEmail, password: authPassword)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(AppTheme.neon)
                                    .disabled(authService.isAuthenticating)
                                }
                            }

                            if authService.isAuthenticating {
                                ProgressView()
                                    .tint(AppTheme.neon)
                            }

                            if let authStatusMessage = authService.authStatusMessage {
                                Text(authStatusMessage)
                                    .dinkBody(12, color: AppTheme.neon)
                            }

                            if let authErrorMessage = authService.authErrorMessage {
                                Text(authErrorMessage)
                                    .dinkBody(12, color: AppTheme.ash)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.steel.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
                        )

                        Button("Log Out") {
                            logOut()
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.ash)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task(id: authService.currentUserID?.uuidString) {
            await loadRemoteProgression()
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .dinkBody(13, color: AppTheme.ash)
            Spacer()
            Text(value)
                .dinkBody(13, color: AppTheme.smoke)
        }
    }

    private var progressionSummary: (progression: UserProgression, latestAward: XPAwardResult?) {
        ProgressionService.buildProgression(for: profile, sessions: sessions)
    }

    private var displayedProgression: UserProgression {
        remoteProgression ?? progressionSummary.progression
    }

    private var progressionCardViewData: ProgressionCardViewData {
        ProgressionService.buildProgressionCardViewData(from: displayedProgression)
    }

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Progression")
                        .dinkHeading(20, color: AppTheme.smoke)

                    Text(displayedProgression.rank.badgeTitle)
                        .dinkBody(12, color: AppTheme.ash)
                }

                Spacer()

                Text("LVL \(progressionCardViewData.level)")
                    .dinkHeading(20, color: AppTheme.neon)
            }

            HStack {
                statChip(title: "Rank", value: progressionCardViewData.rankBadge)
                statChip(title: "Total XP", value: "\(progressionCardViewData.totalXP)")
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: progressionCardViewData.progressBarValue)
                    .tint(AppTheme.neon)

                HStack {
                    Text(progressionCardViewData.currentLevelXPRangeLabel)
                        .dinkBody(11, color: AppTheme.ash)
                    Spacer()
                    Text(progressionCardViewData.nextLevelLabel)
                        .dinkBody(11, color: AppTheme.neon)
                }
            }

            if let latestAward = progressionSummary.latestAward {
                Text("+\(latestAward.xpGained) XP from your latest session")
                    .dinkBody(12, color: AppTheme.smoke)
            } else {
                Text("Finish sessions to earn XP and climb ranks.")
                    .dinkBody(12, color: AppTheme.smoke)
            }

            if let progressionErrorMessage {
                Text(progressionErrorMessage)
                    .dinkBody(11, color: AppTheme.ash)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.steel.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.smoke.opacity(0.08), lineWidth: 1)
        )
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .dinkBody(10, color: AppTheme.ash)
            Text(value)
                .dinkHeading(15, color: AppTheme.neon)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(AppTheme.graphite.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @MainActor
    private func saveProfileChanges() {
        profile.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.dominantArmRawValue = dominantArm.rawValue
        profile.skillLevelRawValue = skillLevel.rawValue

        do {
            try modelContext.save()
            saveMessage = "Profile updated."
        } catch {
            saveMessage = "Couldn't save changes right now."
        }
    }

    @MainActor
    private func logOut() {
        onLogOut(profile)
    }

    @MainActor
    private func loadRemoteProgression() async {
        guard
            let userID = authService.currentUserID,
            let accessToken = authService.accessToken
        else {
            remoteProgression = nil
            progressionErrorMessage = nil
            return
        }

        do {
            let localProgression = progressionSummary.progression
            let fetchedRemoteProgression = try await progressionPersistenceService
                .fetchProgression(userID: userID, accessToken: accessToken)
            remoteProgression = try await progressionPersistenceService.backfillProgressionIfNeeded(
                userID: userID,
                accessToken: accessToken,
                localProgression: localProgression,
                remoteProgression: fetchedRemoteProgression,
                sessionCount: sessions.count
            )
            progressionErrorMessage = nil
        } catch {
            remoteProgression = nil
            progressionErrorMessage = "Using local progression until cloud sync is available."
        }
    }
}
