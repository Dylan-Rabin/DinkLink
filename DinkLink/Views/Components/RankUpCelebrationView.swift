import SwiftUI

struct RankUpCelebrationView: View {
    let awardResult: XPAwardResult
    let onDismiss: () -> Void

    @State private var badgeScale = 0.4
    @State private var badgeRotation = -10.0
    @State private var contentOpacity = 0.0

    var body: some View {
        ZStack {
            AppTheme.ink.opacity(0.82)
                .ignoresSafeArea()

            ConfettiBurstView()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                Text("RANK UP!")
                    .dinkHeading(30, color: AppTheme.neon)
                    .tracking(1.6)

                Image(awardResult.newRank.badgeAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(badgeScale)
                    .rotationEffect(.degrees(badgeRotation))
                    .shadow(color: AppTheme.neon.opacity(0.55), radius: 32)
                    .accessibilityLabel(awardResult.newRank.badgeTitle)

                VStack(spacing: 8) {
                    Text(awardResult.newRank.badgeTitle)
                        .dinkHeading(24, color: AppTheme.smoke)

                    Text("You reached Level \(awardResult.newLevel)")
                        .dinkBody(14, color: AppTheme.ash)

                    Text("+\(awardResult.xpGained) XP this session")
                        .dinkBody(13, color: AppTheme.neon)
                }
                .multilineTextAlignment(.center)

                Button("Keep Dinking") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.neon)
                .foregroundStyle(AppTheme.ink)
                .padding(.top, 8)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                LinearGradient(
                    colors: [AppTheme.steel.opacity(0.96), AppTheme.graphite.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(AppTheme.neon.opacity(0.35), lineWidth: 1)
            )
            .opacity(contentOpacity)
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.62)) {
                badgeScale = 1
                badgeRotation = 0
                contentOpacity = 1
            }
        }
    }
}

private struct ConfettiBurstView: View {
    private let pieces = (0..<88).map { ConfettiPiece(seed: $0) }
    @State private var isBursting = false
    @State private var isSparkling = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(
                        piece: piece,
                        isBursting: isBursting,
                        isSparkling: isSparkling,
                        center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    )
                }
            }
            .onAppear {
                isBursting = true
                isSparkling = true
            }
        }
    }
}

private enum ConfettiShape {
    case capsule
    case circle
    case rectangle
    case diamond
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let isBursting: Bool
    let isSparkling: Bool
    let center: CGPoint

    var body: some View {
        shape
            .frame(width: piece.width, height: piece.height)
            .shadow(color: piece.color.opacity(isSparkling ? 0.75 : 0.15), radius: piece.glowRadius)
            .scaleEffect(isBursting ? piece.finalScale : 0.15)
            .rotationEffect(.degrees(isBursting ? piece.finalRotation : piece.initialRotation))
            .position(
                x: center.x + (isBursting ? piece.xOffset : 0),
                y: center.y + (isBursting ? piece.yOffset : 0)
            )
            .opacity(isBursting ? 0 : 1)
            .animation(
                .interpolatingSpring(stiffness: 42, damping: 11)
                    .speed(0.42)
                    .delay(piece.delay),
                value: isBursting
            )
            .animation(
                .easeInOut(duration: 0.38).repeatCount(5, autoreverses: true).delay(piece.delay),
                value: isSparkling
            )
    }

    @ViewBuilder
    private var shape: some View {
        let fill = LinearGradient(
            colors: [piece.color, piece.color.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        switch piece.shape {
        case .capsule:
            Capsule()
                .fill(fill)
        case .circle:
            Circle()
                .fill(fill)
        case .rectangle:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(fill)
        case .diamond:
            Diamond()
                .fill(fill)
        }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let xOffset: CGFloat
    let yOffset: CGFloat
    let width: CGFloat
    let height: CGFloat
    let initialRotation: Double
    let finalRotation: Double
    let delay: Double
    let color: Color
    let shape: ConfettiShape
    let finalScale: CGFloat
    let glowRadius: CGFloat

    init(seed: Int) {
        id = seed

        let angle = Double(seed) * 0.43
        let direction = seed.isMultiple(of: 2) ? 1.0 : -1.0
        let distance = CGFloat(160 + (seed % 13) * 25)
        let horizontalDrift = CGFloat((seed % 7) * 16) * direction
        xOffset = cos(angle) * distance + horizontalDrift
        yOffset = sin(angle) * distance + CGFloat(120 + (seed % 9) * 26)
        width = CGFloat(6 + (seed % 5) * 3)
        height = seed % 4 == 0 ? width : CGFloat(14 + (seed % 6) * 5)
        initialRotation = Double(seed * 17)
        finalRotation = initialRotation + Double(360 + (seed % 11) * 52)
        delay = Double(seed % 14) * 0.018
        finalScale = CGFloat(0.78 + Double(seed % 5) * 0.13)
        glowRadius = CGFloat(4 + (seed % 4) * 3)

        switch seed % 8 {
        case 0:
            color = AppTheme.neon
        case 1:
            color = AppTheme.smoke
        case 2:
            color = AppTheme.ash
        case 3:
            color = Color(hex: 0xF6B44B)
        case 4:
            color = Color(hex: 0xFF5DA2)
        case 5:
            color = Color(hex: 0x45F0C2)
        case 6:
            color = Color(hex: 0xFFE66D)
        default:
            color = Color(hex: 0x78D8FF)
        }

        switch seed % 4 {
        case 0:
            shape = .capsule
        case 1:
            shape = .circle
        case 2:
            shape = .rectangle
        default:
            shape = .diamond
        }
    }
}

#Preview {
    RankUpCelebrationView(
        awardResult: XPAwardResult(
            xpGained: 140,
            leveledUp: true,
            oldLevel: 3,
            newLevel: 4,
            rankedUp: true,
            oldRank: .bronze,
            newRank: .silver,
            updatedProgression: ProgressionService.buildUserProgression(
                userID: UUID().uuidString,
                totalXP: 520
            ),
            breakdown: [
                XPBreakdownItem(source: "Complete session", xp: 50),
                XPBreakdownItem(source: "Every 10 hits", xp: 40),
                XPBreakdownItem(source: "Sweet spot >= 60%", xp: 15),
                XPBreakdownItem(source: "Played with a friend", xp: 25)
            ]
        ),
        onDismiss: {}
    )
}
