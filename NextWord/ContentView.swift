import SwiftUI
import SwiftData

// tab bar 
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
