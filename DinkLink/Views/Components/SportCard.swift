import SwiftUI

struct SportCard: View {
    let title: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .dinkHeading(18, color: AppTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .dinkBody(12, color: AppTheme.graphite.opacity(0.88))

                Spacer()

                HStack {
                    Text("Start")
                        .dinkBody(12, color: AppTheme.ink)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [accent, AppTheme.smoke],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
