import SwiftUI

/// A month-grid calendar for jumping to a specific day, with a small dot
/// under each day colored by that evening's mood (same ramp as `MoodScaleView`).
/// Only evening check-ins carry a mood rating, so only evening days get a dot.
struct CalendarPickerView: View {
    @Binding var selectedDate: Date
    let checkIns: [CheckIn]

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    init(selectedDate: Binding<Date>, checkIns: [CheckIn]) {
        _selectedDate = selectedDate
        self.checkIns = checkIns
        _displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var moodByDate: [Date: Int] {
        Dictionary(
            checkIns.compactMap { checkIn -> (Date, Int)? in
                guard checkIn.period == .evening, let mood = checkIn.moodRating else { return nil }
                return (checkIn.date, mood)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: today, toGranularity: .month)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                monthHeader
                weekdayHeader
                monthGrid
                Spacer()
            }
            .padding(20)
            .background(Color(.systemBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                Haptic.selection()
                if let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                    displayedMonth = previous
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.headline)

            Spacer()

            Button {
                guard !isCurrentMonth else { return }
                Haptic.selection()
                if let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                    displayedMonth = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(isCurrentMonth ? Color(.tertiaryLabel) : Color.primary)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(daysInMonthGrid.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 48)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let normalized = calendar.startOfDay(for: day)
        let isFuture = normalized > today
        let isSelected = normalized == selectedDate
        let mood = moodByDate[normalized]

        return Button {
            selectedDate = normalized
            Haptic.selection()
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: normalized))")
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isFuture ? Color(.tertiaryLabel) : .primary)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Theme.evening.opacity(0.18) : Color.clear)
                    .clipShape(Circle())

                Circle()
                    .fill(mood.map { Mood.color(for: $0) } ?? Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    private var daysInMonthGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? monthInterval.end
        }
        return days
    }
}

#Preview {
    CalendarPickerView(selectedDate: .constant(.now), checkIns: [])
}
