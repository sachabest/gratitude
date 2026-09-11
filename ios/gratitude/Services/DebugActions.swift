#if DEBUG
import Foundation
import SwiftData
import os

/// One-off, launch-argument-triggered debug actions — same mechanism as
/// `DebugSeeding` (`ProcessInfo.processInfo.arguments`, `#if DEBUG` only)
/// but for isolated diagnostics rather than sample-data seeding.
///
/// `--test-send-smile` fires a single `SmileService.prepareMessage` call
/// with throwaway data, no UI involved, so the CloudKit share-creation path
/// can be reproduced and logged (see `SmileService`'s `Logger` calls)
/// without needing to redo a real check-in just to reach the composer. Only
/// prepares the message — deliberately doesn't call `recordSent`, since
/// there's no real `MFMessageComposeViewController` send to gate it on here.
///
/// `--seed-unseen-smile` inserts a single `Smile(direction: .received,
/// hasBeenSeen: false)` directly, no CloudKit round-trip at all, so
/// `SmileReceivedView`'s hero screen (`HomeView`'s `@Query`) can be
/// exercised in Simulator without needing a second iCloud account/device.
enum DebugActions {
    private static let testSendSmileFlag = "--test-send-smile"
    private static let seedUnseenSmileFlag = "--seed-unseen-smile"
    private static let logger = Logger(subsystem: "com.sachabest.gratitude", category: "DebugActions")

    static func run(context: ModelContext) {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains(testSendSmileFlag) {
            Task {
                let prepared = await SmileService.prepareMessage(
                    message: "Test smile from --test-send-smile.",
                    senderName: UserProfile.displayName
                )
                let hasLink = prepared.body.contains("https://")
                logger.notice("test-send-smile finished, hasLink=\(hasLink, privacy: .public), body=\(prepared.body, privacy: .public)")
                // `Logger` doesn't mirror to stdout, so also `print` for CLI/`devicectl --console` diagnostics.
                print("[DebugActions] test-send-smile finished, hasLink=\(hasLink), body=\(prepared.body)")
            }
        }

        if arguments.contains(seedUnseenSmileFlag) {
            let smile = Smile(
                direction: .received,
                personName: "Kate Bell",
                message: "Thanks for always checking in on me!",
                hasBeenSeen: false
            )
            context.insert(smile)
            try? context.save()
        }
    }
}
#endif
