import Foundation
import SwiftData

@Model
final class CheckIn {
    var id: UUID
    /// Calendar day this check-in belongs to, normalized to midnight local time.
    var date: Date
    var period: Period
    var timeBudget: TimeBudget
    var completedAt: Date
    var updatedAt: Date
    /// Mirrored from a `.scale` response, if this check-in collected one, for fast querying.
    var moodRating: Int?
    /// One optional photo attached while recording this check-in (downsized JPEG).
    /// Reflect mode only ever displays this — it never lets you attach one there.
    var photoData: Data?
    /// The person tagged via `SmileComposerView` when this (evening) check-in
    /// was recorded, if any — lets Reflect offer a one-click "Send a smile to
    /// {name}" for this memory without re-running the contact picker.
    var taggedPersonName: String?
    var taggedPersonPhoneNumber: String?

    @Relationship(deleteRule: .cascade)
    var responses: [QuestionResponse] = []

    init(
        id: UUID = UUID(),
        date: Date,
        period: Period,
        timeBudget: TimeBudget,
        completedAt: Date = .now,
        moodRating: Int? = nil
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.period = period
        self.timeBudget = timeBudget
        self.completedAt = completedAt
        self.updatedAt = completedAt
        self.moodRating = moodRating
    }

    var sortedResponses: [QuestionResponse] {
        responses.sorted { $0.order < $1.order }
    }

    /// The first choice-based response's selected option, used to interpolate
    /// evening prompts with what the user said their morning focus/intention was.
    func firstAnswerText(matching questionId: String) -> String? {
        responses.first { $0.questionId == questionId }?.displaySummary
    }
}
