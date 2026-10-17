import FirebaseCore
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
            } else if authService.user == nil {
                AuthenticationView()
            } else {
                ContentView()
            }
        }
        // Share one AuthService with every screen that needs the account.
        .environmentObject(authService)
    }
}
