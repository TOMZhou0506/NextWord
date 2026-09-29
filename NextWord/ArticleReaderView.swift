import SwiftUI

// This file reads a bundled article and displays it as scrollable text.
// The article content itself is stored in grass-grow.json.

// Decodable maps the JSON fields to Swift properties.
private struct Article: Decodable {
    let id: String
    let title: String
    let author: String
    let source: String
    let sourceURL: URL
    let date: String
    let paragraphs: [String]

    // Find the bundled JSON file and decode one Article from it.
    static func loadSample() throws -> Article {
        guard let url = Bundle.main.url(forResource: "grass-grow", withExtension: "json") else {
            throw ArticleError.missingFile
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Article.self, from: data)
    }
}

// Provide a readable error if the article file is not bundled.
private enum ArticleError: LocalizedError {
    case missingFile

    var errorDescription: String? {
        "The sample article is missing from the app bundle."
    }
}

// Show the article, a loading indicator, or an error message.
struct ArticleReaderView: View {
    @State private var article: Article?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if let article {
                VStack(alignment: .leading, spacing: 20) {
                    Text(article.title)
                        .font(.largeTitle.bold())

                    Text("\(article.author) · \(article.source) · \(article.date)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Render each paragraph in its original order.
                    ForEach(article.paragraphs.indices, id: \.self) { index in
                        Text(article.paragraphs[index])
                            .font(.body)
                            .lineSpacing(6)
                    }

                    Link("Read the original on VOA", destination: article.sourceURL)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else if let errorMessage {
                ContentUnavailableView("Article unavailable", systemImage: "doc.text", description: Text(errorMessage))
            } else {
                ProgressView("Loading article…")
                    .padding()
            }
        }
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        // Load the bundled article when this screen appears.
        .task {
            do {
                article = try Article.loadSample()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
