import Foundation

enum Period: String, Codable, CaseIterable, Identifiable {
    case morning
    case evening

    var id: String { rawValue }
}

enum TimeBudget: String, Codable, CaseIterable {
    case quick
    case standard
    case long

    var title: String {
        switch self {
        case .quick: "Quick"
        case .standard: "Standard"
        case .long: "Long"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: "About 1 minute"
        case .standard: "2–3 minutes"
        case .long: "5+ minutes"
        }
    }

    var symbolName: String {
        switch self {
        case .quick: "bolt.fill"
        case .standard: "gauge.medium"
        case .long: "hourglass"
        }
    }
}

enum AnswerKind: Codable, Equatable {
    case choiceOnly([String])
    case choiceOrText([String])
    case textOnly
    case scale

    var isChoiceBased: Bool {
        switch self {
        case .choiceOnly, .choiceOrText: true
        case .textOnly, .scale: false
        }
    }

    var options: [String] {
        switch self {
        case .choiceOnly(let options), .choiceOrText(let options): options
        case .textOnly, .scale: []
        }
    }

    var allowsFreeText: Bool {
        switch self {
        case .choiceOrText, .textOnly: true
        case .choiceOnly, .scale: false
        }
    }

    var tag: AnswerKindTag {
        switch self {
        case .choiceOnly: .choiceOnly
        case .choiceOrText: .choiceOrText
        case .textOnly: .textOnly
        case .scale: .scale
        }
    }
}

/// A plain, no-associated-value mirror of `AnswerKind`'s cases. SwiftData's
/// `@Model` macro doesn't reliably round-trip a Codable enum that carries
/// associated values (`AnswerKind` itself) once a fetched value gets faulted
/// back in — it crashes with a runtime cast failure. `QuestionResponse` only
/// ever needs to know *which case* a question was, never its choice list, so
/// it persists this instead and `AnswerKind` stays purely an in-memory type
/// used by the live `QuestionBank`.
enum AnswerKindTag: String, Codable {
    case choiceOnly
    case choiceOrText
    case textOnly
    case scale
}
