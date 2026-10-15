import SwiftUI

// Lists the bundled articles and opens the selected one in the existing reader.
struct ArticleLibraryView: View {
    private let resourceNames = ["grass-grow", "making-things-from-scratch"]
    @State private var items: [ArticleItem] = []
    @State private var errorMessage: String?

    private struct ArticleItem: Identifiable {
        let resourceName: String
        let article: Article

        var id: String { article.id }
    }

    var body: some View {
        Group {
            if let errorMessage {
                ContentUnavailableView("Articles unavailable", systemImage: "doc.text", description: Text(errorMessage))
            } else {
                List(items) { item in
                    NavigationLink {
                        ArticleReaderView(resourceName: item.resourceName)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.article.title)
                                .font(.headline)
                            Text("\(item.article.source) · \(item.article.date)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
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
}
