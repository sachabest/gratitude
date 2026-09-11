import Foundation
import SwiftData
import UIKit

/// One day's worth of context to revisit — morning and evening together,
/// whichever of the two exist for that date.
struct HighlightedMemory: Identifiable {
    var id: Date { date }
    let date: Date
    let morning: CheckIn?
    let evening: CheckIn?
    let photo: UIImage?
}

/// Picks a past day to resurface in Reflect — a random pick (not a mood
/// match; Reflect doesn't ask how you're feeling), preferring days where
/// both morning and evening were completed since those give the fullest
/// picture. No ML, no network, everything stays on-device.
enum MemoryEngine {
    static func highlightedMemory(in context: ModelContext, excluding excludedDates: Set<Date> = []) -> HighlightedMemory? {
        let descriptor = FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let allCheckIns = try? context.fetch(descriptor) else { return nil }

        let today = Calendar.current.startOfDay(for: .now)
        let pastCheckIns = allCheckIns.filter { $0.date != today }
        let byDate = Dictionary(grouping: pastCheckIns, by: \.date)

        let completeDates = byDate.keys.filter { date in
            let dayCheckIns = byDate[date] ?? []
            return dayCheckIns.contains { $0.period == .morning } && dayCheckIns.contains { $0.period == .evening }
        }

        // Prefer a fully complete day; fall back to any day with at least
        // one period if that's all there is. Exclude dates already shown
        // this session so "show me another" doesn't repeat until you've
        // actually seen everything available.
        let preferredPool = !completeDates.isEmpty ? Array(completeDates) : Array(byDate.keys)
        let unseenPool = preferredPool.filter { !excludedDates.contains($0) }
        let pool = !unseenPool.isEmpty ? unseenPool : preferredPool

        guard let chosenDate = pool.randomElement() else { return nil }
        let dayCheckIns = byDate[chosenDate] ?? []
        let morning = dayCheckIns.first { $0.period == .morning }
        let evening = dayCheckIns.first { $0.period == .evening }

        let photoData = evening?.photoData ?? morning?.photoData
        let photo = photoData.flatMap { UIImage(data: $0) }

        return HighlightedMemory(date: chosenDate, morning: morning, evening: evening, photo: photo)
    }
}
