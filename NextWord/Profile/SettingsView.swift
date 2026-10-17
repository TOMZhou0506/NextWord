import FirebaseAuth
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authService: AuthService
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @AppStorage("dailyMinutes_v1") private var dailyMinutes = 15
    @AppStorage("readingSize") private var readingSize = "standard"
    @AppStorage("highlightSavedWords") private var highlightSavedWords = true
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                NavigationLink { EditProfileView() } label: { Label("Display name", systemImage: "person.crop.circle") }
                Picker(selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                } label: { Label("Appearance", systemImage: "circle.lefthalf.filled") }
                Picker(selection: $readingSize) {
                    Text("Standard").tag("standard")
                    Text("Large").tag("large")
                    Text("Extra large").tag("extraLarge")
                } label: { Label("Text size", systemImage: "textformat.size") }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your next chapter").font(.headline)
                    Text("Every new word opens a new door.").font(.body)
                    Text("Text size preview").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            } header: { Text("Personalization") } footer: { Text("Text size applies throughout NextWord. Standard follows your device settings; larger options increase that size.") }
            Section {
                Toggle(isOn: $highlightSavedWords) { Label("Highlight saved words", systemImage: "highlighter") }
            } header: { Text("Reading") } footer: { Text("Highlight words you have saved while reading.") }
            Section {
                NavigationLink { LearningPreferencesIntroView() } label: {
                    Label("Retake learning survey", systemImage: "slider.horizontal.3")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Daily goal · \(dailyMinutes) min", systemImage: "clock").monospacedDigit()
                    // Upload once the finger lifts, not on every small movement.
                    Slider(value: $dailyMinutes.asDouble, in: 10...60, step: 5) { editing in
                        if !editing { syncLearningSettings() }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Review session · \(reviewLimit) words", systemImage: "rectangle.stack").monospacedDigit()
                    Slider(value: $reviewLimit.asDouble, in: 10...100, step: 5) { editing in
                        if !editing { syncLearningSettings() }
                    }
                }
            } header: { Text("Learning") } footer: { Text("Your level, interests and study time come from the learning survey. The review session size is the most words one review will include.") }
            Section {
                NavigationLink { AboutNextWordView() } label: { Label("About NextWord", systemImage: "info.circle") }
                NavigationLink("Data & privacy") {
                    InformationView(title: "Data & privacy", symbol: "lock.shield", text: "Your account uses Firebase Authentication; your password is handled by Firebase and never stored by NextWord. Your display name, email and learning survey answers are saved to your account in Firebase.\n\nYour saved vocabulary and review progress are stored on this device, separately for each account. They are not uploaded yet.\n\nWord translation uses DeepL and sends the word you look up for translation. Playing embedded YouTube videos connects to YouTube.\n\nThis is a development version. A full privacy policy will be provided before release.")
                }
                Button("Reset preferences", role: .destructive) { confirmReset = true }
            } footer: { Text("Settings are saved automatically for this account.") }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset preferences?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset preferences", role: .destructive) {
                appearance = "system"
                reviewLimit = 20
                dailyMinutes = 15
                readingSize = "standard"
                highlightSavedWords = true
                syncLearningSettings()
            }
        } message: { Text("Appearance, reading and learning goals return to their defaults. Your name, survey answers and saved words are kept.") }
    }

    // Copy the review size and daily goal to Firestore with the survey answers.
    private func syncLearningSettings() {
        if let uid = authService.user?.uid { PreferencesSync.upload(uid: uid) }
    }
}

struct AboutNextWordView: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }
    var body: some View {
        InformationView(title: "NextWord", symbol: "book.pages.fill", text: "Build your English through stories, videos and words worth remembering.\n\nVersion \(version) · Development preview\n\nEnglish definitions: Wordset / WordNet, licensed under CC BY-SA 4.0.\nTranslations: DeepL.\nArticle and video sources are credited on their respective screens.")
    }
}

struct InformationView: View {
    let title: String
    let symbol: String
    let text: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: symbol).font(.system(size: 52)).foregroundStyle(.blue).accessibilityHidden(true)
                Text(title).font(.largeTitle.bold())
                Text(text).foregroundStyle(.secondary).lineSpacing(6)
            }.padding(24).frame(maxWidth: 650, alignment: .leading).frame(maxWidth: .infinity)
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}
