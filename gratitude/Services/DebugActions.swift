#if DEBUG
import Foundation
import SwiftData
import os

/// One-off, launch-argument-triggered debug actions — same mechanism as
/// `DebugSeeding` (`ProcessInfo.processInfo.arguments`, `#if DEBUG` only)
/// but for isolated diagnostics rather than sample-data seeding.
///
/// `--test-send-smile` fires a single `SmileService.composeSentSmile` call
/// with throwaway data, no UI involved, so the CloudKit share-creation path
/// can be reproduced and logged (see `SmileService`'s `Logger` calls)
/// without needing to redo a real check-in just to reach the composer.
enum DebugActions {
    private static let testSendSmileFlag = "--test-send-smile"
    private static let logger = Logger(subsystem: "com.sachabest.gratitude", category: "DebugActions")

    static func run(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains(testSendSmileFlag) else { return }
        Task {
            let body = await SmileService.composeSentSmile(
                personName: "Debug Test",
                message: "Test smile from --test-send-smile.",
                senderName: UserProfile.displayName,
                context: context
            )
            let hasLink = body.contains("https://")
            logger.notice("test-send-smile finished, hasLink=\(hasLink, privacy: .public), body=\(body, privacy: .public)")
            // `Logger` doesn't mirror to stdout, so also `print` for CLI/`devicectl --console` diagnostics.
            print("[DebugActions] test-send-smile finished, hasLink=\(hasLink), body=\(body)")
        }
    }
}
#endif
