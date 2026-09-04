import UIKit
import CloudKit
import SwiftData

/// The only reason this app has a UIKit app delegate at all: accepting an
/// incoming `CKShare` (a tapped Smile link) is a `UIApplicationDelegate`
/// callback, not something SwiftUI's `App` protocol exposes directly.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            guard let (senderName, message) = await SmileService.acceptShare(metadata: cloudKitShareMetadata) else {
                return
            }
            await MainActor.run {
                let context = ModelContext(PersistenceController.shared)
                let smile = Smile(
                    direction: .received,
                    personName: senderName,
                    message: message,
                    cloudRecordName: cloudKitShareMetadata.hierarchicalRootRecordID?.recordName
                )
                context.insert(smile)
                try? context.save()
            }
        }
    }
}
