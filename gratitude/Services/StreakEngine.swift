import Foundation

/// A day counts toward the streak only once both morning and evening are done.
enum StreakEngine {
    static func isDayComplete(_ date: Date, checkIns: [CheckIn]) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        var hasMorning = false
        var hasEvening = false
        for checkIn in checkIns where checkIn.date == day {
            if checkIn.period == .morning { hasMorning = true }
            if checkIn.period == .evening { hasEvening = true }
            if hasMorning && hasEvening { break }
        }
        return hasMorning && hasEvening
    }

    /// Today doesn't break an in-progress streak — it just doesn't count until it's
    /// complete, so the count walks backward from yesterday until today catches up.
    static func currentStreak(checkIns: [CheckIn], today: Date = .now) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)

        var cursor = todayStart
        if !isDayComplete(todayStart, checkIns: checkIns) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while isDayComplete(cursor, checkIns: checkIns) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
