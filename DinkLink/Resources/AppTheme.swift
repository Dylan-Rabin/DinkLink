import SwiftUI

enum AppTheme {
    static let neon = Color(hex: 0xD6F51D)
    static let ink = Color(hex: 0x090909)
    static let graphite = Color(hex: 0x161616)
    static let steel = Color(hex: 0x2A2A2A)
    static let ash = Color(hex: 0xB7B7B7)
    static let smoke = Color(hex: 0xE7E7E7)
    static let deepShadow = Color(hex: 0x050505)
    static let mutedGlow = Color(hex: 0xD6F51D, opacity: 0.28)
}

extension Font {
    static func dinkHeading(_ size: CGFloat) -> Font {
        .custom("DelaGothicOne-Regular", size: size, relativeTo: .title)
    }

    static func dinkBody(_ size: CGFloat) -> Font {
        .custom("RobotoMono-Regular", size: size, relativeTo: .body)
    }
}

extension View {
    func dinkHeading(_ size: CGFloat, color: Color = AppTheme.smoke) -> some View {
        font(.dinkHeading(size))
            .foregroundStyle(color)
    }

    func dinkBody(_ size: CGFloat = 15, color: Color = AppTheme.smoke) -> some View {
        font(.dinkBody(size))
            .foregroundStyle(color)
    }

    func appScreenGradient() -> some View {
        background(
            LinearGradient(
                colors: [AppTheme.deepShadow, AppTheme.graphite, AppTheme.steel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    func dinkBackButton() -> some View {
        modifier(DinkBackButtonModifier())
    }
}

private struct DinkBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                           // Text("Back")
                            //    .font(.dinkBody(13))
                        }
                        .foregroundStyle(AppTheme.neon)
                    }
                    .buttonStyle(.plain)
                }
            }
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
