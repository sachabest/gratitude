//
//  gratitudeApp.swift
//  gratitude
//
//  Created by Sacha Best on 9/3/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct gratitudeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        #if DEBUG
        DebugSeeding.run(context: ModelContext(PersistenceController.shared))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(PersistenceController.shared)
    }
}
