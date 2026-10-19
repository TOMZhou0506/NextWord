import SwiftUI
import SwiftData

// Show vocabulary totals and links to the five learning stages.
struct VocabularyView: View {
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var words: [SavedWord]
    @AppStorage("reviewLimit") private var reviewLimit = 20
    @ScaledMetric(relativeTo: .largeTitle) private var totalFontSize = 48.0
    @State private var isReviewPresented = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                totalCard
                stageSummary
                reviewPlan
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vocabulary")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    VocabularySearchView()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search dictionary")
            }
        }
        .fullScreenCover(isPresented: $isReviewPresented) {
            VocabularyReviewView(words: reviewWords)
        }
    }

    // The total updates automatically when saved words change.
    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("Your vocabulary")
                .font(.subheadline)
            Text("\(words.count)")
                .font(.system(size: totalFontSize, weight: .semibold, design: .rounded))
            Text("words collected")
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    // Each coloured row opens the words in that stage.
    private var stageSummary: some View {
        VStack(spacing: 16) {
            ForEach(LearningStage.allCases, id: \.self) { stage in
                NavigationLink {
                    VocabularyStageView(stage: stage)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stage.colour)
                            .frame(width: 12, height: 12)
                        Text(stage.label)
                        Spacer()
                        Text("\(wordsIn(stage).count)")
                            .monospacedDigit()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    // Filter the local SwiftData results for one stage.
    private func wordsIn(_ stage: LearningStage) -> [SavedWord] {
        words.filter { $0.stage == stage }
    }

    // Shared with Home, so both "Start review" buttons review the same words.
    private var reviewWords: [SavedWord] {
        ReviewPlan.words(from: words, limit: reviewLimit)
    }

    private var reviewPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review plan")
                .font(.title2.bold())
            Text("Practice red, orange, yellow and green words. The current session includes up to \(reviewLimit) words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Nothing to review: the bird takes a nap until new words arrive.
            if reviewWords.isEmpty {
                BirdMessage(
                    pose: .sleeping,
                    title: "Nothing to review right now",
                    message: words.isEmpty
                        ? "Save words from articles and videos to start reviewing."
                        : "All your words are blue. Save new words to keep learning.",
                    birdSize: 90
                )
            }

            Button {
                isReviewPresented = true
            } label: {
                Text("Start Review · \(reviewWords.count) words")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reviewWords.isEmpty)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

// Show only the English words saved in the selected learning stage.
private struct VocabularyStageView: View {
    let stage: LearningStage
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.word) private var words: [SavedWord]
    @State private var deleteError: String?

    private var stageWords: [SavedWord] {
        words.filter { $0.stage == stage }
    }

    var body: some View {
        List {
            ForEach(stageWords) { word in
                Text(word.word)
            }
            // Swipe left on a row to delete it straight away.
            .onDelete(perform: deleteWords)

            if let deleteError {
                Text("Could not delete word: \(deleteError)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .overlay {
            if stageWords.isEmpty {
                ContentUnavailableView("No words yet", systemImage: "text.book.closed")
            }
        }
        .navigationTitle(stage.label)
    }

    // Remove the swiped words, but keep a history record of each one.
    private func deleteWords(at offsets: IndexSet) {
        let wordsToDelete = offsets.map { stageWords[$0] }
        for word in wordsToDelete {
            modelContext.insert(StudyEvent(kind: .deleted, source: .vocabulary, word: word.word, oldStage: word.stage))
            modelContext.delete(word)
        }
        do {
            try modelContext.save()
            deleteError = nil
        } catch {
            modelContext.rollback()
            deleteError = error.localizedDescription
        }
    }
}

// Keep each stage's label and colour in one place.
extension LearningStage {
    var label: String {
        switch self {
        case .unfamiliar: "Red · Unfamiliar"
        case .learning: "Orange · Learning"
        case .improving: "Yellow · Improving"
        case .familiar: "Green · Familiar"
        case .mastered: "Blue · Mastered"
        }
    }

    var colour: Color {
        switch self {
        case .unfamiliar: .red
        case .learning: .orange
        case .improving: .yellow
        case .familiar: .green
        case .mastered: .blue
        }
    }
}
