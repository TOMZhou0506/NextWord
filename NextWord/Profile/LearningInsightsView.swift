import Charts
import SwiftData
import SwiftUI

// Show progress that can be calculated from the vocabulary saved on this device.
struct LearningInsightsView: View {
    @Query private var words: [SavedWord]
    @State private var selectedDays = 30

    private struct DailyTotal: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    private struct StageTotal: Identifiable {
        let stage: LearningStage
        let count: Int
        var id: LearningStage { stage }
    }

    // Include words saved before the displayed range in its starting total.
    private var dailyTotals: [DailyTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<selectedDays).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - selectedDays + 1, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            return DailyTotal(date: day, count: words.filter { $0.savedAt < nextDay }.count)
        }
    }

    private var stageTotals: [StageTotal] {
        LearningStage.allCases.map { stage in
            StageTotal(stage: stage, count: words.filter { $0.stage == stage }.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                vocabularyGrowth
                currentStages
                learningDays
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Learning Insights")
    }

    private var vocabularyGrowth: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Words collected over time").font(.title3.bold())
            Text("\(words.count) words saved")
                .font(.title2.weight(.semibold))
                .monospacedDigit()

            Picker("Time range", selection: $selectedDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }
            .pickerStyle(.segmented)

            if words.isEmpty {
                ContentUnavailableView("No words saved yet", systemImage: "text.book.closed", description: Text("Save a word to start your chart."))
                    .frame(height: 220)
            } else {
                Chart(dailyTotals) { day in
                    LineMark(
                        x: .value("Date", day.date),
                        y: .value("Words", day.count)
                    )
                    .interpolationMethod(.stepEnd)
                    .foregroundStyle(.blue)
                }
                .chartYScale(domain: 0...max(1, words.count))
                .frame(height: 220)
                .accessibilityLabel("Cumulative words saved in the last \(selectedDays) days")
            }
            Text("Counts are based on saved dates. Deleted words cannot be reconstructed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .insightsCard()
    }

    private var currentStages: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current learning stages").font(.title3.bold())
            Text("Today's distribution, not a history of colour changes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(stageTotals) { item in
                BarMark(
                    x: .value("Stage", item.stage.shortLabel),
                    y: .value("Words", item.count)
                )
                .foregroundStyle(item.stage.colour)
            }
            .chartYScale(domain: 0...max(1, words.count))
            .frame(height: 190)

            ForEach(stageTotals) { item in
                HStack {
                    Circle().fill(item.stage.colour).frame(width: 10, height: 10)
                    Text(item.stage.label)
                    Spacer()
                    Text(item.count.formatted()).monospacedDigit()
                }
                .font(.subheadline)
            }
        }
        .insightsCard()
    }

    private var learningDays: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Learning days").font(.title3.bold())
            Text("A learning calendar will appear after the app starts recording each day's study activity. Existing words only store their latest review date, so earlier learning days cannot be recovered accurately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .insightsCard()
    }
}

private extension LearningStage {
    var shortLabel: String {
        switch self {
        case .unfamiliar: "Red"
        case .learning: "Orange"
        case .improving: "Yellow"
        case .familiar: "Green"
        case .mastered: "Blue"
        }
    }
}

private extension View {
    func insightsCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
