import SwiftUI

// The main screen holds the bottom tabs and the local Home content.
struct ContentView: View {
    // AppStorage keeps the name between app launches; State holds temporary edits.
    @AppStorage("displayName") private var displayName = ""
    @State private var draftName = ""
    @State private var isEditingName = false

    // Remove accidental spaces before saving the name.
    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        // TabView keeps the five main sections in one bottom navigation bar.
        TabView {
            home
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                ArticleReaderView()
            }
            .tabItem { Label("Article", systemImage: "doc.text") }

            placeholder("Video")
                .tabItem { Label("Video", systemImage: "play.rectangle") }

            NavigationStack {
                VocabularyView()
            }
            .tabItem { Label("Vocabulary", systemImage: "books.vertical") }

            placeholder("Profile")
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }

    // Reuse the current welcome and local-name screen as Home.
    private var home: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                if displayName.isEmpty || isEditingName {
                    Text("Welcome to NextWord")
                        .font(.largeTitle.bold())
                    Text("Read English in context and collect words you want to learn.")
                        .foregroundStyle(.secondary)

                    TextField("Your name", text: $draftName)
                        .textContentType(.nickname)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)

                    Button("Get Started") {
                        displayName = trimmedName
                        isEditingName = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedName.isEmpty)
                } else {
                    Text("Hello, \(displayName)!")
                        .font(.largeTitle.bold())
                    Text("Start with a short English article.")
                        .foregroundStyle(.secondary)

                    // Navigate to the separate reading screen.
                    NavigationLink("Read the article") {
                        ArticleReaderView()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Change name") {
                        draftName = displayName
                        isEditingName = true
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .navigationTitle("NextWord")
        }
    }

    // Temporary text for sections we have not built yet.
    private func placeholder(_ title: String) -> some View {
        ContentUnavailableView("\(title) coming soon", systemImage: "square.dashed")
    }
}
