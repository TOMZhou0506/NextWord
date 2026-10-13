import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @AppStorage("readingSize") private var readingSize = "standard"
    @AppStorage("highlightSavedWords") private var highlightSavedWords = true
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Personalization") {
                NavigationLink { EditProfileView() } label: { Label("Display name", systemImage: "person.crop.circle") }
                Picker(selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                } label: { Label("Appearance", systemImage: "circle.lefthalf.filled") }
            }
            Section {
                Picker(selection: $readingSize) {
                    Text("Standard").tag("standard")
                    Text("Large").tag("large")
                    Text("Extra large").tag("extraLarge")
                } label: { Label("Text size", systemImage: "textformat.size") }
                Toggle(isOn: $highlightSavedWords) { Label("Highlight saved words", systemImage: "highlighter") }
                Text("Every new word opens a new door.")
                    .font(readingSize == "extraLarge" ? .title2 : readingSize == "large" ? .title3 : .body)
                    .padding(.vertical, 8)
            } header: { Text("Reading") } footer: { Text("Text size applies to article paragraphs. Your device’s accessibility text size is also supported.") }
            Section {
                Picker(selection: $reviewLimit) {
                    ForEach([5, 10, 20, 30, 50], id: \.self) { Text("\($0) words").tag($0) }
                } label: { Label("Session size", systemImage: "rectangle.stack") }
            } header: { Text("Vocabulary review") } footer: { Text("Choose the maximum number of words in your next review session.") }
            Section {
                NavigationLink { AboutNextWordView() } label: { Label("About NextWord", systemImage: "info.circle") }
                NavigationLink("Data & privacy") {
                    InformationView(title: "Data & privacy", symbol: "lock.shield", text: "Your saved vocabulary, review progress, display name and preferences are stored on this device. Account sign-in and cloud sync are not connected yet.\n\nWord translation uses DeepL and sends the word you look up for translation. Playing embedded YouTube videos connects to YouTube.\n\nThis is a development version. A full privacy policy will be provided before release.")
                }
                Button("Reset preferences", role: .destructive) { confirmReset = true }
            } footer: { Text("Preferences are saved automatically on this device.") }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Reset preferences?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset preferences", role: .destructive) {
                appearance = "system"
                reviewLimit = 20
                readingSize = "standard"
                highlightSavedWords = true
            }
        } message: { Text("Appearance, reading and review preferences return to their defaults. Your name and saved words are kept.") }
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
