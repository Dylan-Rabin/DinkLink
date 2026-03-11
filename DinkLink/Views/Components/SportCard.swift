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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                HStack {
                    Text("Start")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                }
                .foregroundStyle(.white)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [accent.opacity(0.95), .black.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
