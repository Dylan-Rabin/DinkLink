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
    @State private var remoteProgression: UserProgression?
    @State private var progressionErrorMessage: String?
    @State private var localGPNProfile: GPNProfile?
    @State private var gpnUsernameInput = ""
    @State private var gpnPasswordInput = ""
    @State private var isGPNSyncing = false
    @State private var gpnError: String?

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

                        gpnCard

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
            loadLocalGPN()
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
                HStack(alignment: .center, spacing: 12) {
                    Image(displayedProgression.rank.badgeAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityLabel(displayedProgression.rank.badgeTitle)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Progression")
                            .dinkHeading(20, color: AppTheme.smoke)

                        Text(displayedProgression.rank.badgeTitle)
                            .dinkBody(12, color: AppTheme.ash)
                    }
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

    // MARK: - GPN Card

    private var gpnCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Global Pickleball Network")
                    .dinkHeading(20, color: AppTheme.smoke)
                Spacer()
                if let synced = localGPNProfile?.lastSyncedAt {
                    Text("Synced \(synced, style: .relative) ago")
                        .dinkBody(11, color: AppTheme.ash)
                }
            }

            if let gpn = localGPNProfile, !gpn.gpnUsername.isEmpty {
                // Connected state
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(gpn.gpnDisplayName.isEmpty ? gpn.gpnUsername : gpn.gpnDisplayName)
                            .dinkBody(15, color: AppTheme.smoke)
                        if !gpn.gpnLocation.isEmpty {
                            Text(gpn.gpnLocation)
                                .dinkBody(11, color: AppTheme.ash)
                        }
                    }
                    Spacer()
                    if !gpn.gpnProfileUrl.isEmpty, let url = URL(string: gpn.gpnProfileUrl) {
                        Link("View on GPN", destination: url)
                            .font(.dinkBody(12))
                            .foregroundStyle(AppTheme.neon)
                    }
                }

                // Skill levels
                HStack(spacing: 12) {
                    if gpn.singlesLevel > 0 {
                        statChip(title: "Singles", value: String(format: "%.2f", gpn.singlesLevel))
                    }
                    if gpn.doublesLevel > 0 {
                        statChip(title: "Doubles", value: String(format: "%.2f", gpn.doublesLevel))
                    }
                    if gpn.duprRating > 0 {
                        statChip(title: "DUPR", value: String(format: "%.3f", gpn.duprRating))
                    }
                }

                // Match stats
                if gpn.totalMatches > 0 {
                    HStack(spacing: 12) {
                        statChip(title: "Matches", value: "\(gpn.totalMatches)")
                        statChip(title: "Wins", value: "\(gpn.wins)")
                        statChip(title: "Win %", value: String(format: "%.1f%%", gpn.winPercentage))
                    }
                }

                Button(isGPNSyncing ? "Syncing..." : "Re-sync GPN") {
                    Task { await syncGPN() }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.neon)
                .disabled(isGPNSyncing)
            } else {
                // Not yet connected
                Text("Link your GPN account to display your skill level and DUPR rating.")
                    .dinkBody(13, color: AppTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("GPN Username", text: $gpnUsernameInput)
                    .font(.dinkBody(14))
                    .foregroundStyle(AppTheme.ink)
                    .tint(AppTheme.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(AppTheme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                SecureField("GPN Password", text: $gpnPasswordInput)
                    .font(.dinkBody(14))
                    .foregroundStyle(AppTheme.ink)
                    .tint(AppTheme.ink)
                    .padding(12)
                    .background(AppTheme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(isGPNSyncing ? "Connecting..." : "Connect GPN Account") {
                    Task { await syncGPN() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.ink)
                .disabled(gpnUsernameInput.isEmpty || gpnPasswordInput.isEmpty || isGPNSyncing)
            }

            if isGPNSyncing {
                ProgressView().tint(AppTheme.neon)
            }

            if let gpnError {
                Text(gpnError)
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
    }

    @MainActor
    private func loadLocalGPN() {
        let id = profile.id
        let descriptor = FetchDescriptor<GPNProfile>(
            predicate: #Predicate { $0.ownerProfileID == id }
        )
        localGPNProfile = (try? modelContext.fetch(descriptor))?.first
        if let gpn = localGPNProfile {
            gpnUsernameInput = gpn.gpnUsername
        }
    }

    @MainActor
    private func syncGPN() async {
        guard let accessToken = authService.accessToken else {
            gpnError = "Sign in to link your GPN account."
            return
        }
        isGPNSyncing = true
        gpnError = nil
        let service = GPNService()

        // First-link path: use whatever the user typed in.
        // Re-sync path: server already has the cached session — send nil/nil
        // so the Edge Function refreshes data without re-authenticating.
        let isAlreadyLinked = localGPNProfile?.gpnUsername.isEmpty == false
        let usernameToSend: String? = isAlreadyLinked && gpnPasswordInput.isEmpty
            ? nil
            : (gpnUsernameInput.isEmpty ? localGPNProfile?.gpnUsername : gpnUsernameInput)
        let passwordToSend: String? = gpnPasswordInput.isEmpty ? nil : gpnPasswordInput
        do {
            let response = try await service.syncProfile(
                gpnUsername: usernameToSend,
                gpnPassword: passwordToSend,
                accessToken: accessToken
            )
            let gpn = localGPNProfile ?? GPNProfile(ownerProfileID: profile.id)
            gpn.gpnUsername = response.gpnUsername
            gpn.gpnDisplayName = response.gpnDisplayName ?? ""
            gpn.gpnAvatarUrl = response.gpnAvatarUrl ?? ""
            gpn.gpnProfileUrl = response.gpnProfileUrl ?? ""
            gpn.gpnLocation = response.gpnLocation ?? ""
            gpn.singlesLevel = response.singlesLevel ?? 0
            gpn.doublesLevel = response.doublesLevel ?? 0
            gpn.overallLevel = response.overallLevel ?? 0
            gpn.duprRating = response.duprRating ?? 0
            gpn.totalMatches = response.totalMatches ?? 0
            gpn.wins = response.wins ?? 0
            gpn.losses = response.losses ?? 0
            gpn.winPercentage = response.winPercentage ?? 0
            gpn.lastSyncedAt = .now
            gpn.isDirty = false
            if localGPNProfile == nil {
                modelContext.insert(gpn)
            }
            localGPNProfile = gpn
            profile.gpnUsername = response.gpnUsername
            profile.supabaseProfileSynced = false
            gpnPasswordInput = ""
        } catch {
            gpnError = "Could not connect to GPN. Check your username and password."
        }
        isGPNSyncing = false
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
