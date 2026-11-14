import Foundation

// Every bundled article and video in one place, so the Article tab, the Video tab
// and the Home "For you" section all use the same list.

enum VideoDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum VideoInterest: String, CaseIterable {
    case gaming = "Gaming"
    case formulaOne = "F1 Racing"
    case basketball = "Basketball"
    case lifestyle = "Lifestyle"

    // Matches the ids saved by the learning survey.
    var preferenceKey: String {
        switch self {
        case .gaming: "gaming"
        case .formulaOne: "f1"
        case .basketball: "basketball"
        case .lifestyle: "lifestyle"
        }
    }
}

struct VideoOption: Identifiable {
    let id: String
    let title: String
    let source: String
    let transcriptResource: String
    let difficulty: VideoDifficulty
    let interest: VideoInterest
}

struct ArticleItem: Identifiable {
    let resourceName: String
    let article: Article

    var id: String { article.id }
}

enum ContentCatalog {
    // Each video is paired with its prepared Whisper transcript.
    static let videos = [
        VideoOption(
            id: "heycg7D5VZw",
            title: "Lesson 1: Welcome!",
            source: "VOA Learning English",
            transcriptResource: "VOAWelcome-full",
            difficulty: .beginner,
            interest: .lifestyle
        ),
        VideoOption(
            id: "i21NAHe77UM",
            title: "The Most GOATED English Caster Calls in League of Legends History",
            source: "LoL Esports",
            transcriptResource: "LoLHighlights-full",
            difficulty: .advanced,
            interest: .gaming
        ),
        VideoOption(
            id: "G2YToseV8aw",
            title: "Max Verstappen's END OF SEASON REVIEW! | Talking Bull",
            source: "Oracle Red Bull Racing",
            transcriptResource: "RedBullTalkingBull-full",
            difficulty: .intermediate,
            interest: .formulaOne
        ),
        VideoOption(
            id: "t6_vawdzRok",
            title: "Why no one guards Steph Curry this way | NBA Finals Game 4 analysis",
            source: "Thinking Basketball",
            transcriptResource: "ThinkingBasketballCurry-full",
            difficulty: .advanced,
            interest: .basketball
        ),
        VideoOption(
            id: "v9QtM6qnG50",
            title: "I Built A City To Save Kids From Illegal Labor",
            source: "MrBeast",
            transcriptResource: "MrBeastCity-full",
            difficulty: .intermediate,
            interest: .lifestyle
        )
    ]

    // JSON file names in the Article folder.
    static let articleResourceNames = [
        "grass-grow", "making-things-from-scratch", "sliced-bread", "friends", "studying-more-powerful"
    ]

    // Decode every bundled article; throws if any file is missing or broken.
    static func loadArticles() throws -> [ArticleItem] {
        try articleResourceNames.map { name in
            ArticleItem(resourceName: name, article: try Article.load(resourceName: name))
        }
    }
}
