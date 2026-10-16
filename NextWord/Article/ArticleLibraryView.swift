import SwiftUI

// Groups bundled articles by difficulty and opens the selected one.
struct ArticleLibraryView: View {
    @AppStorage("learningQuestionnaireCompleted_v1") private var hasPreferences = false
    @AppStorage("englishLevel_v1") private var englishLevel = ""
    @State private var difficultyFilter = "all"

    private let resourceNames = [
        "grass-grow", "making-things-from-scratch", "sliced-bread", "friends", "studying-more-powerful"
    ]
    @State private var items: [ArticleItem] = []
    @State private var errorMessage: String?

    private struct ArticleItem: Identifiable {
        let resourceName: String
        let article: Article

        var id: String { article.id }
    }

    private var visibleItems: [ArticleItem] {
        items.filter { difficultyFilter == "all" || $0.article.difficulty.rawValue == difficultyFilter }
    }

    // Show up to two level-appropriate articles, including nearby levels only if needed.
    private var recommendedItems: [ArticleItem] {
        guard hasPreferences else { return [] }
        return Array(visibleItems
            .filter { RecommendationRules.distance(level: englishLevel, content: $0.article.difficulty.rawValue) != nil }
            .sorted { first, second in
                let firstDistance = RecommendationRules.distance(level: englishLevel, content: first.article.difficulty.rawValue) ?? 3
                let secondDistance = RecommendationRules.distance(level: englishLevel, content: second.article.difficulty.rawValue) ?? 3
                if firstDistance != secondDistance { return firstDistance < secondDistance }
                return first.article.title < second.article.title
            }
            .prefix(2))
    }

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView("Articles unavailable", systemImage: "doc.text", description: Text(errorMessage))
            } else {
                List {
                    Picker("Difficulty", selection: $difficultyFilter) {
                        Text("All levels").tag("all")
                        ForEach(ArticleDifficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.label).tag(difficulty.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if !recommendedItems.isEmpty {
                        Section("For you") {
                            ForEach(recommendedItems) { item in
                                articleRow(item, reason: RecommendationRules.reason(
                                    level: englishLevel, content: item.article.difficulty.rawValue))
                            }
                        }
                    }

                    ForEach(ArticleDifficulty.allCases, id: \.self) { difficulty in
                        let articles = visibleItems.filter { $0.article.difficulty == difficulty }
                        if !articles.isEmpty {
                            Section(difficulty.label) {
                                ForEach(articles) { item in
                                    articleRow(item)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Articles")
        .task {
            // Reuse the reader's JSON model so the list shows the actual article metadata.
            do {
                items = try resourceNames.map { name in
                    ArticleItem(resourceName: name, article: try Article.load(resourceName: name))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func articleRow(_ item: ArticleItem, reason: String? = nil) -> some View {
        NavigationLink {
            ArticleReaderView(resourceName: item.resourceName)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.article.title).font(.headline)
                if let reason {
                    Text("\(reason) · \(item.article.difficulty.label)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
                Text("\(item.article.source) · \(item.article.date)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }
}
