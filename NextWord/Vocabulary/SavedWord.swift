import Foundation
import SwiftData

// The five learning levels shown on the Vocabulary screen.
enum LearningStage: String, Codable, CaseIterable {
    case unfamiliar
    case learning
    case improving
    case familiar
    case mastered
}

// One saved vocabulary item, shared by the article and video features later.
@Model
final class SavedWord {
    var id: UUID = UUID()
    var word: String
    var lookupKey: String
    var pronunciation: String?
    var meaning: String?
    var stage: LearningStage = LearningStage.unfamiliar
    var savedAt: Date = Date()
    var lastReviewedAt: Date?

    // Start a new word at the unfamiliar stage; details can be added later.
    init(word: String, meaning: String? = nil) {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.word = cleanedWord
        self.lookupKey = cleanedWord.lowercased()
        self.meaning = meaning
    }
}

// Which words the next review includes. Used by Vocabulary and Home.
enum ReviewPlan {
    // Red through green words, least familiar first; blue words are mastered and skipped.
    static func words(from words: [SavedWord], limit: Int) -> [SavedWord] {
        let stages: [LearningStage] = [.unfamiliar, .learning, .improving, .familiar]
        return Array(words
            .filter { stages.contains($0.stage) }
            .sorted { (stages.firstIndex(of: $0.stage) ?? stages.count) < (stages.firstIndex(of: $1.stage) ?? stages.count) }
            .prefix(limit))
    }
}
