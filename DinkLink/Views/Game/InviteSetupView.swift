import SwiftUI

struct InviteSetupView: View {
    let primaryPlayer: Player
    let profileID: UUID          // The logged-in user's profile ID — always the session owner
    let mode: GameMode
    let bluetoothService: MockBluetoothService
    let persistenceService: PersistenceServiceProtocol
    let authService: SupabaseAuthService
    var onSessionSaved: (() -> Void)? = nil

    @State private var opponentName = ""
    @State private var includeOpponent = true
    @State private var startSession = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(mode.rawValue)
                .dinkHeading(28, color: AppTheme.neon)

            Text(mode.subtitle)
                .dinkBody(14, color: AppTheme.ash)

            Toggle("Two-player session", isOn: $includeOpponent)
                .toggleStyle(.switch)
                .tint(AppTheme.neon)
                .dinkBody(14, color: AppTheme.smoke)

            if includeOpponent {
                TextField("Opponent name", text: $opponentName)
                    .font(.dinkBody(15))
                    .foregroundStyle(.white)
                    .tint(AppTheme.neon)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(AppTheme.steel)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Label(primaryPlayer.name, systemImage: "figure.pickleball")
                if includeOpponent {
                    Label(opponentName.isEmpty ? "Add your second player" : opponentName, systemImage: "person.2.fill")
                }
            }
            .dinkBody(14, color: AppTheme.smoke)

            Spacer()

            Button("Start Session") {
                startSession = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
            .disabled(includeOpponent && opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .background(AppTheme.ink.ignoresSafeArea())
        .navigationTitle("Session Setup")
        .dinkBackButton()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $startSession) {
            LiveGameView(
                viewModel: LiveGameViewModel(
                    mode: mode,
                    players: players,
                    bluetoothService: bluetoothService,
                    persistenceService: persistenceService,
                    authService: authService,
                    progressionPersistenceService: SupabaseProgressionPersistenceService(),
                    ownerProfileID: profileID,
                    onSessionSaved: onSessionSaved
                )
            )
        }
    }

    private var players: [Player] {
        if includeOpponent {
            return [
                primaryPlayer,
                Player(
                    name: opponentName,
                    dominantArm: .right,
                    skillLevel: primaryPlayer.skillLevel
                )
            ]
        }

        return [primaryPlayer]
    }
}
