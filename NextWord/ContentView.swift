import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
            NavigationStack { ArticleReaderView() }
                .tabItem { Label("Article", systemImage: "doc.text") }
            NavigationStack { VideoView() }
                .tabItem { Label("Video", systemImage: "play.rectangle") }
            NavigationStack { VocabularyView() }
                .tabItem { Label("Vocabulary", systemImage: "books.vertical") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .modifier(AppTextSizeModifier())
        .tint(.blue)
        .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
    }
}

private struct HomeView: View {
    @AppStorage("displayName") private var displayName = ""
    @Query private var words: [SavedWord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A LITTLE EVERY DAY").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.blue)
                    Text(displayName.isEmpty ? "Make every word count." : "Welcome back, \(displayName).")
                        .font(.largeTitle.bold())
                    Text("Discover a story. Collect new words. Keep growing.").foregroundStyle(.secondary)
                }
                NavigationLink { ArticleReaderView() } label: {
                    VStack(alignment: .leading, spacing: 18) {
                        Image(systemName: "book.pages.fill").font(.largeTitle)
                        Text("Your next chapter").font(.title.bold())
                        Text("Explore English through real stories, one word at a time.").font(.subheadline)
                        Label("Start reading", systemImage: "arrow.right").font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(26)
                    .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
                }.buttonStyle(.plain)
                HStack(spacing: 14) {
                    LearningStat(value: words.count, title: "Words saved", symbol: "bookmark.fill")
                    LearningStat(value: words.filter { $0.stage == .mastered }.count, title: "Mastered", symbol: "checkmark.seal.fill")
                }
                Text("Keep exploring").font(.title2.bold())
                NavigationLink { VideoView() } label: {
                    FeatureRow(title: "Learn by watching", subtitle: "Listen, follow along and save new words", symbol: "play.rectangle.fill", color: .purple)
                }.buttonStyle(.plain)
                NavigationLink { VocabularyView() } label: {
                    FeatureRow(title: "Build your vocabulary", subtitle: "Give the words you saved another look", symbol: "rectangle.stack.fill", color: .blue)
                }.buttonStyle(.plain)
            }.padding(20).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground)).navigationTitle("NextWord")
        .toolbar {
            NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                .accessibilityLabel("Settings")
        }
    }
}
