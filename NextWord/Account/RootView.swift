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

    var body: some View {
        Group {
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
        // Share one AuthService with every screen that needs the account.
        .environmentObject(authService)
    }
}

// Opens the signed-in account's own database and settings, and gives them to every tab.
private struct AccountScopedView: View {
    let uid: String
    @State private var container: ModelContainer?
    @State private var preferences: UserDefaults?
    @State private var errorMessage: String?
    @State private var showSurvey = false

    var body: some View {
        Group {
            if let container, let preferences {
                ContentView()
                    // New learners meet the survey first; it covers the whole screen.
                    .fullScreenCover(isPresented: $showSurvey) {
                        NavigationStack { LearningPreferencesIntroView() }
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
            // "Later" sets the skipped flag; the survey can still be retaken from Settings.
            showSurvey = !accountPreferences.bool(forKey: "learningQuestionnaireCompleted_v1")
                && !accountPreferences.bool(forKey: "learningQuestionnaireSkipped_v1")
        }
    }
}
