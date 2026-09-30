import SwiftUI
import SwiftData

struct VocabularyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWord.savedAt, order: .reverse) private var words: [SavedWord]
    @AppStorage("didSeedVocabularyDemo_v1") private var didSeedDemo = false
    @State private var seedError: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                totalCard
                stageSummary

                if let seedError {
                    Text("Could not add demo words: \(seedError)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Words by stage")
                    .font(.title2.bold())

                ForEach(LearningStage.allCases, id: \.self) { stage in
                    stageSection(stage)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vocabulary")
        .task { addDemoWordsIfNeeded() }
    }

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

    private var stageSummary: some View {
        VStack(spacing: 16) {
            ForEach(LearningStage.allCases, id: \.self) { stage in
                HStack(spacing: 10) {
                    Circle()
                        .fill(stage.colour)
                        .frame(width: 12, height: 12)
                    Text(stage.label)
                    Spacer()
                    Text("\(wordsIn(stage).count)")
                        .monospacedDigit()
                }
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private func stageSection(_ stage: LearningStage) -> some View {
        let stageWords = wordsIn(stage)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(stage.colour).frame(width: 12, height: 12)
                Text(stage.label).font(.headline)
                Spacer()
                Text("\(stageWords.count)")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                if stageWords.isEmpty {
                    Text("No words yet")
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else {
                    ForEach(stageWords) { word in
                        Text(word.word)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                        if word.id != stageWords.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func wordsIn(_ stage: LearningStage) -> [SavedWord] {
        words.filter { $0.stage == stage }
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

private extension LearningStage {
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
