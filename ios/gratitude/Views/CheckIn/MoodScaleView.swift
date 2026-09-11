import SwiftUI

struct MoodScaleView: View {
    @Binding var rating: Int?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(1...5, id: \.self) { value in
                let isSelected = rating == value
                Button {
                    Haptic.selection()
                    rating = value
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(isSelected ? Mood.color(for: value) : Color(.secondarySystemBackground))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle().strokeBorder(Mood.color(for: value), lineWidth: isSelected ? 0 : 2)
                            )
                        Text(Mood.labels[value - 1])
                            .font(.caption)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Mood.labels[value - 1])
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
