import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.22, blue: 0.18), Color(red: 0.89, green: 0.4, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("DinkLink")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)

                Text("Smart paddle training for sharper hands, cleaner contacts, and match-ready confidence.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))

                Group {
                    switch viewModel.currentStep {
                    case .intro:
                        introStep
                    case .playerProfile:
                        profileStep
                    case .paddleSync:
                        paddleSyncStep
                    case .ready:
                        readyStep
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Spacer()
            }
            .padding(24)
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Train smarter.")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)

            Text("Set up your player profile, pair a paddle, and launch into live game modes backed by mocked sensor data.")
                .foregroundStyle(.white.opacity(0.8))

            Button("Build My Profile") {
                viewModel.advance()
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Player Profile")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            TextField("Player name", text: $viewModel.playerName)
                .textInputAutocapitalization(.words)
                .padding()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Picker("Dominant Arm", selection: $viewModel.dominantArm) {
                ForEach(DominantArm.allCases) { arm in
                    Text(arm.rawValue).tag(arm)
                }
            }
            .pickerStyle(.segmented)

            Picker("Skill Level", selection: $viewModel.skillLevel) {
                ForEach(SkillLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button("Continue to Paddle Sync") {
                viewModel.advance()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canContinueFromProfile)
        }
        .foregroundStyle(.white)
    }

    private var paddleSyncStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Paddle Sync")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(viewModel.isScanning ? "Scanning..." : "Scan") {
                    Task {
                        await viewModel.scanForPaddles()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isScanning)
            }

            if viewModel.availableDevices.isEmpty {
                Text("Scan for nearby smart paddles to connect a mock training device.")
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                ForEach(viewModel.availableDevices) { device in
                    Button {
                        viewModel.selectedDeviceID = device.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(device.name)
                                    .font(.headline)
                                Text("\(device.batteryLevel)% battery")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: viewModel.selectedDeviceID == device.id ? "checkmark.circle.fill" : "circle")
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }

                Button(viewModel.isConnecting ? "Connecting..." : "Connect Paddle") {
                    Task {
                        await viewModel.connectSelectedPaddle()
                        viewModel.advance()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedDevice == nil || viewModel.isConnecting)
            }
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("You’re Court Ready")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("\(viewModel.playerName) is paired with \(viewModel.selectedDevice?.name ?? "Mock Paddle").")
                .foregroundStyle(.white.opacity(0.8))

            Button("Launch DinkLink") {
                viewModel.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    OnboardingFlowView(
        viewModel: OnboardingViewModel(
            bluetoothService: MockBluetoothService(),
            persistenceService: PreviewPersistenceService(),
            existingProfile: nil
        )
    )
}

private struct PreviewPersistenceService: PersistenceServiceProtocol {
    func seedSampleSessionsIfNeeded() {}
    func saveProfile(name: String, dominantArm: DominantArm, skillLevel: SkillLevel, paddleName: String) {}
    func saveSession(_ draft: SessionDraft) {}
}
