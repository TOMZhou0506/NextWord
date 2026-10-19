import Foundation

// Keep article and video difficulty recommendations consistent.
enum RecommendationRules {
    // The survey's five self-rated levels map onto the three content difficulties.
    static func difficulty(forLevel level: Int) -> String {
        switch level {
        case 1: "beginner"
        case 2, 3: "intermediate"
        case 4, 5: "advanced"
        default: ""
        }
    }

    static func rank(_ value: String) -> Int? {
        switch value.lowercased() {
        case "beginner": 0
        case "intermediate": 1
        case "advanced": 2
        default: nil
        }
    }

    // Only the learner's level and its immediate neighbours are eligible.
    static func distance(level: String, content: String) -> Int? {
        guard let learnerRank = rank(level), let contentRank = rank(content) else { return nil }
        let gap = abs(learnerRank - contentRank)
        return gap <= 1 ? gap : nil
    }

    // A short, specific explanation, e.g. "Matches your level · Intermediate".
    static func reason(level: String, content: String) -> String {
        guard let learnerRank = rank(level), let contentRank = rank(content) else { return "" }
        let difficultyName = content.capitalized
        if learnerRank == contentRank { return "Matches your level · \(difficultyName)" }
        return contentRank < learnerRank
            ? "Easier practice · \(difficultyName)"
            : "A little challenge · \(difficultyName)"
    }

    // The survey saves interests as "f1,gaming"; "none" means no preference.
    static func interests(from saved: String) -> Set<String> {
        Set(saved.split(separator: ",").map(String.init)).subtracting(["none"])
    }

    // The best article for Home: closest difficulty first, then alphabetical.
    static func recommendedArticle(from items: [ArticleItem], level: String) -> ArticleItem? {
        items
            .filter { distance(level: level, content: $0.article.difficulty.rawValue) != nil }
            .min { first, second in
                let firstDistance = distance(level: level, content: first.article.difficulty.rawValue) ?? 3
                let secondDistance = distance(level: level, content: second.article.difficulty.rawValue) ?? 3
                if firstDistance != secondDistance { return firstDistance < secondDistance }
                return first.article.title < second.article.title
            }
    }

    // The best video for Home: closest difficulty first; within a level, a topic the learner likes wins.
    static func recommendedVideo(from videos: [VideoOption], level: String, interests: Set<String>) -> VideoOption? {
        videos
            .filter { distance(level: level, content: $0.difficulty.rawValue) != nil }
            .min { first, second in
                let firstDistance = distance(level: level, content: first.difficulty.rawValue) ?? 3
                let secondDistance = distance(level: level, content: second.difficulty.rawValue) ?? 3
                if firstDistance != secondDistance { return firstDistance < secondDistance }
                let firstLiked = interests.contains(first.interest.preferenceKey)
                let secondLiked = interests.contains(second.interest.preferenceKey)
                if firstLiked != secondLiked { return firstLiked }
                return first.title < second.title
            }
    }

    // E.g. "Matches your level · Intermediate · You like F1 Racing".
    static func videoReason(for video: VideoOption, level: String, interests: Set<String>) -> String {
        let interestReason = interests.contains(video.interest.preferenceKey) ? " · You like \(video.interest.rawValue)" : ""
        return reason(level: level, content: video.difficulty.rawValue) + interestReason
    }
}
