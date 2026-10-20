import Foundation

// The answers the learning survey offers, kept apart from the survey screen's layout code.
enum SurveyOptions {
    struct Choice: Identifiable {
        let id: String
        let title: String
        let symbol: String
    }

    static let sources = [
        Choice(id: "friends", title: "Friends or family", symbol: "person.2"),
        Choice(id: "appstore", title: "App Store", symbol: "apple.logo"),
        Choice(id: "xiaohongshu", title: "Xiaohongshu (RED)", symbol: "book.closed"),
        Choice(id: "bilibili", title: "Bilibili", symbol: "play.tv"),
        Choice(id: "tiktok", title: "TikTok or Douyin", symbol: "music.note"),
        Choice(id: "instagram", title: "Instagram or Facebook", symbol: "camera"),
        Choice(id: "search", title: "Search engine", symbol: "magnifyingglass"),
        Choice(id: "school", title: "School or teacher", symbol: "graduationcap"),
        Choice(id: "other", title: "Other", symbol: "ellipsis.circle")
    ]

    // Five self-rated levels; RecommendationRules turns them into three content difficulties.
    static let levels = [
        (1, "I'm new to English"),
        (2, "I know some common words"),
        (3, "I can have basic conversations"),
        (4, "I can talk about various topics"),
        (5, "I can discuss most topics in detail")
    ]

    static let goals = [
        Choice(id: "travel", title: "Prepare for travel", symbol: "airplane"),
        Choice(id: "people", title: "Connect with people", symbol: "person.2.wave.2"),
        Choice(id: "education", title: "Support my education", symbol: "graduationcap"),
        Choice(id: "career", title: "Boost my career", symbol: "briefcase"),
        Choice(id: "media", title: "Enjoy videos and games", symbol: "play.rectangle"),
        Choice(id: "productive", title: "Spend time productively", symbol: "brain.head.profile"),
        Choice(id: "fun", title: "Just for fun", symbol: "party.popper")
    ]

    static let interests = [
        Choice(id: "gaming", title: "Gaming", symbol: "gamecontroller"),
        Choice(id: "f1", title: "F1 Racing", symbol: "flag.checkered"),
        Choice(id: "basketball", title: "Basketball", symbol: "basketball"),
        Choice(id: "lifestyle", title: "Lifestyle", symbol: "person.2"),
        Choice(id: "none", title: "No preference", symbol: "sparkles")
    ]

    static let studyTimes = [
        Choice(id: "morning", title: "Morning", symbol: "sunrise"),
        Choice(id: "afternoon", title: "Afternoon", symbol: "sun.max"),
        Choice(id: "evening", title: "Evening", symbol: "moon.stars"),
        Choice(id: "varies", title: "No regular time", symbol: "calendar")
    ]
}
