import Charts
import SwiftUI

// Turn the saved StudyEvent records into the numbers the insights charts show.
struct StudyHistory {
    // Number of study actions on each day, keyed by the start of that day.
    let activityByDay: [Date: Int]
    private let reviews: [StudyEvent]
    private let stageMoves: [StudyEvent]
    private let calendar = Calendar.current

    // Saving, reviewing and changing a colour all count as studying that day.
    private static let studyKinds: Set<StudyEventKind> = [.saved, .reviewed, .stageChanged]

    init(events: [StudyEvent]) {
        var activity: [Date: Int] = [:]
        for event in events where Self.studyKinds.contains(event.kind) {
            activity[Calendar.current.startOfDay(for: event.date), default: 0] += 1
        }
        activityByDay = activity
        reviews = events.filter { $0.kind == .reviewed }
        // Reviews and manual colour changes both store the old and new stage.
        stageMoves = events.filter { $0.oldStage != nil && $0.newStage != nil }
    }

    // Count back from today; if today has no study yet, start from yesterday.
    var currentStreak: Int {
        let today = calendar.startOfDay(for: Date())
        guard var day = activityByDay[today] != nil
                ? today
                : calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var streak = 0
        while activityByDay[day] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // The longest run of back-to-back learning days ever.
    var bestStreak: Int {
        let days = activityByDay.keys.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for day in days {
            // Continue the run only if this day comes straight after the previous one.
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    var studiedToday: Bool {
        activityByDay[calendar.startOfDay(for: Date())] != nil
    }

    // The seven days of the current week, starting on the user's first weekday.
    var thisWeek: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func studied(on day: Date) -> Bool {
        activityByDay[calendar.startOfDay(for: day)] != nil
    }

    // Review cards finished today, used for Home's daily task.
    var reviewsToday: Int {
        reviews.filter { calendar.isDateInToday($0.date) }.count
    }

    func studyDays(inMonthOf date: Date) -> Int {
        activityByDay.keys.filter { calendar.isDate($0, equalTo: date, toGranularity: .month) }.count
    }

    func reviews(since start: Date) -> [StudyEvent] {
        reviews.filter { $0.date >= start }
    }

    struct DailyAccuracy: Identifiable {
        let date: Date
        let percent: Double
        var id: Date { date }
    }

    // Only days with reviews get a point, so a day off is not shown as 0%.
    func dailyAccuracy(since start: Date) -> [DailyAccuracy] {
        let byDay = Dictionary(grouping: reviews(since: start)) { calendar.startOfDay(for: $0.date) }
        return byDay.map { day, items in
            let correct = items.filter { $0.wasCorrect == true }.count
            return DailyAccuracy(date: day, percent: Double(correct) / Double(items.count) * 100)
        }
        .sorted { $0.date < $1.date }
    }

    struct DailyStageMoves: Identifiable {
        let date: Date
        let up: Int
        let down: Int
        var id: Date { date }
    }

    // Compare each event's old and new colour; staying at the same colour is not a move.
    func dailyStageMoves(since start: Date) -> [DailyStageMoves] {
        let recent = stageMoves.filter { $0.date >= start }
        let byDay = Dictionary(grouping: recent) { calendar.startOfDay(for: $0.date) }
        return byDay.compactMap { day, items in
            var up = 0
            var down = 0
            for item in items {
                guard let old = item.oldStage, let new = item.newStage else { continue }
                if new.rank > old.rank { up += 1 }
                if new.rank < old.rank { down += 1 }
            }
            return up + down == 0 ? nil : DailyStageMoves(date: day, up: up, down: down)
        }
        .sorted { $0.date < $1.date }
    }
}

private extension LearningStage {
    // Red is 0 and blue is 4, so a bigger number means a better-known word.
    var rank: Int { LearningStage.allCases.firstIndex(of: self) ?? 0 }
}

// A small summary number at the top of the insights page.
struct InsightTile: View {
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

// A month grid where darker days had more study actions.
struct LearningCalendarCard: View {
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
                ForEach([0, 1, 3, 6], id: \.self) { count in
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
            .foregroundStyle(count >= 3 ? Color.white : Color.primary)
            .background(fill(for: count), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 1.5)
                }
            }
            .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(count) study actions")
    }

    // Four shades: none, a little (1-2), some (3-5), a lot (6+).
    private func fill(for count: Int) -> Color {
        switch count {
        case 0: Color(.tertiarySystemFill)
        case 1...2: .blue.opacity(0.3)
        case 3...5: .blue.opacity(0.65)
        default: .blue
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            month = newMonth
        }
    }
}

// Daily share of review cards answered correctly.
struct AccuracyTrendCard: View {
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

// Words moving up a colour (above the line) or down a colour (below the line).
struct StageMovesCard: View {
    let moves: [StudyHistory.DailyStageMoves]
    let rangeStart: Date
    let rangeEnd: Date

    private var totalUp: Int { moves.reduce(0) { $0 + $1.up } }
    private var totalDown: Int { moves.reduce(0) { $0 + $1.down } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colour changes").font(.title3.bold())
            Text("Words that moved up or down a colour, from reviews and manual changes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if moves.isEmpty {
                BirdMessage(pose: .sleeping, title: "No colour changes yet", message: "Review or recolour a word to start this chart.", birdSize: 90)
                    .frame(minHeight: 200)
            } else {
                HStack(spacing: 16) {
                    Label("\(totalUp) up", systemImage: "arrow.up").foregroundStyle(.green)
                    Label("\(totalDown) down", systemImage: "arrow.down").foregroundStyle(.red)
                }
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

                Chart {
                    ForEach(moves) { day in
                        BarMark(x: .value("Date", day.date, unit: .day), y: .value("Words", day.up))
                            .foregroundStyle(.green)
                        // Draw downward moves below zero so the two directions are easy to compare.
                        BarMark(x: .value("Date", day.date, unit: .day), y: .value("Words", -day.down))
                            .foregroundStyle(.red)
                    }
                    RuleMark(y: .value("Zero", 0)).foregroundStyle(.secondary)
                }
                .chartXScale(domain: rangeStart...rangeEnd)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let count = value.as(Int.self) { Text("\(abs(count))") }
                        }
                    }
                }
                .frame(height: 200)
                .accessibilityLabel("\(totalUp.counted("word")) moved up and \(totalDown.counted("word")) moved down")
            }
        }
        .insightsCard()
    }
}
