import SwiftUI

struct OnboardingFlowView: View {
    // @Bindable exposes writable bindings to an @Observable view model.
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: (PlayerProfile) -> Void
    @State private var showsSplash = true
    @State private var showsBlackLogo = true
    @State private var revealsSplashAnimation = false
    @State private var ballLifted = false
    @State private var paddleTilted = false
    @State private var glowExpanded = false

    var body: some View {
        ZStack {
            if showsSplash {
                Color.black
                    .ignoresSafeArea()
                    .opacity(showsBlackLogo ? 1 : 0)

                VStack {
                    Spacer()

                    Image("SplashLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .shadow(color: AppTheme.mutedGlow.opacity(0.18), radius: 18)

                    Spacer()
                }
                .padding(24)
                .opacity(showsBlackLogo ? 1 : 0)
            }

            if !showsSplash || revealsSplashAnimation {
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
                    .transition(.opacity)
            }

            Group {
                if showsSplash {
                    splashScreen
                        .opacity(revealsSplashAnimation ? 1 : 0)
                        .scaleEffect(revealsSplashAnimation ? 1 : 0.96)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    GeometryReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .center, spacing: 18) {
                                Text("Welcome to The DinkLink")
                                    .dinkHeading(28, color: AppTheme.neon)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Smart paddle training for sharper hands, cleaner contacts, and match-ready confidence.")
                                    .dinkBody(14, color: AppTheme.smoke.opacity(0.82))
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
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: 420)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: proxy.size.height, alignment: .center)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .task {
            guard showsSplash else { return }

            try? await Task.sleep(for: .seconds(0.9))
            guard !Task.isCancelled else { return }

            showsBlackLogo = false

            try? await Task.sleep(for: .seconds(0.2))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.6)) {
                revealsSplashAnimation = true
            }

            startSplashAnimations()
            try? await Task.sleep(for: .seconds(3.8))

            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.9)) {
                showsSplash = false
            }
        }
    }

    @ViewBuilder
    private func styledStepCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppTheme.steel.opacity(0.98), AppTheme.graphite.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.neon.opacity(0.2), lineWidth: 1)
            )
    }

    private var splashScreen: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(AppTheme.mutedGlow.opacity(0.55))
                    .frame(width: glowExpanded ? 260 : 210, height: glowExpanded ? 260 : 210)
                    .blur(radius: 50)

                ZStack(alignment: .bottom) {
                    ZStack {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.smoke, AppTheme.ash],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 112, height: 132)
                            .overlay(
                                Ellipse()
                                    .stroke(AppTheme.neon.opacity(0.35), lineWidth: 2)
                            )

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.smoke, AppTheme.ash],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 18, height: 84)
                            .offset(y: 82)
                    }
                    .rotationEffect(.degrees((paddleTilted ? -12 : 12) + 90), anchor: .center)
                    .offset(y: 34)

                    Circle()
                        .fill(AppTheme.neon)
                        .frame(width: 34, height: 34)
                        .shadow(color: AppTheme.neon.opacity(0.85), radius: 18)
                        .offset(y: ballLifted ? -112 : -34)
                }
            }
            .frame(height: 280)

            VStack(spacing: 12) {
                Text("DinkLink")
                    .dinkHeading(36, color: AppTheme.neon)

                Text("Dialing in your next session.")
                    .dinkBody(16, color: AppTheme.smoke.opacity(0.82))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startSplashAnimations() {
        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            ballLifted = true
        }

        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            paddleTilted = true
        }

        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            glowExpanded = true
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Train smarter.")
                    .dinkHeading(20, color: AppTheme.smoke)

                Text("Set up your player profile, pair a paddle, and launch into live game modes backed by mocked sensor data.")
                    .dinkBody(14, color: AppTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Build My Profile") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.ink)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppTheme.steel.opacity(0.92), AppTheme.graphite.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 18) {
                Text("Returning player?")
                    .dinkHeading(20, color: AppTheme.smoke)

                Text("Sign in with the email and password you used when you built your profile.")
                    .dinkBody(14, color: AppTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Email", text: $viewModel.authEmail)
                    .font(.dinkBody(14))
                    .foregroundStyle(AppTheme.ink)
                    .tint(AppTheme.ink)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(AppTheme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                SecureField("Password", text: $viewModel.authPassword)
                    .font(.dinkBody(14))
                    .foregroundStyle(AppTheme.ink)
                    .tint(AppTheme.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(AppTheme.smoke)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(viewModel.isAuthenticating ? "Signing In..." : "Sign In to My Profile") {
                    Task {
                        if let profile = await viewModel.signInReturningUser() {
                            onComplete(profile)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.neon)
                .disabled(!viewModel.canUseReturningUser)

                if let errorMessage = viewModel.authErrorMessage ?? viewModel.onboardingErrorMessage {
                    Text(errorMessage)
                        .dinkBody(12, color: AppTheme.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let statusMessage = viewModel.authStatusMessage {
                    Text(statusMessage)
                        .dinkBody(12, color: AppTheme.neon)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppTheme.graphite.opacity(0.92), AppTheme.deepShadow.opacity(0.88)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                viewModel.goBack()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))

                    Text("Back")
                        .font(.dinkBody(13))
                }
                .foregroundStyle(AppTheme.neon)
            }
            .buttonStyle(.plain)

            Text("Player Profile")
                .dinkHeading(20, color: AppTheme.smoke)

            TextField("Player name", text: $viewModel.playerName)
                .font(.dinkBody(14))
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(AppTheme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextField("City name", text: $viewModel.playerLocation)
                .font(.dinkBody(14))
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(AppTheme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Text("Email and password are optional. Add them now if you want to post and like comments after onboarding.")
              //  .dinkBody(12, color: AppTheme.ash)

            TextField("Email", text: $viewModel.authEmail)
                .font(.dinkBody(14))
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(AppTheme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            SecureField("Password", text: $viewModel.authPassword)
                .font(.dinkBody(14))
                .foregroundStyle(AppTheme.ink)
                .tint(AppTheme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(AppTheme.smoke)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if viewModel.isAuthenticated {
                Text("Signed in as \(viewModel.authenticatedEmail ?? "Authenticated player").")
                    .dinkBody(12, color: AppTheme.neon)
            }

            if let authStatusMessage = viewModel.authStatusMessage {
                Text(authStatusMessage)
                    .dinkBody(12, color: AppTheme.neon)
            }

            if let authErrorMessage = viewModel.authErrorMessage {
                Text(authErrorMessage)
                    .dinkBody(12, color: AppTheme.ash)
            }

/*            Picker("Dominant Arm", selection: $viewModel.dominantArm) {
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

 */
            Button(viewModel.isAuthenticating ? "Creating Account..." : "Continue to Paddle Sync") {
                Task {
                    await viewModel.continueFromProfile()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.neon)
            .foregroundStyle(AppTheme.ink)
            .disabled(!viewModel.canContinueFromProfile || viewModel.isAuthenticating)

            if let errorMessage = viewModel.authErrorMessage ?? viewModel.onboardingErrorMessage {
                Text(errorMessage)
                    .dinkBody(12, color: AppTheme.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .dinkBody(14, color: AppTheme.smoke)
    }

    private var paddleSyncStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Paddle Sync")
                    .dinkHeading(20, color: AppTheme.smoke)
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
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.graphite, AppTheme.steel],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            authService: SupabaseAuthService(
                storage: UserDefaults(suiteName: "OnboardingPreview") ?? .standard
            ),
            existingProfile: nil
        ),
        onComplete: { _ in }
    )
}

private struct PreviewPersistenceService: PersistenceServiceProtocol {
    func seedDylanSessions(profileID: UUID) {}
    func fetchSavedSessions() -> [StoredGameSession] { [] }
    func saveProfile(name: String, locationName: String, dominantArm: DominantArm, skillLevel: SkillLevel, paddleName: String, supabaseUserID: UUID?) throws -> PlayerProfile {
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
