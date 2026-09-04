import Foundation

struct AnswerDraft {
    var selectedOption: String?
    var freeText: String = ""
    var scaleRating: Int?
    /// For `.choiceOrText` questions: whether the user chose to type instead of tapping a chip.
    var isTextMode: Bool = false

    var isAnswered: Bool {
        if selectedOption != nil { return true }
        if !freeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if scaleRating != nil { return true }
        return false
    }
}
