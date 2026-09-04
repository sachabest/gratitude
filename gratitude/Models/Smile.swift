import Foundation
import SwiftData

enum SmileDirection: String, Codable {
    case sent
    case received
}

/// A Smile — a quick thank-you/kindness note tied to another person. `sent` ones are created locally
/// the moment you compose one (before we even know if CloudKit delivery
/// worked — the message text going out via iMessage is the real payload).
/// `received` ones are written when this device accepts an incoming
/// `CKShare` (see `AppDelegate` + `SmileService`).
@Model
final class Smile {
    var id: UUID
    var direction: SmileDirection
    var personName: String
    var message: String
    var date: Date
    /// The CKRecord name in our custom CloudKit zone (sent) or the shared
    /// zone (received) — kept for debugging/dedupe, not otherwise displayed.
    var cloudRecordName: String?

    init(
        id: UUID = UUID(),
        direction: SmileDirection,
        personName: String,
        message: String,
        date: Date = .now,
        cloudRecordName: String? = nil
    ) {
        self.id = id
        self.direction = direction
        self.personName = personName
        self.message = message
        self.date = date
        self.cloudRecordName = cloudRecordName
    }
}
