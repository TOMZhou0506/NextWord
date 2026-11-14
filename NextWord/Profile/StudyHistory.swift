import Foundation

// Turn the saved StudyEvent records into the numbers the insights charts show.
// StudyHistory is the data processing layer: it handles calculations only, not display.
struct StudyHistory {
    // Number of study actions on each day, keyed by the start of that day.
    let activityByDay: [Date: Int]
    private let reviews: [StudyEvent]
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
        studied(on: Date())
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
}
