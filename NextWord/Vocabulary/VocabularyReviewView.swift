import SwiftUI
import SwiftData

// Review saved words and persist each completed result.
struct VocabularyReviewView: View {
    // Keep this session's order stable even when saving a new stage updates the dashboard.
    @State private var words: [SavedWord]

    init(words: [SavedWord]) {
        _words = State(initialValue: words)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var wordFontSize = 34.0
    @State private var currentIndex = 0
    // nil means the answer is hidden; the choice decides which buttons appear after reveal.
    @State private var rememberedBeforeReveal: Bool?
    @State private var translations: [UUID: String] = [:]
    @State private var translationErrors: [UUID: String] = [:]
    @State private var prefetchTask: Task<Void, Never>?
    @State private var dictionaryEntry: WordsetEntry?
    @State private var dictionaryMessage = ""
    @State private var isDictionaryLoading = false
    @State private var saveError: String?
    // Words that reached blue in this session, listed on the completion card.
    @State private var masteredWords: [String] = []
    // The word being celebrated right now; the bird shows briefly, then hides.
    @State private var celebratingWord: String?

    private var isFinished: Bool { currentIndex >= words.count }

    var body: some View {
        ScrollView {
        VStack(spacing: 18) {
            header

            if isFinished {
                completionCard
            } else {
                ProgressView(value: Double(currentIndex), total: Double(max(words.count, 1)))
                    .tint(.cyan)

                wordCard(words[currentIndex])

                if let rememberedBeforeReveal {
                    if rememberedBeforeReveal {
                        answerLayout {
                            Button { finishCurrentWord(rememberedCorrectly: true) } label: {
                                Text("I was right").frame(maxWidth: .infinity)
                            }
                            .tint(.green)
                            Button { finishCurrentWord(rememberedCorrectly: false) } label: {
                                Text("I was wrong").frame(maxWidth: .infinity)
                            }
                            .tint(.red)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button { finishCurrentWord(rememberedCorrectly: false) } label: {
                            Text("Next Word").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                } else {
                    answerLayout {
                        Button {
                            rememberedBeforeReveal = true
                        } label: {
                            Label("I remember", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.green)

                        Button {
                            rememberedBeforeReveal = false
                        } label: {
                            Label("I don't remember", systemImage: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.red)
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.subheadline.bold())
                }

                if let saveError {
                    Text("Could not save review: \(saveError)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Your answer remains private. Be honest with yourself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        // A short celebration on top of the next card; taps still reach the card underneath.
        .overlay {
            // Skipped on the last card: the completion card already celebrates.
            if let celebratingWord, !isFinished {
                VStack(spacing: 8) {
                    BirdMascot(pose: .celebrate, size: 120, popsIn: true)
                    Text("“\(celebratingWord)” mastered!")
                        .font(.headline)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .allowsHitTesting(false)
                .accessibilityElement(children: .combine)
            }
        }
        .onAppear { prefetchCurrentAndNextFive() }
        .onChange(of: currentIndex) { _, _ in prefetchCurrentAndNextFive() }
        .task(id: currentIndex) { await loadCurrentDictionaryEntry() }
        .onDisappear {
            prefetchTask?.cancel()
            translations.removeAll()
            translationErrors.removeAll()
        }
    }

    // Side by side when every label fits on one line; stacked otherwise.
    // lineLimit(1) stops labels wrapping, so ViewThatFits can tell when the row is too narrow.
    private func answerLayout<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { content() }
            VStack(spacing: 12) { content() }
        }
        .lineLimit(1)
    }

    // The header has a close button and the progress text
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .frame(width: 46, height: 46)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }

            Spacer()
            VStack(spacing: 2) {
                Text("Today's Review")
                    .font(.headline)
                Text(isFinished ? "Complete" : "\(currentIndex + 1) of \(words.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Color.clear.frame(width: 46, height: 46)
        }
    }

    // wordCard shows the word and its colour label
    private func wordCard(_ word: SavedWord) -> some View {
        VStack(spacing: 18) {
            Text(word.stage.label)
                .font(.caption)
                .foregroundStyle(word.stage.colour)
                .padding(20)
                .frame(minHeight: 100)
                .background(word.stage.colour.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))

            Text(word.word)
                .font(.system(size: wordFontSize, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 24)

            if rememberedBeforeReveal != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let chinese = translations[word.id] {
                            Text("DeepL machine translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(chinese)
                                .font(.title3)
                                .foregroundStyle(.blue)
                        } else if let error = translationErrors[word.id] {
                            Text(error)
                                .foregroundStyle(.red)
                            Button("Retry translation") { retryCurrentWord() }
                        } else {
                            ProgressView("Translating this word…")
                        }

                        dictionaryDetails
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 400 : 270)
            } else {
                Text("Think of the meaning and an example.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 360)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.cyan.opacity(0.2)))
    }

    // Show the celebrating bird for a moment when a word moves from green to blue.
    private func celebrate(_ word: String) {
        masteredWords.append(word)
        celebratingWord = word
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            // Only hide it if a newer celebration hasn't replaced it.
            if celebratingWord == word { celebratingWord = nil }
        }
    }

    // Save only when the user finishes the card; closing early leaves it unchanged.
    // finishCurrentWord moves the word up or down one colour,
    private func finishCurrentWord(rememberedCorrectly: Bool) {
        guard !isFinished, rememberedBeforeReveal != nil else { return }
        let word = words[currentIndex]
        let stages = LearningStage.allCases
        guard let oldIndex = stages.firstIndex(of: word.stage) else { return }
        let nextIndex = rememberedCorrectly
            ? min(oldIndex + 1, stages.count - 1)
            : max(oldIndex - 1, 0)
        let oldStage = word.stage
        word.stage = stages[nextIndex]

        // Record this card in the learning history; it is saved together with the new stage.
        modelContext.insert(StudyEvent(
            kind: .reviewed,
            source: .review,
            word: word.word,
            oldStage: oldStage,
            newStage: word.stage,
            wasCorrect: rememberedCorrectly
        ))

        do {
            try modelContext.save()
            saveError = nil
            currentIndex += 1
            rememberedBeforeReveal = nil
            if word.stage == .mastered && oldStage != .mastered {
                celebrate(word.word)
            }
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }

    // Show Wordset's own fields without inventing missing examples or pronunciations.
    // dictionaryDetails shows the Wordset definitions for the current word
    @ViewBuilder
    private var dictionaryDetails: some View {
        Divider()
        Text("Wordset English dictionary")
            .font(.headline)

        if isDictionaryLoading {
            ProgressView("Looking up this word locally…")
        } else if let dictionaryEntry {
            ForEach(dictionaryEntry.meanings, id: \.id) { meaning in
                VStack(alignment: .leading, spacing: 4) {
                    Text(meaning.partOfSpeech.capitalized)
                        .font(.subheadline.bold())
                    Text(meaning.definition)

                    if let example = meaning.example {
                        Text("Example: \(example)")
                            .foregroundStyle(.secondary)
                    }

                    let synonyms = meaning.synonyms?.compactMap { $0 } ?? []
                    if !synonyms.isEmpty {
                        Text("Synonyms: \(synonyms.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
            }
        } else {
            Text(dictionaryMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        Text("Source: Wordset / WordNet · CC BY-SA 4.0")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // Start the local lookup when a card appears, before the answer is revealed.
    // For each new card it looks up the word off the main thread
    @MainActor
    private func loadCurrentDictionaryEntry() async {
        guard !isFinished else { return }
        let word = words[currentIndex]
        let wordID = word.id
        dictionaryEntry = nil
        dictionaryMessage = ""
        isDictionaryLoading = true

        do {
            let result = try await WordsetDictionaryService.shared.lookup(word.word)
            guard !Task.isCancelled, !isFinished, words[currentIndex].id == wordID else { return }
            if let result, !result.meanings.isEmpty {
                dictionaryEntry = result
            } else if result != nil {
                dictionaryMessage = "Wordset lists this word but provides no definitions."
            } else {
                dictionaryMessage = "This word is not in Wordset. The DeepL translation remains available."
            }
        } catch {
            guard !Task.isCancelled, !isFinished, words[currentIndex].id == wordID else { return }
            dictionaryMessage = "Offline dictionary unavailable: \(error.localizedDescription)"
        }
        isDictionaryLoading = false
    }

    // Keep at most one DeepL request active while preparing the next five words.
    private func prefetchCurrentAndNextFive() {
        prefetchTask?.cancel()
        guard !isFinished else { return }

        let endIndex = min(currentIndex + 5, words.count - 1)
        prefetchTask = Task { @MainActor in
            for index in currentIndex...endIndex {
                if Task.isCancelled { return }
                let word = words[index]
                let id = word.id
                if translations[id] != nil || translationErrors[id] != nil { continue }

                do {
                    let chinese = try await ReviewTranslationService.translate(word.word)
                    try Task.checkCancellation()
                    translations[id] = chinese
                } catch {
                    if Task.isCancelled { return }
                    translationErrors[id] = error.localizedDescription
                }
            }
        }
    }

    // If a translation fails, the error is remembered so it won’t retry in a loop
    private func retryCurrentWord() {
        guard !isFinished else { return }
        let id = words[currentIndex].id
        translations.removeValue(forKey: id)
        translationErrors.removeValue(forKey: id)
        prefetchCurrentAndNextFive()
    }

    // completionCard appears when every card is done. It shows a celebrating bird, how many words were
    // reviewed, which reached blue in this session, and a Done button.
    private var completionCard: some View {
        VStack(spacing: 16) {
            BirdMascot(pose: .celebrate, size: 140, popsIn: true)
            Text("Review complete")
                .font(.title2.bold())
            Text("You reviewed \(words.count.counted("word")). Their learning stages have been saved.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if !masteredWords.isEmpty {
                Text("Mastered today: \(masteredWords.joined(separator: ", "))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28))
    }
}
