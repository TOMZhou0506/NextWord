import FirebaseAuth
import SwiftUI
import SwiftData

struct LearningStat: View {
    let value: Int
    let title: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.blue)
            Text(value.formatted()).font(.title.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct FeatureRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }.padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @Query private var words: [SavedWord]
    @State private var confirmSignOut = false
    @State private var signOutError: String?
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 76)).foregroundStyle(.blue.gradient).accessibilityHidden(true)
                    Text(authService.displayName.isEmpty ? "Your learning space" : authService.displayName).font(.title.bold())
                    Text(authService.user?.email ?? "").font(.subheadline).foregroundStyle(.secondary)
                    Button("Sign out", role: .destructive) { confirmSignOut = true }
                        .buttonStyle(.bordered).controlSize(.large)
                    if let signOutError {
                        Text(signOutError).font(.caption).foregroundStyle(.red)
                    }
                }.frame(maxWidth: .infinity).padding(24)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
                HStack(spacing: 14) {
                    LearningStat(value: words.count, title: "Words saved", symbol: "bookmark.fill")
                    LearningStat(value: words.filter { $0.stage == .mastered }.count, title: "Mastered", symbol: "checkmark.seal.fill")
                }
                VStack(spacing: 12) {
                    NavigationLink { LearningInsightsView() } label: {
                        FeatureRow(title: "Learning insights", subtitle: "See your vocabulary progress", symbol: "chart.xyaxis.line", color: .indigo)
                    }
                    NavigationLink { EditProfileView() } label: {
                        FeatureRow(title: "Edit profile", subtitle: "Make NextWord feel like you", symbol: "person.text.rectangle", color: .blue)
                    }
                    NavigationLink { SettingsView() } label: {
                        FeatureRow(title: "Settings", subtitle: "Reading, learning and appearance", symbol: "gearshape.fill", color: .gray)
                    }
                    NavigationLink { AboutNextWordView() } label: {
                        FeatureRow(title: "About NextWord", subtitle: "A little progress, every day", symbol: "info.circle.fill", color: .teal)
                    }
                }.buttonStyle(.plain)
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(Color(.systemGroupedBackground)).navigationTitle("Profile")
            .confirmationDialog("Sign out of NextWord?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                // RootView sees that nobody is signed in and shows the sign-in screen.
                Button("Sign out", role: .destructive) {
                    do {
                        try authService.signOut()
                    } catch {
                        signOutError = AuthService.message(for: error)
                    }
                }
            }
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
