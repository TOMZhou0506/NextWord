import FirebaseAuth
import SwiftUI

// Profile is about "you": your account, your learning, your reminders.
// It's a grouped list (like iOS Settings), so the shared reminder section fits right in.
// App options live in Settings; each feature has only one entry point.
struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var confirmSignOut = false
    @State private var signOutError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        List {
            Section {
                NavigationLink { EditProfileView() } label: { AccountRow() }
                    .accessibilityHint("Edit your name")
            }

            Section("Learning") {
                NavigationLink { LearningPreferencesIntroView() } label: {
                    Label("Retake learning survey", systemImage: "slider.horizontal.3")
                }
                NavigationLink { LearningInsightsView() } label: {
                    Label("Learning insights", systemImage: "chart.xyaxis.line")
                }
            }

            // Moved here from Settings: the same section, reused as it is.
            StudyReminderSection()

            Section {
                NavigationLink { SettingsView() } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            // Sign out sits at the bottom, as in most apps, so it isn't tapped by accident.
            Section {
                Button("Sign out", role: .destructive) { confirmSignOut = true }
                    .frame(maxWidth: .infinity)
                    // iOS shows a confirmation dialog from the view it's attached to. Attaching it
                    // to this bottom button (not the whole list) makes it rise from the bottom.
                    .confirmationDialog("Sign out of NextWord?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                        // RootView sees that nobody is signed in and shows the sign-in screen.
                        Button("Sign out", role: .destructive) {
                            do {
                                try authService.signOut()
                            } catch {
                                signOutError = AuthService.message(for: error)
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("Your words stay saved on this phone for when you sign in again.")
                    }
                if let signOutError {
                    Text(signOutError).font(.caption).foregroundStyle(.red)
                }
                NavigationLink { DeleteAccountView() } label: {
                    Text("Delete account").foregroundStyle(.red)
                }
            } footer: {
                Text("NextWord \(version)").frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Profile")
    }
}

// One compact row for the account: initial, name, email and when the account was made.
private struct AccountRow: View {
    @EnvironmentObject private var authService: AuthService

    private var initial: String {
        let source = authService.displayName.isEmpty ? (authService.user?.email ?? "?") : authService.displayName
        return String(source.prefix(1)).uppercased()
    }

    // Firebase records when the account was created.
    private var memberSince: String? {
        guard let date = authService.user?.metadata.creationDate else { return nil }
        return "Learning since \(date.formatted(.dateTime.month(.abbreviated).year()))"
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(initial)
                .font(.title2.bold())
                .foregroundStyle(.blue)
                .frame(width: 54, height: 54)
                .background(Color.blue.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(authService.displayName.isEmpty ? "Add your name" : authService.displayName)
                    .font(.headline)
                Text(authService.user?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let memberSince {
                    Text(memberSince).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Display name") {
                TextField("Your name", text: $name).textContentType(.nickname).textInputAutocapitalization(.words)
            }
            Section {
                Text("Your name is saved to your NextWord account and appears on your home screen.").foregroundStyle(.secondary)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
            .onAppear { name = authService.displayName }
            .toolbar {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .disabled(cleanName.isEmpty || cleanName.count > AuthService.nameCharacterLimit || cleanName == authService.displayName)
                }
            }
    }

    // Close the page only after Firebase has accepted the new name.
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await authService.updateDisplayName(cleanName)
            dismiss()
        } catch {
            errorMessage = AuthService.message(for: error)
        }
    }
}
