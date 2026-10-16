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
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("learningQuestionnaireCompleted_v1") private var hasLearningPreferences = false
    @Query private var words: [SavedWord]
    @State private var showAuthentication = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 76)).foregroundStyle(.blue.gradient).accessibilityHidden(true)
                    Text(displayName.isEmpty ? "Your learning space" : displayName).font(.title.bold())
                    Text("Learning on this device").font(.subheadline).foregroundStyle(.secondary)
                    Button("Sign in or create an account") { showAuthentication = true }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                    Text("Account connection is coming soon. You can keep learning as a guest.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(24)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
                HStack(spacing: 14) {
                    LearningStat(value: words.count, title: "Words saved", symbol: "bookmark.fill")
                    LearningStat(value: words.filter { $0.stage == .mastered }.count, title: "Mastered", symbol: "checkmark.seal.fill")
                }
                VStack(spacing: 12) {
                    NavigationLink { LearningPreferencesIntroView() } label: {
                        FeatureRow(title: "Learning preferences", subtitle: hasLearningPreferences ? "Update your learning profile" : "Set up your English learning profile", symbol: "slider.horizontal.3", color: .blue)
                    }
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
            .sheet(isPresented: $showAuthentication) { AuthenticationView() }
    }
}

struct EditProfileView: View {
    @AppStorage("displayName") private var displayName = ""
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        Form {
            Section("Display name") {
                TextField("Your name", text: $name).textContentType(.nickname).textInputAutocapitalization(.words)
            }
            Section {
                Text("Your name is saved on this device and appears on your home screen.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Edit profile").navigationBarTitleDisplayMode(.inline)
            .onAppear { name = displayName }
            .toolbar {
                Button("Save") {
                    displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 40)
            }
    }
}
