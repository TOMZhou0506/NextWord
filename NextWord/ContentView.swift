import SwiftUI
import SwiftData

struct ContentView: View {
    private enum AppTab { case home, article, video, vocabulary, profile }

    @AppStorage("appearance") private var appearance = "system"
    // Knowing the selected tab lets a tapped reminder switch to Vocabulary.
    @State private var selectedTab = AppTab.home
    private let router = NotificationRouter.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            NavigationStack { ArticleLibraryView() }
                .tabItem { Label("Article", systemImage: "doc.text") }
                .tag(AppTab.article)
            NavigationStack { VideoLibraryView() }
                .tabItem { Label("Video", systemImage: "play.rectangle") }
                .tag(AppTab.video)
            NavigationStack { VocabularyView() }
                .tabItem { Label("Vocabulary", systemImage: "books.vertical") }
                .tag(AppTab.vocabulary)
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
        // While the app is running, a tapped reminder changes the router's flag.
        .onChange(of: router.wantsVocabulary) { _, wants in
            if wants { openVocabulary() }
        }
        // If the tap launched the app, the flag was set before this screen existed.
        .onAppear {
            if router.wantsVocabulary { openVocabulary() }
        }
        .modifier(AppTextSizeModifier())
        .tint(.blue)
        .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
    }

    private func openVocabulary() {
        selectedTab = .vocabulary
        router.wantsVocabulary = false
    }
}

private struct HomeView: View {
    @EnvironmentObject private var authService: AuthService
    @Query private var words: [SavedWord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A LITTLE EVERY DAY").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.blue)
                    Text(authService.displayName.isEmpty ? "Make every word count." : "Welcome back, \(authService.displayName).")
                        .font(.largeTitle.bold())
                    Text("Discover a story. Collect new words. Keep growing.").foregroundStyle(.secondary)
                }
                NavigationLink { ArticleLibraryView() } label: {
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
                NavigationLink { VideoLibraryView() } label: {
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
