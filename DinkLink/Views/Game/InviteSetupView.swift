import SwiftUI

struct InviteSetupView: View {
    let primaryPlayer: Player
    let mode: GameMode
    let bluetoothService: MockBluetoothService
    let persistenceService: PersistenceServiceProtocol

    @State private var opponentName = ""
    @State private var includeOpponent = true
    @State private var startSession = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(mode.rawValue)
                .font(.largeTitle.weight(.black))

            Text(mode.subtitle)
                .foregroundStyle(.secondary)

            Toggle("Two-player session", isOn: $includeOpponent)
                .toggleStyle(.switch)

            if includeOpponent {
                TextField("Opponent name", text: $opponentName)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Label(primaryPlayer.name, systemImage: "figure.pickleball")
                if includeOpponent {
                    Label(opponentName.isEmpty ? "Add your second player" : opponentName, systemImage: "person.2.fill")
                }
            }
            .font(.headline)

            Spacer()

            NavigationLink(isActive: $startSession) {
                LiveGameView(
                    viewModel: LiveGameViewModel(
                        mode: mode,
                        players: players,
                        bluetoothService: bluetoothService,
                        persistenceService: persistenceService
                    )
                )
            } label: {
                EmptyView()
            }

            Button("Start Session") {
                startSession = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(includeOpponent && opponentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .navigationTitle("Session Setup")
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
