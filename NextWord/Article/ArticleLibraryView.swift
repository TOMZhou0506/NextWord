import SwiftUI

// Groups bundled articles by difficulty and opens the selected one.
// Recommendations live only on Home; this tab lists everything.
struct ArticleLibraryView: View {
    @State private var difficultyFilter = "all"
    @State private var items: [ArticleItem] = []
    @State private var errorMessage: String?

    private var visibleItems: [ArticleItem] {
        items.filter { difficultyFilter == "all" || $0.article.difficulty.rawValue == difficultyFilter }
    }

    var body: some View {
        Group {
            if let errorMessage {
                BirdMessage(pose: .reading, title: "Articles unavailable", message: errorMessage)
            } else {
                List {
                    Picker("Difficulty", selection: $difficultyFilter) {
                        Text("All levels").tag("all")
                        ForEach(ArticleDifficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.label).tag(difficulty.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

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
            // The shared catalog decodes each article's JSON, so the list shows real metadata.
            do {
                items = try ContentCatalog.loadArticles()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func articleRow(_ item: ArticleItem) -> some View {
        NavigationLink {
            ArticleReaderView(resourceName: item.resourceName)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.article.title).font(.headline)
                Text("\(item.article.source) · \(item.article.date)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }
}
