import Foundation
import UserNotifications

enum NotificationScheduler {
    static let morningIdentifier = "morning-reminder"
    static let eveningIdentifier = "evening-reminder"

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func scheduleMorningReminder(at time: DateComponents) {
        schedule(
            identifier: morningIdentifier,
            title: "Good morning",
            body: "A minute to set your intention for today.",
            time: time
        )
    }

    static func scheduleEveningReminder(at time: DateComponents) {
        schedule(
            identifier: eveningIdentifier,
            title: "Before you sleep",
            body: "Take a moment to reflect on your day.",
            time: time
        )
    }

    static func cancelMorningReminder() {
        cancel(identifier: morningIdentifier)
    }

    static func cancelEveningReminder() {
        cancel(identifier: eveningIdentifier)
    }

    private static func schedule(identifier: String, title: String, body: String, time: DateComponents) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute

        let calendarTrigger = UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: calendarTrigger)
        center.add(request)
    }

    private static func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
