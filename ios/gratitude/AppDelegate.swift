import UIKit
import CloudKit
import SwiftData
import os

/// Three reasons this app has a UIKit app delegate at all: accepting an
/// incoming `CKShare` (a native CloudKit share invitation push, or a tapped
/// raw `icloud.com` link) is a `UIApplicationDelegate` callback, not
/// something SwiftUI's `App` protocol exposes directly; registering for
/// remote notifications needs `UIApplication.registerForRemoteNotifications()`;
/// and handling a tapped `gratitude.sachabest.com` Universal Link needs
/// `application(_:continue:restorationHandler:)`.
///
/// The Push Notifications capability exists **only** so CloudKit itself can
/// deliver a native "A Smile from X" invitation push when `SmileService`
/// manages to add the recipient as a real `CKShare.Participant` (see
/// `SmileService.findParticipant`) — that delivery is entirely Apple's own
/// infrastructure once a device is registered; this app never sees a device
/// token, holds no APNs credentials, and runs no server of its own. If that
/// participant lookup fails (recipient not discoverable, or doesn't have the
/// app yet), the plain-link-in-an-iMessage path is still what actually
/// carries the message — this capability is additive, not a replacement.
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static let logger = Logger(subsystem: "com.sachabest.gratitude", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.logger.notice("Registered for remote notifications")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.logger.error("Failed to register for remote notifications: \(error as NSError, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            let context = ModelContext(PersistenceController.shared)
            _ = await SmileService.acceptShareAndSaveSmile(metadata: cloudKitShareMetadata, context: context)
        }
    }

    /// Handles a tap on a `gratitude.sachabest.com/s?u=<shareURL>&from=<name>`
    /// link when the app is already installed (Universal Link routing, via
    /// the Associated Domains entitlement + that domain's
    /// `apple-app-site-association` file — see CLAUDE.md's "Smiles"
    /// section). Unlike a raw `icloud.com` link, iOS doesn't recognize this
    /// URL as a CloudKit share on its own, so we pull the wrapped `u` query
    /// item back out and look the share up ourselves before accepting it —
    /// everything after that converges on the same
    /// `acceptShareAndSaveSmile` the native path above uses.
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let webpageURL = userActivity.webpageURL,
              webpageURL.path == "/s",
              let components = URLComponents(url: webpageURL, resolvingAgainstBaseURL: false),
              let shareURLString = components.queryItems?.first(where: { $0.name == "u" })?.value,
              let shareURL = URL(string: shareURLString)
        else { return false }

        Task {
            guard let metadata = await SmileService.fetchShareMetadata(from: shareURL) else { return }
            let context = ModelContext(PersistenceController.shared)
            _ = await SmileService.acceptShareAndSaveSmile(metadata: metadata, context: context)
        }
        return true
    }
}
