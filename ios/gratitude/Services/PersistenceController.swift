import Foundation
import SwiftData

/// The single `ModelContainer` instance, shared between the SwiftUI `App`
/// (via `.modelContainer`) and `AppDelegate` (which needs its own
/// `ModelContext` to write incoming `Smile`s from outside the view tree).
enum PersistenceController {
    static let shared: ModelContainer = {
        let schema = Schema([
            CheckIn.self,
            QuestionResponse.self,
            Smile.self,
        ])
        // See gratitudeApp.swift / CLAUDE.md for why `cloudKitDatabase` is `.none`.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
