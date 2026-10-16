import Foundation

// Keep article and video difficulty recommendations consistent.
enum RecommendationRules {
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

    static func reason(level: String, content: String) -> String {
        guard let learnerRank = rank(level), let contentRank = rank(content) else { return "" }
        if learnerRank == contentRank { return "Matches your level" }
        return contentRank < learnerRank ? "Good for practice" : "A little challenge"
    }
}
