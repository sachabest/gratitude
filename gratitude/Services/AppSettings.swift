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
    /// Seconds since midnight — see `CheckInWindow`. Evening's start is
    /// normally later than its end (the window wraps past midnight, e.g.
    /// 8pm-2am); morning's isn't expected to.
    static let morningWindowStart = "morningWindowStart"
    static let morningWindowEnd = "morningWindowEnd"
    static let eveningWindowStart = "eveningWindowStart"
    static let eveningWindowEnd = "eveningWindowEnd"
    /// Cached copy of `AppConfigService`'s remote `adHocSmileWeeklyLimit`,
    /// so the ad-hoc smile flow has a value even offline/before first fetch.
    static let adHocSmileWeeklyLimit = "adHocSmileWeeklyLimit"
    static let adHocSmileCountThisWeek = "adHocSmileCountThisWeek"
    static let adHocSmileWeekStartDate = "adHocSmileWeekStartDate"
}

enum CheckInWindowDefaults {
    static let morningStart: TimeInterval = 4 * 3600
    static let morningEnd: TimeInterval = 11 * 3600
    static let eveningStart: TimeInterval = 20 * 3600
    static let eveningEnd: TimeInterval = 2 * 3600
}

enum CheckInWindowState {
    /// Before the window opens today — not "missed," just not time yet.
    case tooEarly
    case open
    /// Past the window's end, same calendar day — mirrors a completed day
    /// that's locked, not one that never had a chance to start.
    case tooLate
}

/// Pure time-of-day window logic shared by `HomeView` (to gate/label the
/// Morning and Evening cards) and `SettingsView` (to edit the boundaries).
/// Deliberately takes `start`/`end` as parameters rather than reading
/// `UserDefaults` itself, so callers can source them from `@AppStorage`
/// (which stays reactive to Settings changes) instead of this type
/// silently going stale.
enum CheckInWindow {
    /// `start > end` means the window wraps past midnight (evening's
    /// default 8pm-2am): open whenever the current time is at/after
    /// `start` OR before `end`, closed in the daytime gap between them,
    /// and never "too late" — that transition is masked by the day
    /// rolling over at midnight before it could be observed.
    static func state(start: TimeInterval, end: TimeInterval, now: Date = .now) -> CheckInWindowState {
        let secondsSinceMidnight = now.timeIntervalSince(Calendar.current.startOfDay(for: now))
        if start <= end {
            if secondsSinceMidnight < start { return .tooEarly }
            if secondsSinceMidnight < end { return .open }
            return .tooLate
        } else {
            if secondsSinceMidnight >= start || secondsSinceMidnight < end { return .open }
            return .tooEarly
        }
    }
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

/// Local, calendar-week rate limit for the ad-hoc "send a smile anytime"
/// flow (`Views/Smiles/AdHocSmileComposerView.swift`) — the smile-tag-
/// during-a-check-in path and Reflect's one-click resend are unaffected,
/// since both are already naturally bounded by real journal activity. The
/// limit itself comes from `AppConfigService` (a CloudKit public-database
/// record the developer can edit without shipping a build); this just
/// tracks this week's usage against whatever that cached limit currently
/// is. "This week" follows the user's `Calendar` (`.weekOfYear`), so it
/// resets on whatever day their locale considers the start of the week.
enum AdHocSmileLimiter {
    private static let defaultWeeklyLimit = 3

    static var cachedWeeklyLimit: Int {
        get {
            let defaults = UserDefaults.standard
            return defaults.object(forKey: SettingsKeys.adHocSmileWeeklyLimit) != nil
                ? defaults.integer(forKey: SettingsKeys.adHocSmileWeeklyLimit)
                : defaultWeeklyLimit
        }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKeys.adHocSmileWeeklyLimit) }
    }

    static var sentThisWeek: Int {
        resetIfNewWeek()
        return UserDefaults.standard.integer(forKey: SettingsKeys.adHocSmileCountThisWeek)
    }

    static var remainingThisWeek: Int {
        max(0, cachedWeeklyLimit - sentThisWeek)
    }

    static func recordSend() {
        resetIfNewWeek()
        UserDefaults.standard.set(sentThisWeek + 1, forKey: SettingsKeys.adHocSmileCountThisWeek)
    }

    private static func resetIfNewWeek() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let lastWeekStart = defaults.object(forKey: SettingsKeys.adHocSmileWeekStartDate) as? Date ?? .distantPast
        guard lastWeekStart != thisWeekStart else { return }
        defaults.set(0, forKey: SettingsKeys.adHocSmileCountThisWeek)
        defaults.set(thisWeekStart, forKey: SettingsKeys.adHocSmileWeekStartDate)
    }
}
