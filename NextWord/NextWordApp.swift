//
//  NextWordApp.swift
//  NextWord
//
//  Created by Tom on 15/9/2026.
//

import FirebaseCore
import SwiftUI
import UIKit
import UserNotifications

// NextWordApp is the entry point and shows RootView. AppDelegate is the UIKit part: at launch it
//configures Firebase, becomes the notification delegate and registers the snooze action, and it also
// handles notification taps."
// Runs once at launch: connects to Firebase and handles notifications (as in the Week 10 lab).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Only configure when the config file is bundled, so a missing file shows a message instead of crashing.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        // Become the notification delegate so the methods below are called.
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self

        // The button shown when the reminder is long-pressed (a category with one action, as in the lab).
        // No .foreground option: snoozing happens without opening the app.
        let snoozeAction = UNNotificationAction(
            identifier: NotificationConstants.snoozeActionIdentifier,
            title: "Remind me in 1 hour",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationConstants.reminderCategoryIdentifier,
            actions: [snoozeAction],
            intentIdentifiers: []
        )
        notificationCenter.setNotificationCategories([category])
        return true
    }

    // Without this, iOS hides notifications that arrive while NextWord is open.
    // .banner shows it at the top of the screen; .list also keeps it in Notification Center.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Called when the user taps the reminder or one of its buttons.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case NotificationConstants.snoozeActionIdentifier:
            // Send the same reminder again once, an hour from now.
            let request = UNNotificationRequest(
                identifier: NotificationConstants.snoozedReminderIdentifier,
                content: response.notification.request.content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: NotificationConstants.snoozeDelay, repeats: false)
            )
            try? await center.add(request)
        case UNNotificationDefaultActionIdentifier:
            // The reminder itself was tapped: open the app on the Vocabulary tab.
            NotificationRouter.shared.wantsVocabulary = true
        default:
            break
        }
    }
}

@main
// The app entry point creates the first window and shows RootView.
struct NextWordApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            // RootView opens the signed-in account's own database (see AccountStore).
            RootView()
        }
    }
}
