import FirebaseAuth
import SwiftUI

// Profile is about "you": who you are and what kind of learner you are.
// App options live in Settings; each feature has only one entry point.
struct ProfileView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var confirmSignOut = false
    @State private var signOutError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AccountRow()
                LearningProfileCard()

                VStack(spacing: 0) {
                    NavigationLink { LearningInsightsView() } label: {
                        ProfileLinkRow(title: "Learning insights", symbol: "chart.xyaxis.line")
                    }
                    Divider().padding(.leading, 52)
                    NavigationLink { SettingsView() } label: {
                        ProfileLinkRow(title: "Settings", symbol: "gearshape")
                    }
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                // Sign out sits at the bottom, as in most apps, so it isn't tapped by accident.
                Button(role: .destructive) { confirmSignOut = true } label: {
                    Text("Sign out")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.top, 12)
                if let signOutError {
                    Text(signOutError).font(.caption).foregroundStyle(.red)
                }
                Text("NextWord \(version)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
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

// One compact row for the account. Tapping it edits the name (like Apple ID in iOS Settings).
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
        NavigationLink { EditProfileView() } label: {
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
                        .foregroundStyle(.primary)
                    Text(authService.user?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let memberSince {
                        Text(memberSince).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Edit your name")
    }
}

// The learning survey's answers in plain words. "Edit" retakes the survey.
private struct LearningProfileCard: View {
    @AppStorage("learningQuestionnaireCompleted_v1") private var hasPreferences = false
    @AppStorage("englishLevel_v2") private var level = 0
    @AppStorage("learningGoals_v1") private var goals = ""
    @AppStorage("videoInterests_v1") private var interests = ""
    @AppStorage("dailyMinutes_v1") private var dailyMinutes = 15
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @AppStorage("reminderEnabled_v1") private var reminderEnabled = false
    @AppStorage("reminderMinutes_v1") private var reminderMinutes = 19 * 60

    private var reminderText: String {
        guard reminderEnabled else { return "Off" }
        let time = Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
        return "Every day at \(time.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your learning profile").font(.headline)
                Spacer()
                NavigationLink { LearningPreferencesIntroView() } label: {
                    Text(hasPreferences ? "Edit" : "Start").font(.subheadline.weight(.semibold))
                }
            }

            if hasPreferences {
                profileLine("Level", SurveyOptions.levelTitle(level) ?? "Not set")
                profileLine("Goals", SurveyOptions.titles(for: goals, in: SurveyOptions.goals))
                profileLine("Interests", SurveyOptions.titles(for: interests, in: SurveyOptions.interests))
                profileLine("Daily goal", "\(dailyMinutes) min · \(reviewLimit) words")
                profileLine("Reminder", reminderText)
            } else {
                HStack(spacing: 12) {
                    BirdMascot(pose: .wave, size: 56)
                    Text("Take the learning survey so NextWord can match your level and interests.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    // Label on the left, answer on the right; stacks on two lines when the text is long.
    private func profileLine(_ label: String, _ value: String) -> some View {
        VStack(spacing: 10) {
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label).foregroundStyle(.secondary)
                    Spacer(minLength: 12)
                    Text(value.isEmpty ? "–" : value).multilineTextAlignment(.trailing)
                }
                // One line only here, so ViewThatFits picks the stacked layout for long answers.
                .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).foregroundStyle(.secondary)
                    Text(value.isEmpty ? "–" : value)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
        }
    }
}

private struct ProfileLinkRow: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(.blue).frame(width: 24)
            Text(title).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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
