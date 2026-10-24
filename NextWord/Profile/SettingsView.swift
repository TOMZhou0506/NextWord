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
            } header: { Text("Learning") } footer: { Text("The review session size is the most words one review will include. To change your level or interests, retake the learning survey in Profile. Study reminders are in Profile too.") }
            Section {
                NavigationLink { AboutNextWordView() } label: { Label("About NextWord", systemImage: "info.circle") }
                NavigationLink { PrivacyPolicyView() } label: { Label("Privacy policy", systemImage: "lock.shield") }
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

// The About page required by the unit: the app, the developer, and credit for every
// library, service, source and tool used to build NextWord.
struct AboutNextWordView: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0" }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    BirdMascot(pose: .wave, size: 110)
                    Text("NextWord").font(.title.bold())
                    Text("Build your English through stories, videos and words worth remembering.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Developer") {
                LabeledContent("Name", value: "Xiaoyu Zhou (Tom)")
                LabeledContent("Student ID", value: "35484632")
                LabeledContent("Unit", value: "FIT3178 iOS App Development")
                LabeledContent("University", value: "Monash University, 2026")
            }

            Section {
                CreditRow(name: "Firebase iOS SDK", detail: "Authentication and Cloud Firestore · Google · Apache 2.0",
                          link: "https://firebase.google.com")
                CreditRow(name: "DeepL API", detail: "English to Chinese translation",
                          link: "https://www.deepl.com/pro-api")
                CreditRow(name: "Wordset dictionary", detail: "Offline English definitions, based on WordNet · CC BY-SA 4.0",
                          link: "https://github.com/wordset/wordset-dictionary")
                CreditRow(name: "YouTube IFrame Player API", detail: "Plays the video lessons inside the app",
                          link: "https://developers.google.com/youtube/iframe_api_reference")
            } header: {
                Text("Libraries and services")
            }

            Section {
                CreditRow(name: "VOA Learning English", detail: "All reading articles; each article links to its original page",
                          link: "https://learningenglish.voanews.com")
                ForEach(ContentCatalog.videos) { video in
                    CreditRow(name: video.title, detail: "Video by \(video.source)", link: "https://www.youtube.com/watch?v=\(video.id)")
                }
            } header: {
                Text("Content")
            } footer: {
                Text("All articles and videos belong to their original creators and are used for learning only.")
            }

            Section {
                CreditRow(name: "OpenAI Whisper", detail: "Speech recognition for the video transcripts · MIT",
                          link: "https://github.com/openai/whisper")
                CreditRow(name: "yt-dlp", detail: "Downloads the audio used for transcription · Unlicense",
                          link: "https://github.com/yt-dlp/yt-dlp")
                CreditRow(name: "FFmpeg", detail: "Converts the audio for Whisper · LGPL",
                          link: "https://ffmpeg.org")
            } header: {
                Text("Transcript tools")
            } footer: {
                Text("Used on a Mac to prepare transcripts in advance; not included in the app. See tools/README.md in the repository.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// One acknowledgement: what was used, how it's used, and an optional link to its website.
private struct CreditRow: View {
    let name: String
    let detail: String
    var link: String? = nil

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 3) {
            Text(name).foregroundStyle(.primary)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        if let link, let url = URL(string: link) {
            Link(destination: url) {
                HStack {
                    content
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
        } else {
            content
        }
    }
}
