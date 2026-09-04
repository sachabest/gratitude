import SwiftUI

/// A single day's memory, spotlighted front-and-center rather than presented
/// as just another row in a list — this is the whole point of Reflect: one
/// day, given real weight, with morning and evening shown together so it
/// reads as a whole day, not an isolated snippet.
struct HighlightedMemoryView: View {
    let memory: HighlightedMemory

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(memory.date, format: .dateTime.weekday(.wide))
                    .font(.title2.weight(.bold))
                Text(memory.date, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            if let photo = memory.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
                    .clipped()
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
            }

            VStack(alignment: .leading, spacing: 16) {
                if let morning = memory.morning {
                    periodSection(period: .morning, checkIn: morning)
                }

                if let evening = memory.evening {
                    periodSection(period: .evening, checkIn: evening)
                }
            }
        }
    }

    private func periodSection(period: Period, checkIn: CheckIn) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(period.title, systemImage: period.symbolName)
                .font(.headline)
                .foregroundStyle(period.tint)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(checkIn.sortedResponses) { response in
                    QuestionResponseRow(response: response)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}
