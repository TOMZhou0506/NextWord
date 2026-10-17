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
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Without this, iOS hides notifications that arrive while NextWord is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
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
