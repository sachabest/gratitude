import SwiftUI

/// A question prompt + its answer, rendering a `.scale` answer as a colored
/// mood dot + label instead of the raw stored number. Shared by
/// `CheckInDetailView` and `HighlightedMemoryView` so the two don't drift.
struct QuestionResponseRow: View {
    let response: QuestionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(response.questionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if response.answerKindTag == .scale, let rating = Int(response.selectedOption ?? "") {
                HStack(spacing: 8) {
                    Circle().fill(Mood.color(for: rating)).frame(width: 12, height: 12)
                    Text(Mood.labels[rating - 1])
                        .font(.body.weight(.medium))
                }
            } else {
                Text(response.displaySummary)
                    .font(.body.weight(.medium))
            }
        }
    }
}
