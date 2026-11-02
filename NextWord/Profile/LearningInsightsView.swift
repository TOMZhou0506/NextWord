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
// get the words stage data for current learning stages chart
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

    // MARK: - Current learning stages
    
    private var currentStages: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current learning stages").font(.title3.bold())
            Text("Today's distribution, not a history of colour changes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            //chart logic
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

// MARK: - Summary tiles 4 girds

// A small summary number at the top of 4 cards on the insights page.
private struct InsightTile: View {
    let value: String
    let title: String
    let symbol: String
    let colour: Color
    // An optional bird in the top corner, e.g. the flame bird for an active streak.
    var bird: BirdMascot.Pose? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(colour)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        // Fill the row height so tiles with one- and two-line titles line up.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // An overlay doesn't change the tile's size, so the two tiles in a row still match.
        .overlay(alignment: .topTrailing) {
            if let bird { BirdMascot(pose: bird, size: 56) }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Learning calendar

// A month grid where darker days had more study actions.
private struct LearningCalendarCard: View {
    let activityByDay: [Date: Int]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    // Put empty cells first so day 1 lands under the correct weekday.
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leadingBlanks) + days
    }

    // Start the weekday header on the user's first day of the week.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
// calendar part
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title and month switcher share a row when they fit; the switcher drops below at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Learning calendar").font(.title3.bold())
                    Spacer()
                    monthSwitcher
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Learning calendar").font(.title3.bold())
                    monthSwitcher
                }
            }
            .lineLimit(1)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            HStack(spacing: 4) {
                Text("Less")
                ForEach([0, 1, 30, 100], id: \.self) { count in
                    RoundedRectangle(cornerRadius: 3).fill(fill(for: count)).frame(width: 12, height: 12)
                }
                Text("More")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)

            Text("Saving, reviewing or changing a word's colour counts as a learning day. History starts from when recording was added.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .insightsCard()
    }

    private var monthSwitcher: some View {
        HStack {
            Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous month")
            Text(month, format: .dateTime.month(.abbreviated).year())
                .font(.subheadline.weight(.semibold))
            Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                .disabled(isCurrentMonth)
                .accessibilityLabel("Next month")
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let count = activityByDay[day] ?? 0
        let isToday = calendar.isDateInToday(day)
        return Text(day, format: .dateTime.day())
            .font(.caption.weight(isToday ? .bold : .regular))
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 34)
            .foregroundStyle(count >= 30 ? Color.white : Color.primary)
            .background(fill(for: count), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 1.5)
                }
            }
            .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(count) study actions")
    }

    // Four shades: none, a little (1-29), some (30-99), a lot (100+).
    private func fill(for count: Int) -> Color {
        switch count {
        case 0: Color(.tertiarySystemFill)
        case 1...29: .blue.opacity(0.3)
        case 30...99: .blue.opacity(0.65)
        default: .blue
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            month = newMonth
        }
    }
}

// MARK: - Review accuracy

// Daily share of review cards answered correctly.
// Review accuracy Line Chart
private struct AccuracyTrendCard: View {
    let points: [StudyHistory.DailyAccuracy]
    let rangeStart: Date
    let rangeEnd: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review accuracy").font(.title3.bold())
            Text("How many review cards you answered correctly each day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if points.isEmpty {
                BirdMessage(pose: .sleeping, title: "No reviews yet", message: "Finish a review to start this chart.", birdSize: 90)
                    .frame(minHeight: 200)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date, unit: .day), y: .value("Accuracy", point.percent))
                        .foregroundStyle(.green)
                    PointMark(x: .value("Date", point.date, unit: .day), y: .value("Accuracy", point.percent))
                        .foregroundStyle(.green)
                }
                // chart format
                .chartXScale(domain: rangeStart...rangeEnd)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let percent = value.as(Int.self) { Text("\(percent)%") }
                        }
                    }
                }
                .frame(height: 200)
                .accessibilityLabel("Daily review accuracy")
            }
            Text("Days without reviews are left out instead of counting as 0%.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .insightsCard()
    }
}

// MARK: - Shared helpers

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
    // The rounded card used by every section on this screen.
    func insightsCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

