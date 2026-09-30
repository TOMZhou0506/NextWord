import SwiftUI
import SwiftData

// Show vocabulary totals and links to the five learning stages.
struct VocabularyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var words: [SavedWord]
    @AppStorage("didSeedVocabularyDemo_v1") private var didSeedDemo = false
    @State private var seedError: String?
    @State private var isReviewPresented = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                totalCard
                stageSummary
                reviewPlan

                if let seedError {
                    Text("Could not add demo words: \(seedError)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vocabulary")
        .task { addDemoWordsIfNeeded() }
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
                .font(.system(size: 48, weight: .semibold, design: .rounded))
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
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    // Filter the local SwiftData results for one stage.
    private func wordsIn(_ stage: LearningStage) -> [SavedWord] {
        words.filter { $0.stage == stage }
    }

    // Review the three not-yet-familiar stages, with red words first.
    private var reviewWords: [SavedWord] {
        let stages: [LearningStage] = [.unfamiliar, .learning, .improving]
        return Array(words
            .filter { stages.contains($0.stage) }
            .sorted { (stages.firstIndex(of: $0.stage) ?? stages.count) < (stages.firstIndex(of: $1.stage) ?? stages.count) }
            .prefix(20))
    }

    private var reviewPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review plan")
                .font(.title2.bold())
            Text("Practice red, orange and yellow words. The current session includes up to 20 words.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    // Add sample words once, without changing words already saved by the user.
    private func addDemoWordsIfNeeded() {
        guard !didSeedDemo else { return }
        let samples: [(String, LearningStage)] = [
            ("tedious", .unfamiliar), ("overwhelmed", .unfamiliar),
            ("bloom", .learning), ("renewal", .learning),
            ("noticeable", .improving), ("campaign", .improving),
            ("grass", .familiar), ("speech", .familiar),
            ("flower", .mastered), ("travel", .mastered)
        ]
        let existingKeys = Set(words.map(\.lookupKey))

        for (text, stage) in samples where !existingKeys.contains(text) {
            let word = SavedWord(word: text)
            word.stage = stage
            modelContext.insert(word)
        }

        do {
            try modelContext.save()
            didSeedDemo = true
        } catch {
            modelContext.rollback()
            seedError = error.localizedDescription
        }
    }
}

// Show only the English words saved in the selected learning stage.
private struct VocabularyStageView: View {
    let stage: LearningStage
    @Query(sort: \SavedWord.word) private var words: [SavedWord]

    private var stageWords: [SavedWord] {
        words.filter { $0.stage == stage }
    }

    var body: some View {
        List {
            ForEach(stageWords) { word in
                Text(word.word)
            }
        }
        .overlay {
            if stageWords.isEmpty {
                ContentUnavailableView("No words yet", systemImage: "text.book.closed")
            }
        }
        .navigationTitle(stage.label)
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
