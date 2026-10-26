import FirebaseAuth
import FirebaseCore
import SwiftData
import SwiftUI

// Decide what to show first: a setup problem, the sign-in screen, or the app itself.
struct RootView: View {
    var body: some View {
        if FirebaseApp.app() != nil {
            AuthenticatedRootView()
        } else {
            ContentUnavailableView(
                "Firebase is not set up",
                systemImage: "exclamationmark.icloud",
                description: Text("Add GoogleService-Info.plist to the project and run the app again.")
            )
        }
    }
}

// Created only after Firebase is configured, so AuthService can safely use Firebase.
private struct AuthenticatedRootView: View {
    @StateObject private var authService = AuthService()
    @State private var notificationManager = NotificationManager()

    var body: some View {
        // A ZStack, not a Group: a Group copies its modifiers onto each child, so the
        // .onChange below would be thrown away with the old screen and miss the sign-out.
        // A ZStack is one real container that stays alive while its content changes.
        ZStack {
            if authService.isCheckingAuthentication {
                ProgressView()
            } else if let user = authService.user {
                // .id makes SwiftUI build a fresh view (and database) whenever the account changes.
                AccountScopedView(uid: user.uid)
                    .id(user.uid)
            } else {
                AuthenticationView()
            }
        }
        // Share one AuthService and one NotificationManager with every screen.
        .environmentObject(authService)
        .environment(notificationManager)
        // Notifications belong to the whole phone, not one account, so a signed-out
        // phone must not keep reminding the previous user.
        .onChange(of: authService.user?.uid) { _, uid in
            if uid == nil { notificationManager.cancelDailyReminder() }
        }
    }
}

// Opens the signed-in account's own database and settings, and gives them to every tab.
private struct AccountScopedView: View {
    let uid: String
    @Environment(NotificationManager.self) private var notificationManager
    @State private var container: ModelContainer?
    @State private var preferences: UserDefaults?
    @State private var errorMessage: String?
    @State private var showSurvey = false

    var body: some View {
        // ZStack for the same reason as above: .task must run once, not once per child screen.
        ZStack {
            if let container, let preferences {
                ContentView()
                    // New learners meet the survey first; it covers the whole screen.
                    .fullScreenCover(isPresented: $showSurvey) {
                        NavigationStack { LearningPreferencesIntroView(isRequired: true) }
                    }
                    .modelContainer(container)
                    // Every @AppStorage below now reads and writes this account's settings.
                    .defaultAppStorage(preferences)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Could not open your data",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task {
            do {
                container = try AccountStore.container(for: uid)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            let accountPreferences = AccountStore.preferences(for: uid)
            preferences = accountPreferences
            // On a new phone, bring back the survey answers saved in Firestore.
            // @AppStorage notices the new values and the screens update by themselves.
            await PreferencesSync.restoreIfNeeded(uid: uid, into: accountPreferences)

            // Decide only after restoring, so a returning user on a new phone isn't asked again.
            // The survey is required until it has a valid 1–5 level.
            showSurvey = !PreferencesSync.hasCompletedSurvey(accountPreferences)

            await restoreReminder(from: accountPreferences)
        }
    }

    // Put back this account's own reminder (or none) after signing in or switching accounts.
    private func restoreReminder(from preferences: UserDefaults) async {
        guard preferences.bool(forKey: "reminderEnabled_v1") else {
            notificationManager.cancelDailyReminder()
            return
        }
        // On a new phone the reminder may be on from Firestore while this phone hasn't been asked yet.
        await notificationManager.refresh()
        if notificationManager.authorizationStatus == .notDetermined {
            await notificationManager.requestAuthorization()
        }
        let minutes = preferences.object(forKey: "reminderMinutes_v1") as? Int ?? 19 * 60
        await notificationManager.scheduleDailyReminder(hour: minutes / 60, minute: minutes % 60)
    }
}
