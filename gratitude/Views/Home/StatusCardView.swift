import SwiftUI

struct StatusCardView: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let isComplete: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isDisabled ? 0.08 : 0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isDisabled ? tint.opacity(0.4) : tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if !isDisabled {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(isComplete ? Theme.positive : Color(.tertiaryLabel))
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground).opacity(isDisabled ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityElement(children: .combine)
    }
}
