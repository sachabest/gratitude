import SwiftUI

struct ChipSelectorView: View {
    let options: [String]
    let tint: Color
    @Binding var selection: String?

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    Haptic.selection()
                    selection = option
                } label: {
                    Text(option)
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isSelected ? tint : Color(.secondarySystemBackground))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
