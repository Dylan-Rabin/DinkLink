import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.ink, AppTheme.graphite, AppTheme.steel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("DinkLink")
                    .dinkHeading(34, color: AppTheme.neon)

                Text("Smart paddle training for sharper hands, cleaner contacts, and match-ready confidence.")
                    .dinkBody(14, color: AppTheme.smoke.opacity(0.82))

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
                .background(AppTheme.steel.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppTheme.neon.opacity(0.2), lineWidth: 1)
                )

                Spacer()
            }
            .padding(24)
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Train smarter.")
                .dinkHeading(24, color: AppTheme.smoke)

            Text("Set up your player profile, pair a paddle, and launch into live game modes backed by mocked sensor data.")
                .dinkBody(14, color: AppTheme.ash)

            Button("Build My Profile") {
                viewModel.advance()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Player Profile")
                .dinkHeading(22, color: AppTheme.smoke)

            TextField("Player name", text: $viewModel.playerName)
                .font(.dinkBody(15))
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .textInputAutocapitalization(.words)
                .padding()
                .background(AppTheme.smoke)
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
            .background(AppTheme.graphite)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button("Continue to Paddle Sync") {
                viewModel.advance()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
            .disabled(!viewModel.canContinueFromProfile)
        }
        .dinkBody(14, color: AppTheme.smoke)
    }

    private var paddleSyncStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Paddle Sync")
                    .dinkHeading(22, color: AppTheme.smoke)
                Spacer()
                Button(viewModel.isScanning ? "Scanning..." : "Scan") {
                    Task {
                        await viewModel.scanForPaddles()
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.neon)
                .disabled(viewModel.isScanning)
            }

            if viewModel.availableDevices.isEmpty {
                Text("Scan for nearby smart paddles to connect a mock training device.")
                    .dinkBody(14, color: AppTheme.ash)
            } else {
                ForEach(viewModel.availableDevices) { device in
                    Button {
                        viewModel.selectedDeviceID = device.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(device.name)
                                    .dinkHeading(16, color: AppTheme.smoke)
                                Text("\(device.batteryLevel)% battery")
                                    .dinkBody(12, color: AppTheme.ash)
                            }
                            Spacer()
                            Image(systemName: viewModel.selectedDeviceID == device.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(AppTheme.neon)
                        }
                        .padding()
                        .background(AppTheme.graphite)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(viewModel.isConnecting ? "Connecting..." : "Connect Paddle") {
                    Task {
                        await viewModel.connectSelectedPaddle()
                        viewModel.completeOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.ink)
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
