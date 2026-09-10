import Foundation
import CloudKit
import os

/// Minimal CloudKit-backed remote config: a single well-known record in the
/// container's **public** database, editable directly in CloudKit Console's
/// Public Data tab without shipping a new build. Currently two fields — the
/// ad-hoc smile weekly limit (`AdHocSmileLimiter.cachedWeeklyLimit`) and an
/// app-install link for smiles that fell back to plain text
/// (`SmileInstallLink.cachedURL`) — add more fields to the same record if
/// more knobs are needed later rather than inventing a second mechanism.
///
/// Public database reads don't require the user to be signed into iCloud
/// (unlike everything else in `SmileService`/`CloudBackupService`, which use
/// the private database), so this works even before/without iCloud sign-in.
///
/// The record must exist in **both** CloudKit environments to matter in
/// both places — same Development/Production split documented on
/// `SmileService`. Create it via Console → Public Data → New Record
/// (record type `AppConfig`, record name `AppConfig-main`, an
/// `adHocSmileWeeklyLimit` Int64 field and/or an `installLinkURL` String
/// field), then deploy schema to Production. Until that record exists (or a
/// fetch fails), callers keep whatever was last cached, or each field's own
/// built-in default/absence.
enum AppConfigService {
    private static let container = CKContainer(identifier: "iCloud.com.sachabest.gratitude")
    private static let recordName = "AppConfig-main"
    private static let logger = Logger(subsystem: "com.sachabest.gratitude", category: "AppConfigService")

    static func refresh() async {
        let recordID = CKRecord.ID(recordName: recordName)
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            if let limit = record["adHocSmileWeeklyLimit"] as? Int {
                AdHocSmileLimiter.cachedWeeklyLimit = limit
            }
            if let installLink = record["installLinkURL"] as? String {
                SmileInstallLink.cachedURL = installLink
            }
        } catch {
            logger.error("AppConfig refresh failed, keeping cached/default values: \(error as NSError, privacy: .public)")
        }
    }
}
