import Foundation
import UIKit

/// Shared UserDefaults keys, used both by `@AppStorage` in views and by
/// plain services that need to read the same values outside a View.
enum SettingsKeys {
    static let morningReminderEnabled = "morningReminderEnabled"
    static let eveningReminderEnabled = "eveningReminderEnabled"
    /// Seconds since midnight.
    static let morningReminderTime = "morningReminderTime"
    static let eveningReminderTime = "eveningReminderTime"
    static let cloudBackupEnabled = "cloudBackupEnabled"
    static let userDisplayName = "userDisplayName"
}

enum CloudBackupSettings {
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: SettingsKeys.cloudBackupEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKeys.cloudBackupEnabled) }
    }
}

/// The name attached to outgoing Smiles, so the recipient sees "From: <name>".
enum UserProfile {
    static var displayName: String {
        let stored = UserDefaults.standard.string(forKey: SettingsKeys.userDisplayName) ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UIDevice.current.name : trimmed
    }
}
