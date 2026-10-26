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

    private struct StageTotal: Identifiable {
        let stage: LearningStage
        let count: Int
        var id: LearningStage { stage }
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
            // The flame bird only appears once there is a streak to be proud of.
            InsightTile(value: history.currentStreak.formatted(), title: "Day streak", symbol: "flame.fill", colour: .orange,
                        bird: history.currentStreak > 0 ? .flame : nil)
            InsightTile(value: history.studyDays(inMonthOf: Date()).formatted(), title: "Learning days this month", symbol: "calendar", colour: .blue)
            InsightTile(value: recentReviews.count.formatted(), title: "Words reviewed · \(selectedDays) days", symbol: "arrow.triangle.2.circlepath", colour: .cyan)
            InsightTile(value: accuracy, title: "Accuracy · \(selectedDays) days", symbol: "checkmark.seal.fill", colour: .green)
        }
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
