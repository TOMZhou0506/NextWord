import SwiftUI

// Lets the learner permanently delete their account from inside the app,
// as App Store guideline 5.1.1(v) requires for apps that support account creation.
struct DeleteAccountView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var password = ""
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Label("This can't be undone.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)
            } footer: {
                Text("If you only want to leave this phone for now, use Sign out instead. Your data stays saved.")
            }

            Section("What will be deleted") {
                Label("Your NextWord account (email and password)", systemImage: "person.crop.circle.badge.xmark")
                Label("Your name and learning survey answers saved online", systemImage: "icloud.slash")
                Label("Your saved words, learning history and settings on this phone", systemImage: "iphone.slash")
            }

            Section {
                SecureField("Password", text: $password)
                    .textContentType(.password)
            } header: {
                Text("Confirm your password")
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    Text("For your security, enter your password again before deleting.")
                }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    if isDeleting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Delete my account").frame(maxWidth: .infinity)
                    }
                }
                .disabled(password.isEmpty || isDeleting)
                // A second confirmation, so the account is never deleted by one accidental tap.
                .confirmationDialog("Delete your account permanently?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete permanently", role: .destructive) {
                        Task { await deleteAccount() }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Your account and all of its learning data will be removed.")
                }
            }
        }
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
    }

    // On success RootView sees that nobody is signed in and shows the sign-in screen by itself.
    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        errorMessage = nil
        do {
            try await authService.deleteAccount(password: password)
        } catch {
            errorMessage = AuthService.message(for: error)
        }
    }
}
