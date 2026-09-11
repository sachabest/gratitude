import Foundation
import CloudKit
import SwiftData
import os

/// Creates and accepts `CKShare`-backed "Smile" notes (a quick thank-you/
/// kindness note sent to someone).
///
/// Unlike `CloudBackupService`, records here are stored **unencrypted** —
/// that's deliberate, not an oversight: the whole point is for the recipient
/// (a different iCloud account, without our AES key) to be able to read it.
/// Only ever put the message itself here, nothing else personal.
///
/// Delivery always goes out as a plain iMessage (see `MessageComposePresenter`)
/// with a link embedded in the text — this is the one guaranteed path, works
/// for any recipient regardless of whether they've used Gratitude before.
/// That link is **not** the raw `CKShare.url` shown directly — it's a
/// `gratitude.sachabest.com` landing page (`landingURL`) wrapping it, so
/// iMessage's own link-preview fetcher renders a branded "X sent you a
/// Smile" card instead of a plain `icloud.com` URL, and someone without the
/// app gets a real install page instead of a dead end (see the Cloudflare
/// Worker referenced by CLAUDE.md's "Smiles" section, not part of this repo).
///
/// On top of that link, `prepareShare` also tries to add the recipient as a
/// real `CKShare.Participant` via phone-number discoverability
/// (`findParticipant`); when that resolves — recipient has "Discoverable by
/// Others" on and already has Gratitude installed — CloudKit's own
/// infrastructure delivers a native "A Smile from X" push invitation with no
/// server or APNs credentials of ours involved. That's strictly additive:
/// whether someone gets there via that push, via `gratitude.sachabest.com`
/// (already installed, so it opens as a Universal Link), or via a raw
/// `icloud.com` link, everything converges on `acceptShareAndSaveSmile`
/// below, and `HomeView`'s `@Query` shows `SmileReceivedView` the moment a
/// new one lands regardless of which path it came through.
enum SmileService {
    private static let zoneName = "SmileZone"
    private static let recordType = "Smile"
    private static let container = CKContainer(identifier: "iCloud.com.sachabest.gratitude")
    /// Surfaces errors the fallback paths below otherwise swallow silently.
    private static let logger = Logger(subsystem: "com.sachabest.gratitude", category: "SmileService")

    struct PreparedShare {
        let url: URL
        let recordName: String
    }

    enum SmileError: LocalizedError {
        case missingShareURL

        var errorDescription: String? {
            "Couldn't prepare the smile link."
        }
    }

    static func prepareShare(message: String, senderName: String, recipientPhoneNumber: String? = nil) async throws -> PreparedShare {
        let db = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(zoneName: zoneName)

        // Idempotent: harmless if the zone already exists.
        _ = try? await db.save(CKRecordZone(zoneID: zoneID))

        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(zoneID: zoneID))
        record["message"] = message as CKRecordValue
        record["senderName"] = senderName as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue

        let share = CKShare(rootRecord: record)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "A Smile from \(senderName)" as CKRecordValue

        if let recipientPhoneNumber, let participant = await findParticipant(phoneNumber: recipientPhoneNumber) {
            participant.permission = .readOnly
            share.addParticipant(participant)
        }

        try await save([record, share], to: db)

        guard let url = share.url else { throw SmileError.missingShareURL }
        return PreparedShare(url: url, recordName: record.recordID.recordName)
    }

    /// Best-effort lookup of a phone number as a discoverable `CKShare`
    /// participant — succeeds only if that person has "Discoverable by
    /// Others" enabled in their iCloud settings and their Apple ID's phone
    /// number matches exactly. Fails (returns `nil`) silently and often; that
    /// silence is fine, since it just means the iMessage-link fallback in
    /// `prepareShare` is what actually reaches them.
    private static func findParticipant(phoneNumber: String) async -> CKShare.Participant? {
        let lookupInfo = CKUserIdentity.LookupInfo(phoneNumber: phoneNumber)
        return await withCheckedContinuation { continuation in
            var found: CKShare.Participant?
            let operation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
            operation.perShareParticipantResultBlock = { _, result in
                if case .success(let participant) = result {
                    found = participant
                }
            }
            operation.fetchShareParticipantsResultBlock = { result in
                if case .failure(let error) = result {
                    logger.notice("findParticipant lookup failed (expected when not discoverable): \(error as NSError, privacy: .public)")
                }
                continuation.resume(returning: found)
            }
            container.add(operation)
        }
    }

    struct PreparedMessage {
        let body: String
        let cloudRecordName: String?
    }

    private static let landingPageBaseURL = URL(string: "https://gratitude.sachabest.com/s")!

    /// Wraps a raw `CKShare.url` in our own landing page so iMessage renders
    /// a branded preview card instead of a plain `icloud.com` link, and a
    /// recipient without the app gets a real "get Gratitude" page instead of
    /// a dead end (see the Cloudflare Worker described in CLAUDE.md — it's
    /// not part of this repo). `senderName` is the only smile content that
    /// goes in the URL; the actual message text stays behind the CloudKit
    /// fetch in `acceptShare`, same as always. `URLComponents.queryItems`
    /// percent-encodes both values when building `.url` — don't also encode
    /// them yourself, or they'll be double-encoded.
    private static func landingURL(for shareURL: URL, senderName: String) -> URL {
        var components = URLComponents(url: landingPageBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "u", value: shareURL.absoluteString),
            URLQueryItem(name: "from", value: senderName),
        ]
        return components.url!
    }

    /// Prepares a `CKShare` (best-effort — falls back to a plain message with
    /// no link if CloudKit is unavailable, e.g. not signed into iCloud),
    /// returning the message body ready to hand to `MessageComposePresenter`.
    /// Deliberately does **not** touch SwiftData — call `recordSent` only
    /// once `MFMessageComposeViewController` actually reports `.sent`, so
    /// cancelling out of the compose sheet doesn't create a phantom
    /// `Smile(direction: .sent)` or (for the ad-hoc path) burn a
    /// rate-limited send that never went anywhere. Shared by the check-in
    /// flow's composer, Reflect's one-click resend, and the ad-hoc composer
    /// so none of the three drift.
    static func prepareMessage(message: String, senderName: String, recipientPhoneNumber: String? = nil) async -> PreparedMessage {
        do {
            let prepared = try await prepareShare(message: message, senderName: senderName, recipientPhoneNumber: recipientPhoneNumber)
            let link = landingURL(for: prepared.url, senderName: senderName)
            return PreparedMessage(body: message + "\n\n\(link.absoluteString)", cloudRecordName: prepared.recordName)
        } catch {
            logger.error("prepareShare failed, sending plain-text smile with no link: \(error as NSError, privacy: .public)")
            return PreparedMessage(body: message, cloudRecordName: nil)
        }
    }

    /// Records a local `Smile(direction: .sent)` — call this from a
    /// `MessageComposePresenter`'s `onFinish` callback, gated on
    /// `result == .sent`, never merely on having composed a message. See
    /// `prepareMessage` above for why the two are split.
    static func recordSent(personName: String, message: String, cloudRecordName: String?, context: ModelContext) {
        let sent = Smile(direction: .sent, personName: personName, message: message, cloudRecordName: cloudRecordName)
        context.insert(sent)
        try? context.save()
    }

    /// Reconstructs `CKShare.Metadata` from a bare share URL — needed
    /// because a `gratitude.sachabest.com` Universal Link tap (see
    /// `AppDelegate.application(_:continue:restorationHandler:)`) hands us
    /// the wrapped landing-page URL, not the raw `icloud.com` one, so iOS's
    /// automatic "recognize this as a CloudKit share" routing doesn't apply
    /// — we have to look the embedded URL up ourselves before we can accept
    /// it. Mirrors `findParticipant`'s operation-based style.
    static func fetchShareMetadata(from shareURL: URL) async -> CKShare.Metadata? {
        await withCheckedContinuation { continuation in
            var found: CKShare.Metadata?
            let operation = CKFetchShareMetadataOperation(shareURLs: [shareURL])
            operation.perShareMetadataResultBlock = { _, result in
                if case .success(let metadata) = result {
                    found = metadata
                }
            }
            operation.fetchShareMetadataResultBlock = { result in
                if case .failure(let error) = result {
                    logger.error("fetchShareMetadata failed: \(error as NSError, privacy: .public)")
                }
                continuation.resume(returning: found)
            }
            container.add(operation)
        }
    }

    /// Accepts a share and writes the resulting `Smile(direction: .received)`
    /// — the one place both convergent entry points end up (the native
    /// `userDidAcceptCloudKitShareWith` delegate callback, and the new
    /// `application(_:continue:restorationHandler:)` Universal Link handler
    /// feeding `fetchShareMetadata`'s result in here), so neither duplicates
    /// this insert/save. `hasBeenSeen: false` is what makes `HomeView`'s
    /// `@Query` pop `SmileReceivedView` for it.
    @MainActor
    static func acceptShareAndSaveSmile(metadata: CKShare.Metadata, context: ModelContext) async -> Smile? {
        guard let (senderName, message) = await acceptShare(metadata: metadata) else { return nil }
        let smile = Smile(
            direction: .received,
            personName: senderName,
            message: message,
            cloudRecordName: metadata.hierarchicalRootRecordID?.recordName,
            hasBeenSeen: false
        )
        context.insert(smile)
        try? context.save()
        return smile
    }

    /// Called from `AppDelegate` when the user taps a Smile link and
    /// already has this app installed.
    static func acceptShare(metadata: CKShare.Metadata) async -> (senderName: String, message: String)? {
        let accepted: Bool = await withCheckedContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                continuation.resume(returning: (try? result.get()) != nil)
            }
            container.add(operation)
        }
        guard accepted, let rootRecordID = metadata.hierarchicalRootRecordID else {
            logger.error("acceptShare: CKAcceptSharesOperation did not succeed (accepted=\(accepted, privacy: .public))")
            return nil
        }

        do {
            let record = try await container.sharedCloudDatabase.record(for: rootRecordID)
            let message = record["message"] as? String ?? ""
            let senderName = record["senderName"] as? String ?? "Someone"
            return (senderName, message)
        } catch {
            logger.error("acceptShare: failed to fetch shared record: \(error as NSError, privacy: .public)")
            return nil
        }
    }

    private static func save(_ records: [CKRecord], to database: CKDatabase) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }
}
