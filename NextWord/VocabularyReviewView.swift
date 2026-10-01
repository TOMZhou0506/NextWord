import SwiftUI

// A temporary review session; it does not change learning stages yet.
struct VocabularyReviewView: View {
    let words: [SavedWord]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var isAnswerVisible = false
    @State private var translations: [UUID: String] = [:]
    @State private var translationErrors: [UUID: String] = [:]
    @State private var prefetchTask: Task<Void, Never>?

    private var isFinished: Bool { currentIndex >= words.count }

    var body: some View {
        VStack(spacing: 18) {
            header

            if isFinished {
                completionCard
            } else {
                ProgressView(value: Double(currentIndex), total: Double(max(words.count, 1)))
                    .tint(.cyan)

                wordCard(words[currentIndex])

                Button(isAnswerVisible ? "Next Word" : "Reveal Answer") {
                    if isAnswerVisible {
                        currentIndex += 1
                        isAnswerVisible = false
                    } else {
                        isAnswerVisible = true
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 14))

                Text("Your answer remains private. Be honest with yourself.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
        .onAppear { prefetchCurrentAndNextFive() }
        .onChange(of: currentIndex) { _, _ in prefetchCurrentAndNextFive() }
        .onDisappear {
            prefetchTask?.cancel()
            translations.removeAll()
            translationErrors.removeAll()
        }
    }

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

    private func wordCard(_ word: SavedWord) -> some View {
        VStack(spacing: 18) {
            Text(word.stage.label)
                .font(.caption)
                .foregroundStyle(word.stage.colour)
                .padding(20)
                .frame(minHeight: 100)
                .background(word.stage.colour.opacity(0.09), in: RoundedRectangle(cornerRadius: 20))

            Text(word.word)
                .font(.system(size: 34, weight: .semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            if let pronunciation = word.pronunciation, !pronunciation.isEmpty {
                Text(pronunciation)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            if isAnswerVisible {
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
            } else {
                Text("Think of the meaning and an example.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 360)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.cyan.opacity(0.2)))
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

    private func retryCurrentWord() {
        guard !isFinished else { return }
        let id = words[currentIndex].id
        translations.removeValue(forKey: id)
        translationErrors.removeValue(forKey: id)
        prefetchCurrentAndNextFive()
    }

    private var completionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Review complete")
                .font(.title2.bold())
            Text("You looked through \(words.count) words. Review results are not saved yet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(.white, in: RoundedRectangle(cornerRadius: 28))
    }
}
