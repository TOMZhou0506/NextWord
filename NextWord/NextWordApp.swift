//
//  NextWordApp.swift
//  NextWord
//
//  Created by Tom on 15/9/2026.
//

import FirebaseCore
import SwiftUI
import UIKit

// Connect to Firebase once, as soon as the app finishes launching.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Only configure when the config file is bundled, so a missing file shows a message instead of crashing.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        return true
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
