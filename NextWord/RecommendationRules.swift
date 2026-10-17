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
}
