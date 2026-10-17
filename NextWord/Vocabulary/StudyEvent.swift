import Foundation
import SwiftData

// What kind of learning action happened.
enum StudyEventKind: String, Codable, CaseIterable {
    case saved          // A new word was added to Vocabulary.
    case stageChanged   // The user picked a new colour for a saved word.
    case reviewed       // The user finished one review card.
    case deleted        // A saved word was removed.
}

// Where the learning action happened in the app.
enum StudyEventSource: String, Codable, CaseIterable {
    case article
    case video
    case search
    case review
    case vocabulary
}

// One learning action, kept as a history record for the insights charts.
// The word is stored as text (not a relationship), so the record stays
// even after the SavedWord itself is deleted.
@Model
final class StudyEvent {
    var id: UUID = UUID()
    var date: Date = Date()
    var kind: StudyEventKind = StudyEventKind.saved
    var source: StudyEventSource = StudyEventSource.vocabulary
    var word: String = ""
    var lookupKey: String = ""
    var oldStage: LearningStage?
    var newStage: LearningStage?
    // Only set for review events: true when the user answered correctly.
    var wasCorrect: Bool?

    init(
        kind: StudyEventKind,
        source: StudyEventSource,
        word: String,
        oldStage: LearningStage? = nil,
        newStage: LearningStage? = nil,
        wasCorrect: Bool? = nil,
        date: Date = Date()
    ) {
        let cleanedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        self.kind = kind
        self.source = source
        self.word = cleanedWord
        self.lookupKey = cleanedWord.lowercased()
        self.oldStage = oldStage
        self.newStage = newStage
        self.wasCorrect = wasCorrect
        self.date = date
    }
}
