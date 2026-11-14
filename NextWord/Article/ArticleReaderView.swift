import SwiftUI
import SwiftData

// This file reads a bundled article and displays it as scrollable text.
// Article content is stored in a JSON file chosen by the reader.

enum ArticleDifficulty: String, Decodable, CaseIterable {
    case beginner
    case intermediate
    case advanced

    var label: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }
}

struct Article: Decodable {
    let id: String
    let title: String
    let author: String
    let source: String
    let sourceURL: URL
    let date: String
    let difficulty: ArticleDifficulty
    let paragraphs: [String]

    // Find the bundled JSON file and decode one Article from it.
    static func load(resourceName: String) throws -> Article {
        // Xcode can flatten synchronized resources into the bundle root.
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "Article")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json") else {
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
        "The article is missing from the app bundle."
    }
}

// Show the article, a loading indicator, or an error message.
struct ArticleReaderView: View {
    let resourceName: String

    init(resourceName: String = "grass-grow") {
        self.resourceName = resourceName
    }

    // Saved with @AppStorage, so the choice survives restarts.
    @AppStorage("highlightSavedWords") private var highlightSavedWords = true

    @Query private var savedWords: [SavedWord]
    @State private var article: Article?
    @State private var errorMessage: String?
    @State private var selectedWord: SelectedArticleWord?

    private struct SelectedArticleWord: Identifiable {
        let id = UUID()
        let text: String
    }

    // Keep punctuation and paragraph spacing while making English words tappable.
    // What counts as a word, so words like "don't" stay whole.
    private static let wordPattern = try! NSRegularExpression(
        pattern: #"[A-Za-z]+(?:['’\-][A-Za-z]+)*"#
    )

    // Saved words drive every occurrence; mastered words stay tappable but unmarked.
    private var highlightedStages: [String: LearningStage] {
        guard highlightSavedWords else { return [:] }
        var stages: [String: LearningStage] = [:]
        for savedWord in savedWords where savedWord.stage != .mastered {
            stages[savedWord.lookupKey.lowercased()] = savedWord.stage
        }
        return stages
    }

    var body: some View {
        ScrollView {
            if let article {
                VStack(alignment: .leading, spacing: 20) {
                    Text(article.title)
                        .font(.largeTitle.bold())

                    Text("\(article.author) · \(article.source) · \(article.date)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Tap an English word to see its meaning and save it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // Render each paragraph in its original order.
                    ForEach(article.paragraphs.indices, id: \.self) { index in
                        Text(linkedParagraph(article.paragraphs[index]))
                            .font(.body)
                            .lineSpacing(6)
                            .environment(\.openURL, OpenURLAction { url in
                                guard url.scheme == "nextword", url.host == "lookup",
                                      let word = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                        .queryItems?.first(where: { $0.name == "word" })?.value else {
                                    return .systemAction
                                }
                                selectedWord = SelectedArticleWord(text: word)
                                return .handled
                            })
                    }

                    Link("Read the original on VOA", destination: article.sourceURL)
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            } else if let errorMessage {
                BirdMessage(pose: .reading, title: "Article unavailable", message: errorMessage)
            } else {
                ProgressView("Loading article…")
                    .padding()
            }
        }
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWord) { selection in
            ArticleWordSheetView(word: selection.text)
                .presentationDetents([.medium, .large])
        }
        // Reload, cancelling the old task, when the selected article changes.
        .task(id: resourceName) {
            article = nil
            errorMessage = nil
            do {
                article = try Article.load(resourceName: resourceName)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // Every word becomes a link, and saved words get their colour as a background.
    private func linkedParagraph(_ paragraph: String) -> AttributedString {
        var result = AttributedString()
        var cursor = paragraph.startIndex
        let stages = highlightedStages
        let matches = Self.wordPattern.matches(
            in: paragraph,
            range: NSRange(paragraph.startIndex..<paragraph.endIndex, in: paragraph)
        )

        for match in matches {
            guard let range = Range(match.range, in: paragraph) else { continue }
            result += AttributedString(String(paragraph[cursor..<range.lowerBound]))

            let token = String(paragraph[range])
            var linkedWord = AttributedString(token)
            var destination = URLComponents()
            destination.scheme = "nextword"
            destination.host = "lookup"
            destination.queryItems = [URLQueryItem(name: "word", value: token)]
            linkedWord.link = destination.url
            linkedWord.foregroundColor = .primary
            if let stage = stages[token.lowercased()] {
                linkedWord.backgroundColor = stage.colour.opacity(0.26)
                linkedWord.font = .body.bold()
            }
            result += linkedWord
            cursor = range.upperBound
        }

        result += AttributedString(String(paragraph[cursor...]))
        return result
    }
}
