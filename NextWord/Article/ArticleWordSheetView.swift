import SwiftUI
import SwiftData

// Show a tapped article word, then optionally save it to the shared vocabulary.
struct ArticleWordSheetView: View {
    let word: String

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
                    saveSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
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

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your familiarity")
                .font(.headline)
            if let existingWord {
                Text("Currently saved as \(existingWord.stage.label).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Looking up a word does not add it to Vocabulary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(availableStages, id: \.self) { stage in
                Button {
                    selectedStage = stage
                    saveMessage = nil
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(stage.colour)
                            .frame(width: 14, height: 14)
                        Text(stage.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedStage == stage {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button(existingWord == nil ? "Add to Vocabulary" : "Update colour") {
                saveWord()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(selectedStage == nil)

            if let saveMessage {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(saveMessage.hasPrefix("Could not") ? .red : .secondary)
            }
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
            existingWord.stage = selectedStage
        } else {
            let saved = SavedWord(word: word)
            saved.stage = selectedStage
            modelContext.insert(saved)
            insertedWord = saved
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
