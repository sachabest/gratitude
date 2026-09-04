import SwiftUI

struct TimeBudgetStepView: View {
    let period: Period
    let onSelect: (TimeBudget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("How much time do you have?")
                .font(.title2.weight(.semibold))

            VStack(spacing: 14) {
                ForEach(TimeBudget.allCases, id: \.self) { budget in
                    Button {
                        Haptic.selection()
                        onSelect(budget)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: budget.symbolName)
                                .font(.title2)
                                .foregroundStyle(period.tint)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(budget.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(budget.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }
}
