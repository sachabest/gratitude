#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Populates the local store with realistic sample data for interactive
/// testing — a real code path exercising normal SwiftData saves, not a raw
/// SQLite hack against SwiftData's internal schema (which is unstable across
/// model changes and painful to keep in sync by hand).
///
/// Never compiled into a Release build (`#if DEBUG`). Triggered by a launch
/// argument rather than running unconditionally, so a normal Debug build/run
/// from Xcode doesn't silently seed data you didn't ask for. Driven by
/// `Scripts/seed-simulator.sh` — see that file and README.md.
enum DebugSeeding {
    private static let seedFlag = "--seed-sample-data"
    private static let resetFlag = "--reset-data"

    /// Rotated across tagged sample evenings so Reflect's one-click smile
    /// resend has more than one contact to exercise.
    private static let taggedPeople: [(name: String, phoneNumber: String)] = [
        ("John Appleseed", "555-0100"),
        ("Kate Bell", "555-0101"),
        ("Priya Shah", "555-0102"),
    ]

    static func run(context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains(seedFlag) else { return }

        if arguments.contains(resetFlag) {
            wipeAllData(context: context)
        }

        seedSampleData(context: context)
    }

    private static func wipeAllData(context: ModelContext) {
        for checkIn in (try? context.fetch(FetchDescriptor<CheckIn>())) ?? [] { context.delete(checkIn) }
        for smile in (try? context.fetch(FetchDescriptor<Smile>())) ?? [] { context.delete(smile) }
        try? context.save()
    }

    private static func seedSampleData(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Past 13 days, fully filled in. Today itself is left alone so
        // auto-launch, the empty "not completed" state, etc. still behave
        // like a fresh install when you're testing those specifically.
        for offset in stride(from: 13, through: 1, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }

            let focus = QuestionBank.options(forQuestionId: "morning.focus").randomElement() ?? "Work"
            let feeling = QuestionBank.options(forQuestionId: "morning.feeling").randomElement() ?? "Calm"

            let morning = CheckIn(
                date: day,
                period: .morning,
                timeBudget: .standard,
                completedAt: day.addingTimeInterval(8 * 3600)
            )
            morning.responses = [
                QuestionResponse(
                    questionId: "morning.focus",
                    questionText: "What's your main focus today?",
                    order: 0,
                    answerKindTag: .choiceOrText,
                    selectedOption: focus
                ),
                QuestionResponse(
                    questionId: "morning.worthwhile",
                    questionText: "What would make today feel worthwhile?",
                    order: 1,
                    answerKindTag: .choiceOrText,
                    selectedOption: "Getting something done"
                ),
                QuestionResponse(
                    questionId: "morning.feeling",
                    questionText: "How do you want to feel by tonight?",
                    order: 2,
                    answerKindTag: .choiceOnly,
                    selectedOption: feeling
                ),
            ]
            context.insert(morning)

            // Cycle 1...5 across the days so calendar dots and Reflect's
            // mood-matching both have full-spectrum sample data to work with.
            let mood = ((offset - 1) % 5) + 1
            let positive = QuestionBank.options(forQuestionId: "evening.positive").randomElement() ?? "A conversation"

            let evening = CheckIn(
                date: day,
                period: .evening,
                timeBudget: .standard,
                completedAt: day.addingTimeInterval(21 * 3600),
                moodRating: mood
            )
            evening.responses = [
                QuestionResponse(
                    questionId: "evening.outcome",
                    questionText: "You focused on \(focus.lowercased()) today — how did that go?",
                    order: 0,
                    answerKindTag: .choiceOrText,
                    selectedOption: QuestionBank.options(forQuestionId: "evening.outcome").randomElement()
                ),
                QuestionResponse(
                    questionId: "evening.positive",
                    questionText: "What was one positive thing about today?",
                    order: 1,
                    answerKindTag: .choiceOrText,
                    selectedOption: positive
                ),
                QuestionResponse(
                    questionId: "evening.mood",
                    questionText: "How are you feeling right now?",
                    order: 2,
                    answerKindTag: .scale,
                    selectedOption: String(mood)
                ),
            ]
            // A photo on every 4th day, enough to exercise Reflect/detail-view
            // photo rendering without every single entry carrying one.
            if offset % 4 == 0 {
                evening.photoData = samplePhotoData(seed: offset)
            }
            // A tagged person on every 3rd day, cycling through a few names, so
            // Reflect's one-click "Send a smile" button has several distinct
            // reflections to exercise rather than just one repeated contact.
            if offset % 3 == 0 {
                let tagged = taggedPeople[(offset / 3) % taggedPeople.count]
                evening.taggedPersonName = tagged.name
                evening.taggedPersonPhoneNumber = tagged.phoneNumber
            }
            context.insert(evening)
        }

        context.insert(Smile(
            direction: .sent,
            personName: "John Appleseed",
            message: "Thank you for a quiet moment today — it meant a lot.",
            date: today.addingTimeInterval(-2 * 86400)
        ))
        context.insert(Smile(
            direction: .received,
            personName: "Kate Bell",
            message: "Thanks for always checking in on me!",
            date: today.addingTimeInterval(-5 * 86400)
        ))

        try? context.save()
    }

    /// A small solid-color placeholder JPEG — good enough to verify photo
    /// rendering without needing a real seeded Photos-library asset.
    private static func samplePhotoData(seed: Int) -> Data? {
        let size = CGSize(width: 400, height: 300)
        let hue = CGFloat(seed % 10) / 10.0
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor(hue: hue, saturation: 0.5, brightness: 0.85, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }
        return image.jpegData(compressionQuality: 0.7)
    }
}
#endif
