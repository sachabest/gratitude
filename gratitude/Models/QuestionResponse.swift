import Foundation
import SwiftData

@Model
final class QuestionResponse {
    var id: UUID
    var questionId: String
    var questionText: String
    var order: Int
    var answerKindTag: AnswerKindTag
    var selectedOption: String?
    var freeText: String?

    @Relationship(inverse: \CheckIn.responses)
    var checkIn: CheckIn?

    init(
        id: UUID = UUID(),
        questionId: String,
        questionText: String,
        order: Int,
        answerKindTag: AnswerKindTag,
        selectedOption: String? = nil,
        freeText: String? = nil
    ) {
        self.id = id
        self.questionId = questionId
        self.questionText = questionText
        self.order = order
        self.answerKindTag = answerKindTag
        self.selectedOption = selectedOption
        self.freeText = freeText
    }

    /// A short human-readable answer, for previews and summaries.
    var displaySummary: String {
        if let selectedOption, !selectedOption.isEmpty {
            return selectedOption
        }
        if let freeText, !freeText.isEmpty {
            return freeText
        }
        return "—"
    }
}
