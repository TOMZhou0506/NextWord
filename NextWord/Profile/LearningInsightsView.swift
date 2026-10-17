import Charts
import SwiftData
import SwiftUI

// Show progress from the saved vocabulary and the learning history on this device.
struct LearningInsightsView: View {
    @Query private var words: [SavedWord]
    @Query private var events: [StudyEvent]
    @State private var selectedDays = 30

    // First day shown by the 7/30-day picker.
    private var rangeStart: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: 1 - selectedDays, to: today) ?? today
    }

    // End of today, so today's bar or point fits inside the chart.
    private var rangeEnd: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
    }

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
        // Build the history once per refresh and share it with every card.
        let history = StudyHistory(events: events)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Time range", selection: $selectedDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)

                summaryTiles(history)
                LearningCalendarCard(activityByDay: history.activityByDay)
                AccuracyTrendCard(points: history.dailyAccuracy(since: rangeStart), rangeStart: rangeStart, rangeEnd: rangeEnd)
                StageMovesCard(moves: history.dailyStageMoves(since: rangeStart), rangeStart: rangeStart, rangeEnd: rangeEnd)
                vocabularyGrowth
                currentStages
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Learning Insights")
    }

    // Streak and month count ignore the picker; reviews and accuracy follow it.
    private func summaryTiles(_ history: StudyHistory) -> some View {
        let recentReviews = history.reviews(since: rangeStart)
        let correct = recentReviews.filter { $0.wasCorrect == true }.count
        let accuracy = recentReviews.isEmpty
            ? "–"
            : "\(Int((Double(correct) / Double(recentReviews.count) * 100).rounded()))%"
        let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

        return LazyVGrid(columns: columns, spacing: 14) {
            InsightTile(value: history.currentStreak.formatted(), title: "Day streak", symbol: "flame.fill", colour: .orange)
            InsightTile(value: history.studyDays(inMonthOf: Date()).formatted(), title: "Learning days this month", symbol: "calendar", colour: .blue)
            InsightTile(value: recentReviews.count.formatted(), title: "Words reviewed · \(selectedDays) days", symbol: "arrow.triangle.2.circlepath", colour: .cyan)
            InsightTile(value: accuracy, title: "Accuracy · \(selectedDays) days", symbol: "checkmark.seal.fill", colour: .green)
        }
    }

    private var vocabularyGrowth: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Words collected over time").font(.title3.bold())
            Text("\(words.count) words saved")
                .font(.title2.weight(.semibold))
                .monospacedDigit()

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
            Text("Counts the words in your Vocabulary now, by the date each was saved.")
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

// Shared card style, also used by LearningHistoryCards.swift.
extension View {
    func insightsCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}
