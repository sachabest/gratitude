import SwiftUI
import UIKit

enum Theme {
    static let morning = Color("MorningTint")
    static let evening = Color("EveningTint")
    static let reflect = Color("ReflectTint")
    static let positive = Color("PositiveTint")
    static let smile = Color("SmileTint")

    static let cardCornerRadius: CGFloat = 20
}

extension Period {
    var tint: Color {
        switch self {
        case .morning: Theme.morning
        case .evening: Theme.evening
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .evening: "moon.stars.fill"
        }
    }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .evening: "Evening"
        }
    }
}

enum Mood {
    static let labels = ["Rough", "Low", "Okay", "Good", "Great"]

    static func color(for rating: Int) -> Color {
        switch rating {
        case 1: .red
        case 2: .orange
        case 3: .yellow
        case 4: Theme.positive
        default: .mint
        }
    }
}

enum Haptic {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
