import SwiftUI
import SwiftData

// Show a tapped article word, then optionally save it to the shared vocabulary.
struct ArticleWordSheetView: View {
    let word: String
    // Tells the learning history whether this word came from an article or a video.
    var source: StudyEventSource = .article

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedWords: [SavedWord]
    @State private var dictionaryEntry: WordsetEntry?
    @State private var dictionaryMessage: String?
    @State private var chineseTranslation: String?
    @State private var translationMessage: String?
    @State private var isDictionaryLoading = true
    @State private var isTranslationLoading = true
    @State private var selectedStage: LearningStage?
    @State private var saveMessage: String?
    @State private var newlySavedWord: SavedWord?

    private let availableStages: [LearningStage] = [
        .unfamiliar, .learning, .improving, .familiar
    ]

    private var existingWord: SavedWord? {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return newlySavedWord ?? savedWords.first { $0.lookupKey == key }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(word)
                        .font(.largeTitle.bold())

                    translationSection
                    dictionarySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
            }
            .navigationTitle("Word details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if let existingWord, existingWord.stage != .mastered {
                selectedStage = existingWord.stage
            }
            async let dictionary: Void = loadDictionary()
            async let translation: Void = loadTranslation()
            _ = await (dictionary, translation)
        }
    }

    @ViewBuilder
    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chinese translation · DeepL")
                .font(.headline)
            if isTranslationLoading {
                ProgressView("Translating…")
            } else if let chineseTranslation {
                Text(chineseTranslation).font(.title3)
            } else if let translationMessage {
                Text(translationMessage).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var dictionarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("English dictionary · Wordset")
                .font(.headline)
            if isDictionaryLoading {
                ProgressView("Looking up locally…")
            } else if let dictionaryEntry, !dictionaryEntry.meanings.isEmpty {
                ForEach(dictionaryEntry.meanings, id: \.id) { meaning in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(meaning.partOfSpeech.capitalized)
                            .font(.subheadline.bold())
                        Text(meaning.definition)
                        if let example = meaning.example, !example.isEmpty {
                            Text("Example: \(example)").foregroundStyle(.secondary)
                        }
                        let synonyms = (meaning.synonyms ?? []).compactMap { $0 }
                        if !synonyms.isEmpty {
                            Text("Synonyms: \(synonyms.joined(separator: ", "))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    Divider()
                }
            } else if let dictionaryMessage {
                Text(dictionaryMessage).foregroundStyle(.secondary)
            }

            Text("Source: Wordset / WordNet · CC BY-SA 4.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Keep the colour choices and save action visible while definitions scroll.
    private var saveBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a colour")
                .font(.subheadline.bold())
            if let existingWord {
                Text("Currently saved as \(existingWord.stage.label).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Four in a row when the names fit on one line; a 2 × 2 grid at very large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { stageButtons }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    stageButtons
                }
            }
            .lineLimit(1)

            Button {
                saveWord()
            } label: {
                Text(existingWord == nil ? "Add to Vocabulary" : "Update colour")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedStage == nil)

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(saveMessage.hasPrefix("Could not") ? .red : .secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    // The four colour buttons, used by both the row and the grid layout above.
    @ViewBuilder private var stageButtons: some View {
        ForEach(availableStages, id: \.self) { stage in
            Button {
                selectedStage = stage
                saveMessage = nil
            } label: {
                VStack(spacing: 5) {
                    Circle()
                        .fill(stage.colour)
                        .frame(width: 18, height: 18)
                    Text(stageName(stage))
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(stage.colour.opacity(selectedStage == stage ? 0.15 : 0.04),
                            in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(selectedStage == stage ? stage.colour : .clear, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(stage.label)
            .accessibilityAddTraits(selectedStage == stage ? .isSelected : [])
        }
    }

    private func stageName(_ stage: LearningStage) -> String {
        switch stage {
        case .unfamiliar: "Red"
        case .learning: "Orange"
        case .improving: "Yellow"
        case .familiar: "Green"
        case .mastered: "Blue"
        }
    }

    // Load the independent local and online results without making one block the other.
    @MainActor
    private func loadDictionary() async {
        do {
            let result = try await WordsetDictionaryService.shared.lookup(word)
            guard !Task.isCancelled else { return }
            dictionaryEntry = result
            dictionaryMessage = result == nil
                ? "This exact form is not in Wordset. Try looking up its base form later."
                : "Wordset lists this word but has no definitions."
        } catch {
            guard !Task.isCancelled else { return }
            dictionaryMessage = "Offline dictionary unavailable: \(error.localizedDescription)"
        }
        isDictionaryLoading = false
    }

    @MainActor
    private func loadTranslation() async {
        do {
            let result = try await ReviewTranslationService.translate(word)
            guard !Task.isCancelled else { return }
            chineseTranslation = result
        } catch {
            guard !Task.isCancelled else { return }
            translationMessage = "Translation unavailable: \(error.localizedDescription)"
        }
        isTranslationLoading = false
    }

    // Update the existing word when possible; never create a duplicate for the same spelling.
    private func saveWord() {
        guard let selectedStage else { return }
        var insertedWord: SavedWord?
        if let existingWord {
            // Only a real colour change is worth recording.
            if existingWord.stage != selectedStage {
                modelContext.insert(StudyEvent(kind: .stageChanged, source: source, word: existingWord.word,
                                               oldStage: existingWord.stage, newStage: selectedStage))
            }
            existingWord.stage = selectedStage
        } else {
            let saved = SavedWord(word: word)
            saved.stage = selectedStage
            modelContext.insert(saved)
            insertedWord = saved
            modelContext.insert(StudyEvent(kind: .saved, source: source, word: saved.word, newStage: selectedStage))
        }
        do {
            try modelContext.save()
            newlySavedWord = insertedWord ?? newlySavedWord
            saveMessage = "Saved to Vocabulary as \(selectedStage.label)."
        } catch {
            modelContext.rollback()
            saveMessage = "Could not save word: \(error.localizedDescription)"
        }
    }
}
