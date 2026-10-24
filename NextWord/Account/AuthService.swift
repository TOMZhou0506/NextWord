import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

// Keeps track of who is signed in and talks to Firebase Authentication.
// Firebase Authentication stores the password; we never save it ourselves.
@MainActor
final class AuthService: ObservableObject {
    static let nameCharacterLimit = 40

    // The signed-in Firebase user, or nil when nobody is signed in.
    @Published private(set) var user: User?
    // True until Firebase has told us whether a user is already signed in.
    @Published private(set) var isCheckingAuthentication = true
    // The account's name, published separately because Firebase changes User in place,
    // which SwiftUI would not notice on its own.
    @Published private(set) var displayName = ""

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        // Firebase calls this at launch and every time the user signs in or out.
        authListener = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.displayName = user?.displayName ?? ""
                self?.isCheckingAuthentication = false
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: Self.clean(email), password: password)
    }

    func createAccount(name: String, email: String, password: String) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await auth.createUser(withEmail: Self.clean(email), password: password)

        // Save the name on the Firebase account itself.
        let change = result.user.createProfileChangeRequest()
        change.displayName = cleanName
        try await change.commitChanges()

        // Keep a public profile at users/{uid}: name and email only, never the password.
        // We don't wait for this write, so registration still finishes when offline;
        // Firestore keeps the write and sends it once the phone is back online.
        db.collection("users").document(result.user.uid).setData([
            "displayName": cleanName,
            "email": result.user.email ?? Self.clean(email),
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error { print("Could not save user profile: \(error.localizedDescription)") }
        }

        displayName = cleanName
    }

    // Change the name on the Firebase account and in the users/{uid} profile.
    func updateDisplayName(_ name: String) async throws {
        guard let user else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let change = user.createProfileChangeRequest()
        change.displayName = cleanName
        try await change.commitChanges()

        // merge: true only changes displayName and keeps the other profile fields.
        db.collection("users").document(user.uid).setData(["displayName": cleanName], merge: true) { error in
            if let error { print("Could not update user profile: \(error.localizedDescription)") }
        }

        displayName = cleanName
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: Self.clean(email))
    }

    func signOut() throws {
        try auth.signOut()
    }

    // Delete the account for good (App Store guideline 5.1.1(v)). The order matters.
    func deleteAccount(password: String) async throws {
        guard let user, let email = user.email else { return }
        let uid = user.uid

        // 1. Firebase only deletes an account that signed in recently, so confirm the password first.
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)

        // 2. Delete the cloud profile while still signed in: the security rules only let the owner delete it.
        try await db.collection("users").document(uid).delete()

        // 3. Delete the account itself. The auth listener then shows the sign-in screen and cancels reminders.
        try await user.delete()

        // 4. Remove this account's data from the phone last, so an error above never loses local data.
        AccountStore.deleteLocalData(for: uid)
    }

    private static func clean(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Turn Firebase error codes into short, friendly messages.
    static func message(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }
        switch code {
        case .invalidEmail:
            return "That email address doesn't look right."
        case .emailAlreadyInUse:
            return "An account with this email already exists. Try signing in instead."
        case .weakPassword:
            return "Please choose a stronger password with at least 8 characters."
        case .wrongPassword, .invalidCredential, .userNotFound:
            return "The email or password is incorrect."
        case .networkError:
            return "No internet connection. Please check your network and try again."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        default:
            return error.localizedDescription
        }
    }
}
