import SwiftUI
import SwiftData

// Search the bundled English dictionary and save a word at a chosen learning stage.
struct VocabularySearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedWords: [SavedWord]
    @State private var query = ""
    @State private var entry: WordsetEntry?
    @State private var message: String?
    @State private var isSearching = false
    @State private var selectedStage: LearningStage = .unfamiliar
    @State private var isStagePickerPresented = false

    private var existingWord: SavedWord? {
        guard let entry else { return nil }
        let key = entry.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return savedWords.first { $0.lookupKey == key }
    }

    var body: some View {
        Form {
            Section("English word") {
                HStack {
                    TextField("Enter a word", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    Button("Search") { Task { await search() } }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
            }

            if isSearching {
                ProgressView("Searching the local dictionary…")
            } else if let message, entry == nil {
                // The search found nothing (or the dictionary couldn't be read): the bird is puzzled too.
                Section { BirdMessage(pose: .thinking, title: "Hmm, no luck", message: message, birdSize: 90) }
            } else if let message {
                // Notes about saving, e.g. "Word added to Vocabulary."
                Section { Text(message).foregroundStyle(.secondary) }
            } else if entry == nil {
                // Before the first search, invite the learner to look something up.
                Section { BirdMessage(pose: .magnifier, title: "Look up any English word", message: "Definitions come from the offline Wordset dictionary.", birdSize: 90) }
            }

            if let entry {
                Section(entry.word) {
                    if entry.meanings.isEmpty {
                        Text("This entry has no definitions.").foregroundStyle(.secondary)
                    }
                    ForEach(entry.meanings, id: \.id) { meaning in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(meaning.partOfSpeech).font(.subheadline.bold())
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
                        .padding(.vertical, 4)
                    }
                }

                Section("Your familiarity") {
                    Button {
                        isStagePickerPresented = true
                    } label: {
                        HStack {
                            Text("Learning stage")
                            Spacer()
                            Circle()
                                .fill(selectedStage.colour)
                                .frame(width: 12, height: 12)
                            Text(selectedStage.label)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .popover(isPresented: $isStagePickerPresented) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(LearningStage.allCases, id: \.self) { stage in
                                Button {
                                    selectedStage = stage
                                    isStagePickerPresented = false
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
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(minWidth: 240)
                        .padding(.vertical, 8)
                        .presentationCompactAdaptation(.popover)
                    }
                    Button(existingWord == nil ? "Add to Vocabulary" : "Update Colour") {
                        saveWord(entry)
                    }
                    .disabled(entry.meanings.isEmpty)
                }

                Section {
                    Text("Source: Wordset / WordNet · CC BY-SA 4.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Search Dictionary")
        .onChange(of: query) {
            entry = nil
            message = nil
        }
    }

    // Look up exactly what the user entered; the dictionary does not infer word forms.
    @MainActor
    private func search() async {
        let word = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !word.isEmpty else { return }
        entry = nil
        message = nil
        isSearching = true
        defer { isSearching = false }

        do {
            let found = try await WordsetDictionaryService.shared.lookup(word)
            guard query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == word else { return }
            if let found {
                entry = found
                let key = found.word.lowercased()
                selectedStage = savedWords.first { $0.lookupKey == key }?.stage ?? .unfamiliar
            } else {
                message = "This word was not found in the local dictionary. Try its base form."
            }
        } catch {
            message = "Could not read the local dictionary: \(error.localizedDescription)"
        }
    }

    // Reuse an existing record instead of adding the same word twice.
    private func saveWord(_ entry: WordsetEntry) {
        let wasAlreadySaved = existingWord != nil
        if let existingWord {
            // Only a real colour change is worth recording.
            if existingWord.stage != selectedStage {
                modelContext.insert(StudyEvent(kind: .stageChanged, source: .search, word: existingWord.word,
                                               oldStage: existingWord.stage, newStage: selectedStage))
            }
            existingWord.stage = selectedStage
        } else {
            let word = SavedWord(word: entry.word)
            word.stage = selectedStage
            modelContext.insert(word)
            modelContext.insert(StudyEvent(kind: .saved, source: .search, word: word.word, newStage: selectedStage))
        }
        do {
            try modelContext.save()
            message = wasAlreadySaved ? "Learning stage updated." : "Word added to Vocabulary."
        } catch {
            modelContext.rollback()
            message = "Could not save the word: \(error.localizedDescription)"
        }
    }
}
