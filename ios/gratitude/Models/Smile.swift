import Foundation
import SwiftData

enum SmileDirection: String, Codable {
    case sent
    case received
}

/// A Smile — a quick thank-you/kindness note tied to another person. `sent`
/// ones are created locally once the outgoing iMessage is actually sent
/// (`MFMessageComposeViewController`'s `.sent` result — see
/// `SmileService.recordSent`), regardless of whether the CKShare link inside
/// it worked (the message text going out via iMessage is the real payload;
/// CloudKit delivery is best-effort on top of that). `received` ones are
/// written when this device accepts an incoming `CKShare` (see
/// `AppDelegate` + `SmileService`).
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
    /// Whether `SmileReceivedView`'s hero screen has already shown this one.
    /// Defaults to `true` — only a freshly-received smile passes `false`
    /// explicitly (see `SmileService.acceptShareAndSaveSmile`), so sent
    /// smiles and any row predating this field are correctly never treated
    /// as "new."
    var hasBeenSeen: Bool = true

    init(
        id: UUID = UUID(),
        direction: SmileDirection,
        personName: String,
        message: String,
        date: Date = .now,
        cloudRecordName: String? = nil,
        hasBeenSeen: Bool = true
    ) {
        self.id = id
        self.direction = direction
        self.personName = personName
        self.message = message
        self.date = date
        self.cloudRecordName = cloudRecordName
        self.hasBeenSeen = hasBeenSeen
    }
}
