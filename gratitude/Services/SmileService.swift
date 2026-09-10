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
/// with the `CKShare.url` embedded in the text. If the recipient has
/// Gratitude installed and taps the link, iOS routes straight to
/// `AppDelegate.application(_:userDidAcceptCloudKitShareWith:)` — no server,
/// no push notifications, no associated domain needed; CloudKit + the
/// container entitlement handle that routing natively. If they don't have
/// the app, the message text alone still reads as a normal thank-you.
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

    static func prepareShare(message: String, senderName: String) async throws -> PreparedShare {
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

        try await save([record, share], to: db)

        guard let url = share.url else { throw SmileError.missingShareURL }
        return PreparedShare(url: url, recordName: record.recordID.recordName)
    }

    /// Prepares a `CKShare` (best-effort — falls back silently to a plain
    /// message if CloudKit is unavailable, e.g. not signed into iCloud) and
    /// records a local `Smile(direction: .sent)`, returning the message body
    /// ready to hand to `MessageComposePresenter`. Shared by the check-in
    /// flow's composer and Reflect's one-click resend so the two don't drift.
    static func composeSentSmile(personName: String, message: String, senderName: String, context: ModelContext) async -> String {
        var body = message
        do {
            let prepared = try await prepareShare(message: message, senderName: senderName)
            body += "\n\n\(prepared.url.absoluteString)"
            let sent = Smile(direction: .sent, personName: personName, message: message, cloudRecordName: prepared.recordName)
            context.insert(sent)
            try? context.save()
        } catch {
            logger.error("prepareShare failed, sending plain-text smile with no link: \(error as NSError, privacy: .public)")
            let sent = Smile(direction: .sent, personName: personName, message: message)
            context.insert(sent)
            try? context.save()
        }
        return body
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
