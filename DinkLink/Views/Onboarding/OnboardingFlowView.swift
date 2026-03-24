import SwiftUI

struct OnboardingFlowView: View {
    // @Bindable exposes writable bindings to an @Observable view model.
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: (PlayerProfile) -> Void

    var body: some View {
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
                .blur(radius: 100)
                .offset(x: 160, y: -260)

            VStack(alignment: .leading, spacing: 32) {
                Text("Welcome to The DinkLink")
                    .dinkHeading(34, color: AppTheme.neon)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Smart paddle training for sharper hands, cleaner contacts, and match-ready confidence.")
                    .dinkBody(18, color: AppTheme.smoke.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                switch viewModel.currentStep {
                case .intro:
                    introStep
                case .playerProfile:
                    styledStepCard {
                        profileStep
                    }
                case .paddleSync:
                    styledStepCard {
                        paddleSyncStep
                    }
                case .ready:
                    styledStepCard {
                        readyStep
                    }
                }

                if let onboardingErrorMessage = viewModel.onboardingErrorMessage {
                    Text(onboardingErrorMessage)
                        .dinkBody(12, color: AppTheme.ash)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func styledStepCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppTheme.steel.opacity(0.98), AppTheme.graphite.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.neon.opacity(0.2), lineWidth: 1)
            )
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Train smarter.")
                    .dinkHeading(24, color: AppTheme.smoke)

                Text("Set up your player profile, pair a paddle, and launch into live game modes backed by mocked sensor data.")
                    .dinkBody(16, color: AppTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Build My Profile") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.ink)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppTheme.steel.opacity(0.92), AppTheme.graphite.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 24) {
                Text("Returning player?")
                    .dinkHeading(24, color: AppTheme.smoke)

                Text("Jump in with Dylan's sample account data as a left-handed player in San Francisco using a CourtSense One paddle.")
                    .dinkBody(15, color: AppTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Sign In as Dylan") {
                    if let profile = viewModel.signInReturningUser() {
                        onComplete(profile)
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.neon)
                .disabled(!viewModel.canUseReturningUser)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppTheme.graphite.opacity(0.92), AppTheme.deepShadow.opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 22) {
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

            TextField("City or ZIP code", text: $viewModel.playerLocation)
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
            .background(
                LinearGradient(
                    colors: [AppTheme.graphite, AppTheme.steel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
        VStack(alignment: .leading, spacing: 20) {
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
                    .dinkBody(16, color: AppTheme.ash)
            } else {
                ForEach(viewModel.availableDevices) { device in
                    Button {
                        viewModel.selectedDeviceID = device.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
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
                        .background(
                            LinearGradient(
                                colors: [AppTheme.graphite, AppTheme.steel],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button(viewModel.isConnecting ? "Connecting..." : "Connect Paddle") {
                    Task {
                        await viewModel.connectSelectedPaddle()
                        if let profile = viewModel.completeOnboarding() {
                            onComplete(profile)
                        }
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
        VStack(alignment: .leading, spacing: 22) {
            Text("You’re Court Ready")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("\(viewModel.playerName) is paired with \(viewModel.selectedDevice?.name ?? "Mock Paddle").")
                .foregroundStyle(.white.opacity(0.8))

            Text("Local weather will be shown for \(viewModel.playerLocation).")
                .foregroundStyle(.white.opacity(0.8))

            Button("Launch DinkLink") {
                if let profile = viewModel.completeOnboarding() {
                    onComplete(profile)
                }
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
        ),
        onComplete: { _ in }
    )
}

private struct PreviewPersistenceService: PersistenceServiceProtocol {
    func seedSampleSessionsIfNeeded() {}
    func saveProfile(name: String, locationName: String, dominantArm: DominantArm, skillLevel: SkillLevel, paddleName: String) throws -> PlayerProfile {
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
