import SwiftUI
import SwiftData

struct HistoryListView: View {
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]

    var body: some View {
        List {
            ForEach(checkIns) { checkIn in
                NavigationLink(value: checkIn) {
                    HStack(spacing: 12) {
                        Image(systemName: checkIn.period.symbolName)
                            .foregroundStyle(checkIn.period.tint)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(checkIn.period.title)
                                .font(.body.weight(.medium))
                            Text(checkIn.date, format: .dateTime.month(.abbreviated).day().year())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let moodRating = checkIn.moodRating {
                            Circle().fill(Mood.color(for: moodRating)).frame(width: 10, height: 10)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationDestination(for: CheckIn.self) { checkIn in
            CheckInDetailView(checkIn: checkIn)
        }
        .overlay {
            if checkIns.isEmpty {
                ContentUnavailableView(
                    "No entries yet",
                    systemImage: "book.closed",
                    description: Text("Your morning and evening check-ins will show up here.")
                )
            }
        }
    }
}
