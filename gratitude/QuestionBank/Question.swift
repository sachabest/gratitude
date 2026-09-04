import Foundation

struct Question: Identifiable, Equatable {
    /// Stable across time budgets so evening prompts can look back at a specific
    /// morning answer (e.g. "morning.focus") regardless of which budget was used.
    let id: String
    let period: Period
    let prompt: String
    let answerKind: AnswerKind

    /// Replaces `{morningFocus}` / `{morningFeeling}` placeholders with the day's
    /// morning answers, falling back to a neutral phrase if morning wasn't done.
    func resolvedPrompt(morningCheckIn: CheckIn?) -> String {
        var text = prompt
        if text.contains("{morningFocus}") {
            let focus = morningCheckIn?.firstAnswerText(matching: "morning.focus") ?? "whatever you had in mind"
            text = text.replacingOccurrences(of: "{morningFocus}", with: focus.lowercased())
        }
        if text.contains("{morningFeeling}") {
            let feeling = morningCheckIn?.firstAnswerText(matching: "morning.feeling") ?? "good"
            text = text.replacingOccurrences(of: "{morningFeeling}", with: feeling.lowercased())
        }
        return text
    }
}
