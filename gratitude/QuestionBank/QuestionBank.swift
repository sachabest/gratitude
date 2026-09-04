import Foundation

/// Loads the question set from the bundled `questions.json` (see
/// `Resources/questions.json`) rather than hardcoding it in Swift — the
/// content can be edited without recompiling, and this is the seam a future
/// remote-config/service-backed question set would slot into (see the DTOs
/// below): swap `loadBundledQuestions()` for a network fetch with the same
/// decoded shape, cached locally, and nothing above `QuestionBank` needs to
/// change.
enum QuestionBank {
    private static let bank: QuestionBankDTO = loadBundledQuestions()

    static func questions(for period: Period, budget: TimeBudget) -> [Question] {
        let periodQuestions = period == .morning ? bank.morning : bank.evening
        let dtos: [QuestionDTO]
        switch budget {
        case .quick: dtos = periodQuestions.quick
        case .standard: dtos = periodQuestions.standard
        case .long: dtos = periodQuestions.long
        }
        return dtos.map { $0.toQuestion(period: period) }
    }

    /// The configured choice options for a given question id, if any — used
    /// by `DebugSeeding` to generate plausible sample answers without
    /// duplicating the option lists.
    static func options(forQuestionId id: String) -> [String] {
        let all = TimeBudget.allCases.flatMap { budget in
            questions(for: .morning, budget: budget) + questions(for: .evening, budget: budget)
        }
        return all.first { $0.id == id }?.answerKind.options ?? []
    }

    private static func loadBundledQuestions() -> QuestionBankDTO {
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            fatalError("Missing questions.json in app bundle")
        }
        do {
            return try JSONDecoder().decode(QuestionBankDTO.self, from: data)
        } catch {
            fatalError("Invalid questions.json: \(error)")
        }
    }
}

// MARK: - Decoding

private struct QuestionBankDTO: Decodable {
    let morning: PeriodQuestionsDTO
    let evening: PeriodQuestionsDTO
}

private struct PeriodQuestionsDTO: Decodable {
    let quick: [QuestionDTO]
    let standard: [QuestionDTO]
    let long: [QuestionDTO]
}

private struct QuestionDTO: Decodable {
    let id: String
    let prompt: String
    let answerKind: AnswerKindTag
    let options: [String]?

    func toQuestion(period: Period) -> Question {
        let kind: AnswerKind
        switch answerKind {
        case .choiceOnly: kind = .choiceOnly(options ?? [])
        case .choiceOrText: kind = .choiceOrText(options ?? [])
        case .textOnly: kind = .textOnly
        case .scale: kind = .scale
        }
        return Question(id: id, period: period, prompt: prompt, answerKind: kind)
    }
}
